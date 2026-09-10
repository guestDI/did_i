import SwiftUI

/// One row of the board. Shared so the Day 0 practice card is not a lookalike of
/// the main screen's card — it is the same view, "exactly as it will look".
///
/// The status itself is inert. Confirmation is a separate, labelled button so
/// looking at a record can never create a new one by accident. Secondary controls
/// are layered beside the item name by the app.
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
        let base = statusOverride ?? Copy.status(for: state, item: item, isAway: isAway)
        // The settings screen already tells you a rule change waits for the next
        // confirmation; this is that promise made visible on the item it affects.
        // Only surfaced while it's actually true, so the common case — active
        // rule matches current settings — reads exactly as it always has.
        guard statusOverride == nil, case .confirmed = state,
              let activeRule = item.lastConfirmationRule, activeRule != item.resetRule
        else { return base }
        return "\(Copy.activeResetNote(activeRule)) \(base)"
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
            Button(action: onConfirm) {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        FlapCell(
                            state == .unknown ? "·" : "✓",
                            color: Palette.color(for: state),
                            width: 22, height: 28, fontSize: 13
                        )
                        if dynamicTypeSize.isAccessibilitySize {
                            Text(state == .unknown ? "———" : item.word.uppercased())
                                .font(boardScaled(.headline, .bold))
                                .foregroundStyle(Palette.color(for: state))
                                .multilineTextAlignment(.trailing)
                        } else {
                            FlapWord(
                                item: item, state: state,
                                cellWidth: 18, cellHeight: 28, fontSize: 12.5, maxWidth: 150
                            )
                        }
                    }
                    Text(Copy.confirmNow)
                        .boardFont(8.5, .bold, relativeTo: .caption2)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.muted)
                }
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("confirmationRow.\(item.name)")
            .accessibilityLabel(Copy.confirmLabel(item: item))
            .accessibilityValue(status)
            .accessibilityHint(Copy.confirmHint)
            .modifier(ClearAccessibility(action: onClear))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
        // Rows stay a regular grid even when the status line wraps to two —
        // a departure board with ragged rows stops reading as one.
        .frame(minHeight: 76)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
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
