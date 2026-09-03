import SwiftUI

/// One row of the board. Shared so the Day 0 practice card is not a lookalike of
/// the main screen's card — it is the same view, "exactly as it will look".
///
/// The row confirms and a hold clears the current confirmation. Secondary controls are layered beside
/// it by the app so this shared view remains one coherent accessibility element.
public struct BoardRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: Item
    let state: ItemState
    let statusOverride: String?
    let isAway: Bool
    let onConfirm: () -> Void
    let onClear: (() -> Void)?

    public init(
        item: Item,
        state: ItemState,
        statusOverride: String? = nil,
        isAway: Bool = false,
        onConfirm: @escaping () -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self.item = item
        self.state = state
        self.statusOverride = statusOverride
        self.isAway = isAway
        self.onConfirm = onConfirm
        self.onClear = onClear
    }

    private var status: String {
        statusOverride ?? Copy.status(for: state, item: item, isAway: isAway)
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                name
                // Two lines: the away line runs to 62 characters and is the one
                // sentence in the app that must never be clipped.
                Text(status)
                    .boardFont(11.5, .medium, relativeTo: .caption)
                    .foregroundStyle(Palette.sub)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            FlapCell(
                state == .unknown ? "·" : "✓",
                color: Palette.color(for: state),
                width: 22, height: 28, fontSize: 13
            )
            .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                Text(state == .unknown ? "———" : item.word.uppercased())
                    .font(boardScaled(.headline, .bold))
                    .foregroundStyle(Palette.color(for: state))
                    .multilineTextAlignment(.trailing)
                    .accessibilityHidden(true)
            } else {
                FlapWord(
                    item: item, state: state,
                    cellWidth: 18, cellHeight: 28, fontSize: 12.5, maxWidth: 150
                )
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
        // Rows stay a regular grid even when the status line wraps to two —
        // a departure board with ragged rows stops reading as one.
        .frame(minHeight: 76)
        .contentShape(.rect)
        .modifier(ConfirmOrClear(onConfirm: onConfirm, onClear: onClear))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("confirmationRow.\(item.name)")
        .accessibilityLabel(Copy.confirmLabel(item: item))
        .accessibilityValue(status)
        .accessibilityHint(Copy.confirmHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onConfirm() }
        .modifier(ClearAccessibility(action: onClear))
    }

    private var name: some View {
        Text(item.name)
            .boardFont(15, relativeTo: .body)
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundStyle(Palette.text)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
    }
}

/// `.onTapGesture` and `.onLongPressGesture` attached as two independent
/// modifiers on the same view is a known SwiftUI trap: the underlying UIKit
/// recognizers have no failure relationship, so the first long press after the
/// view appears can lose the race and register as nothing — the exact "doesn't
/// work the first time" report this replaces. `.exclusively(before:)` composes
/// them into one `Gesture` with an explicit precedence — hold long enough and
/// the clear wins outright; release early and only then does the confirm fire — so
/// there is nothing left to race.
private struct ConfirmOrClear: ViewModifier {
    let onConfirm: () -> Void
    let onClear: (() -> Void)?

    func body(content: Content) -> some View {
        if let onClear {
            content.gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in onClear() }
                    .exclusively(before: TapGesture().onEnded(onConfirm))
            )
        } else {
            content.onTapGesture(perform: onConfirm)
        }
    }
}

/// A row with no confirmation has nothing to clear, so VoiceOver must not offer
/// a custom action that silently does nothing.
private struct ClearAccessibility: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.accessibilityAction(named: Copy.clearStatus) { action() }
        } else {
            content
        }
    }
}
