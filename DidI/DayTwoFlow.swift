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
        case limited
        case declined

        var id: String {
            switch self {
            case .lesson: "lesson"
            case .locationAsk: "locationAsk"
            case .homeSetup: "homeSetup"
            case .alwaysEscalation: "alwaysEscalation"
            case .limited: "limited"
            case .declined: "declined"
            }
        }
    }

    @State var step: Step
    let onFinished: () -> Void

    /// A one-shot fix can come back empty indoors or in airplane mode. Without
    /// this the primary button silently does nothing and reads as broken.
    @State private var homeCaptureFailed = false
    @State private var showingSaveError = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case .lesson(let items): lesson(items)
                    case .locationAsk: locationAsk
                    case .homeSetup: homeSetup
                    case .alwaysEscalation: alwaysEscalation
                    case .limited: limited
                    case .declined: declined
                    }
                }
                .padding(30)
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }

    // MARK: - The lesson

    private func lesson(_ items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Lesson.title(items: items, hour: resetHour(items)))
                .font(boardScaled(.headline, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.Lesson.body)
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)
            // Waking up to "unknown" reads as failure. Say plainly that it isn't.
            Text(Copy.Lesson.footer)
                .font(.footnote)
                .foregroundStyle(Palette.dim)
                .padding(.top, 16)
            Spacer(minLength: 20)
            Button(Copy.Lesson.button) {
                if mark({ $0.flags.decayLessonShown = true }) { step = .locationAsk }
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
                .font(boardScaled(.headline, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.LocationAsk.body)
                .font(.subheadline)
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
                .buttonStyle(SecondaryButton())
                .padding(.top, 4)
        }
    }

    // MARK: - Home

    private var homeSetup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.HomeSetup.title)
                .font(boardScaled(.headline, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.HomeSetup.body)
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)
            if homeCaptureFailed {
                Text(Copy.HomeSetup.noFix)
                    .font(.footnote)
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
                    guard mark({
                        $0.home = home
                        $0.flags.homeSetupPending = false
                        $0.flags.homeSetupDeferredUntil = nil
                    }) else { return }
                    LocationMonitor.shared.monitor(home)
                    step = .alwaysEscalation
                }
            }
            .buttonStyle(PrimaryButton())

            Button(Copy.HomeSetup.notHome) {
                // Keep the route alive without showing the same prompt again on
                // the very next open.
                if mark({ $0.flags.deferHomeSetup(at: .now) }) { onFinished() }
            }
            .buttonStyle(SecondaryButton())
            .padding(.top, 4)
        }
    }

    /// architecture §6: without `always`, exit events never arrive while the app
    /// is backgrounded or terminated — which is exactly when they matter. A
    /// refusal degrades silently to the 24h ceiling. No banner, no badgering.
    private var alwaysEscalation: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.HomeSetup.saved)
                .font(boardScaled(.subheadline, .semibold))
                .foregroundStyle(Palette.fresh)
            Text(Copy.LocationAsk.alwaysTitle)
                .font(boardScaled(.headline, .semibold))
                .foregroundStyle(Palette.text)
                .padding(.top, 20)
            Text(Copy.LocationAsk.alwaysReason)
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
                .padding(.top, 12)
            Spacer(minLength: 20)

            Button(Copy.LocationAsk.alwaysButton) {
                LocationMonitor.shared.requestAlways { status in
                    if status == .authorizedAlways { onFinished() } else { step = .limited }
                }
            }
            .buttonStyle(PrimaryButton())

            Button(Copy.LocationAsk.alwaysSkip) { step = .limited }
                .buttonStyle(SecondaryButton())
                .padding(.top, 4)
        }
    }

    private var limited: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.HomeSetup.saved)
                .font(boardScaled(.headline, .semibold))
                .foregroundStyle(Palette.fresh)
            Text(Copy.HomeSettings.foregroundOnly)
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)
            Spacer(minLength: 20)
            Button(Copy.done) { onFinished() }
                .buttonStyle(PrimaryButton())
        }
    }

    // MARK: - Declined

    private var declined: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.LocationDeclined.message)
                .font(boardScaled(.subheadline, .semibold))
                .foregroundStyle(Palette.text)
            // Shown silently, once.
            Text(Copy.resetRuleHint)
                .font(.footnote)
                .foregroundStyle(Palette.sub)
                .padding(.top, 16)
            Spacer(minLength: 20)
            Button(Copy.ok) { onFinished() }
                .buttonStyle(PrimaryButton())
        }
    }

    private func decline() {
        guard mark({
            $0.flags.locationDeclined = true
            $0.flags.settingsHintShown = true
            $0.flags.homeSetupPending = false
            $0.flags.homeSetupDeferredUntil = nil
        }) else { return }
        step = .declined
    }

    private func mark(_ change: (inout Store) -> Void) -> Bool {
        do {
            try StoreIO.mutate(change)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
            return true
        } catch {
            showingSaveError = true
            UIAccessibility.post(notification: .announcement, argument: Copy.saveFailedBody)
            return false
        }
    }
}
