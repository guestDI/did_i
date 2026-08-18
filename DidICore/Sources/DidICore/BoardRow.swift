import SwiftUI

/// One row of the board. Shared so the Day 0 practice card is not a lookalike of
/// the main screen's card — it is the same view, "exactly as it will look".
///
/// The row confirms and a hold undoes. Secondary controls are layered beside
/// it by the app so this shared view remains one coherent accessibility element.
public struct BoardRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: Item
    let state: ItemState
    let statusOverride: String?
    let isAway: Bool
    let onConfirm: () -> Void
    let onUndo: (() -> Void)?

    public init(
        item: Item,
        state: ItemState,
        statusOverride: String? = nil,
        isAway: Bool = false,
        onConfirm: @escaping () -> Void,
        onUndo: (() -> Void)? = nil
    ) {
        self.item = item
        self.state = state
        self.statusOverride = statusOverride
        self.isAway = isAway
        self.onConfirm = onConfirm
        self.onUndo = onUndo
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
                    .font(boardScaled(.caption, .medium))
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
        .onTapGesture(perform: onConfirm)
        .modifier(LongPressUndo(action: onUndo))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Copy.confirmLabel(item: item))
        .accessibilityValue(status)
        .accessibilityHint(Copy.confirmHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onConfirm() }
        .modifier(UndoAccessibility(action: onUndo))
    }

    private var name: some View {
        Text(item.name)
            .font(boardScaled(.body))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundStyle(Palette.text)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
    }
}

/// `onLongPressGesture` with no action still swallows taps, so the modifier is
/// only attached when there is something to undo to.
private struct LongPressUndo: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onLongPressGesture(perform: action)
        } else {
            content
        }
    }
}

/// A row with no confirmation has nothing to undo, so VoiceOver must not offer
/// a custom action that silently does nothing.
private struct UndoAccessibility: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.accessibilityAction(named: Copy.undo) { action() }
        } else {
            content
        }
    }
}
