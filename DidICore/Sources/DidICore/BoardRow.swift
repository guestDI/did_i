import SwiftUI

/// One row of the board. Shared so the Day 0 practice card is not a lookalike of
/// the main screen's card — it is the same view, "exactly as it will look".
///
/// Two tap targets, per day-2: the *name* opens the editor, everything else
/// confirms. A hold undoes. Omit a closure and that affordance disappears, which
/// is how onboarding gets a confirm-only card.
public struct BoardRow: View {
    let item: Item
    let state: ItemState
    let statusOverride: String?
    let isAway: Bool
    let onConfirm: () -> Void
    let onUndo: (() -> Void)?
    let onEditName: (() -> Void)?

    public init(
        item: Item,
        state: ItemState,
        statusOverride: String? = nil,
        isAway: Bool = false,
        onConfirm: @escaping () -> Void,
        onUndo: (() -> Void)? = nil,
        onEditName: (() -> Void)? = nil
    ) {
        self.item = item
        self.state = state
        self.statusOverride = statusOverride
        self.isAway = isAway
        self.onConfirm = onConfirm
        self.onUndo = onUndo
        self.onEditName = onEditName
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
                    .font(board(9.5, .medium))
                    .foregroundStyle(Palette.sub)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            FlapCell(
                state == .unknown ? "·" : "✓",
                color: Palette.color(for: state),
                width: 22, height: 28, fontSize: 13
            )
            FlapWord(
                item: item, state: state,
                cellWidth: 18, cellHeight: 28, fontSize: 12.5, maxWidth: 150
            )
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
        .accessibilityElement(children: onEditName == nil ? .ignore : .contain)
        .accessibilityLabel(Copy.confirmLabel(item: item))
        .accessibilityHint(Copy.confirmHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onConfirm() }
        .accessibilityAction(named: "Undo") { onUndo?() }
    }

    @ViewBuilder
    private var name: some View {
        let label = Text(item.name)
            .font(board(15))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundStyle(Palette.text)
            .lineLimit(1)

        if let onEditName {
            Button(action: onEditName) { label }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings for \(item.name)")
        } else {
            label
        }
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
