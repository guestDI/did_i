import SwiftUI
import CoreLocation
import WidgetKit
import DidICore

/// day-2, in order: the decay lesson, then the location ask, then home, then the
/// `always` escalation. A sheet over the main screen, never a takeover — the item
/// list stays visible behind it so they can see what is being talked about.
struct DayTwoFlow: View {
    enum Step: Identifiable {
        case lesson([Item])
        case locationAsk
        case homeSetup
        case alwaysEscalation
        case declined

        var id: String {
            switch self {
            case .lesson: "lesson"
            case .locationAsk: "locationAsk"
            case .homeSetup: "homeSetup"
            case .alwaysEscalation: "alwaysEscalation"
            case .declined: "declined"
            }
        }
    }

    @State var step: Step
    let onFinished: () -> Void

    /// A one-shot fix can come back empty indoors or in airplane mode. Without
    /// this the primary button silently does nothing and reads as broken.
    @State private var homeCaptureFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .lesson(let items): lesson(items)
            case .locationAsk: locationAsk
            case .homeSetup: homeSetup
            case .alwaysEscalation: alwaysEscalation
            case .declined: declined
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    // MARK: - The lesson

    private func lesson(_ items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Lesson.title(items: items, hour: resetHour(items)))
                .font(board(18, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.Lesson.body)
                .font(.system(size: 14))
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)
            // Waking up to "unknown" reads as failure. Say plainly that it isn't.
            Text(Copy.Lesson.footer)
                .font(.system(size: 12))
                .foregroundStyle(Palette.dim)
                .padding(.top, 16)
            Spacer(minLength: 20)
            Button(Copy.Lesson.button) {
                mark { $0.flags.decayLessonShown = true }
                step = .locationAsk
            }
            .buttonStyle(PrimaryButton())
        }
    }

    /// Only meaningful when everything that aged out shares a nightly hour.
    private func resetHour(_ items: [Item]) -> Int? {
        let hours = items.compactMap { item -> Int? in
            if case .dailyAt(let hour) = item.resetRule { return hour }
            return nil
        }
        guard hours.count == items.count, let first = hours.first,
              hours.allSatisfy({ $0 == first })
        else { return nil }
        return first
    }

    // MARK: - The location ask

    private var locationAsk: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.LocationAsk.title)
                .font(board(18, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.LocationAsk.body)
                .font(.system(size: 14))
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)
            Spacer(minLength: 20)

            // Only this button presents the iOS dialog.
            Button(Copy.LocationAsk.use) {
                LocationMonitor.shared.requestWhenInUse { status in
                    switch status {
                    case .authorizedWhenInUse, .authorizedAlways:
                        step = .homeSetup
                    default:
                        decline()
                    }
                }
            }
            .buttonStyle(PrimaryButton())

            Button(Copy.LocationAsk.keepTimer) { decline() }
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }

    // MARK: - Home

    private var homeSetup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.HomeSetup.title)
                .font(board(18, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.HomeSetup.body)
                .font(.system(size: 14))
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)
            if homeCaptureFailed {
                Text(Copy.HomeSetup.noFix)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.amber)
                    .padding(.top, 14)
            }
            Spacer(minLength: 20)

            Button(Copy.HomeSetup.set) {
                homeCaptureFailed = false
                LocationMonitor.shared.captureHome { coordinate in
                    // Not `decline()`: a failed fix is not a refusal, and burning
                    // `locationDeclined` here would mean never asking again.
                    guard let coordinate else {
                        homeCaptureFailed = true
                        return
                    }
                    let home = HomeLocation(
                        latitude: coordinate.latitude, longitude: coordinate.longitude
                    )
                    mark {
                        $0.home = home
                        $0.flags.homeSetupPending = false
                        $0.flags.homeSetupDeferredUntil = nil
                    }
                    LocationMonitor.shared.monitor(home)
                    step = .alwaysEscalation
                }
            }
            .buttonStyle(PrimaryButton())

            Button(Copy.HomeSetup.notHome) {
                // Keep the route alive without showing the same prompt again on
                // the very next open.
                mark { $0.flags.deferHomeSetup(at: .now) }
                onFinished()
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
    }

    /// architecture §6: without `always`, exit events never arrive while the app
    /// is backgrounded or terminated — which is exactly when they matter. A
    /// refusal degrades silently to the 24h ceiling. No banner, no badgering.
    private var alwaysEscalation: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.HomeSetup.confirmed)
                .font(board(15, .semibold))
                .foregroundStyle(Palette.fresh)
            Text(Copy.LocationAsk.alwaysTitle)
                .font(board(18, .semibold))
                .foregroundStyle(Palette.text)
                .padding(.top, 20)
            Text(Copy.LocationAsk.alwaysReason)
                .font(.system(size: 14))
                .foregroundStyle(Palette.sub)
                .padding(.top, 12)
            Spacer(minLength: 20)

            Button(Copy.LocationAsk.alwaysButton) {
                LocationMonitor.shared.requestAlways { _ in onFinished() }
            }
            .buttonStyle(PrimaryButton())

            Button(Copy.LocationAsk.alwaysSkip) { onFinished() }
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }

    // MARK: - Declined

    private var declined: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.LocationDeclined.message)
                .font(board(15, .semibold))
                .foregroundStyle(Palette.text)
            // Shown silently, once.
            Text(Copy.resetRuleHint)
                .font(.system(size: 13))
                .foregroundStyle(Palette.sub)
                .padding(.top, 16)
            Spacer(minLength: 20)
            Button(Copy.ok) { onFinished() }
                .buttonStyle(PrimaryButton())
        }
    }

    private func decline() {
        mark {
            $0.flags.locationDeclined = true
            $0.flags.settingsHintShown = true
            $0.flags.homeSetupPending = false
            $0.flags.homeSetupDeferredUntil = nil
        }
        step = .declined
    }

    private func mark(_ change: (inout Store) -> Void) {
        try? StoreIO.mutate(change)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
    }
}
