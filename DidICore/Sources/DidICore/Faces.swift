import SwiftUI

/// How a face turns an item into something tappable.
///
/// The faces live here so they can be snapshot-tested, but `Button(intent:)`
/// needs AppIntents and WidgetKit, which this package deliberately does not
/// link. The extension injects the real wrapper; tests and previews get `.inert`
/// and render exactly the same pixels.
public struct ConfirmAction {
    let wrap: (Item, AnyView) -> AnyView

    public init(_ wrap: @escaping (Item, AnyView) -> AnyView) {
        self.wrap = wrap
    }

    // Computed: `ConfirmAction` holds a view-building closure, which is
    // main-actor work and not `Sendable`. A stored global would need an
    // isolation promise it cannot make.
    public static var inert: ConfirmAction { ConfirmAction { _, content in content } }

    func callAsFunction(_ item: Item, @ViewBuilder _ content: () -> some View) -> AnyView {
        wrap(item, AnyView(content()))
    }
}

private struct ConfirmActionKey: EnvironmentKey {
    static var defaultValue: ConfirmAction { .inert }
}

public extension EnvironmentValues {
    var confirmAction: ConfirmAction {
        get { self[ConfirmActionKey.self] }
        set { self[ConfirmActionKey.self] = newValue }
    }
}

// MARK: - systemSmall

/// One item, chosen via widget configuration.
///
/// The flaps are the button; the header row is not. Wrapping the whole face meant
/// tapping to look closer wrote a confirmation — a false green, which is the one
/// thing this app exists to prevent — and left a small-widget user with no way
/// into the app at all. The header falls through to the default open action.
public struct SmallFace: View {
    @Environment(\.confirmAction) private var confirm

    let item: Item
    let state: ItemState

    public init(item: Item, state: ItemState) {
        self.item = item
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(board(9))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(shortAge(state))
                    .font(board(9, .medium))
                    .invalidatableContent()
            }
            .foregroundStyle(Palette.muted)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Copy.openHint)

            confirm(item) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 6)

                    FlapWord(item: item, state: state, cellWidth: 34, cellHeight: 48, fontSize: 22, maxWidth: 126)
                        .invalidatableContent()

                    Text(Copy.status(for: state, item: item))
                        .font(board(8.5))
                        .foregroundStyle(Palette.color(for: state))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .invalidatableContent()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(spokenLabel(item: item, state: state))
                .accessibilityHint(Copy.confirmHint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - systemMedium

/// Two columns (architecture §5). Two rows for a board of four or fewer, three
/// once it grows past that — the cap is six and `prefix(4)` silently hid the last
/// two, which on a "did I?" board is the worst possible thing to hide.
///
/// Board order, never state order: cells that reshuffle on a timeline refresh
/// would move the target out from under a finger already on its way down.
public struct MediumFace: View {
    @Environment(\.confirmAction) private var confirm

    let items: [Item]
    let states: [UUID: ItemState]
    let date: Date

    public init(items: [Item], states: [UUID: ItemState], date: Date) {
        self.items = items
        self.states = states
        self.date = date
    }

    var shown: [Item] { Array(items.prefix(6)) }

    private var rowCount: Int { shown.count > 4 ? 3 : 2 }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Did I?")
                    .font(board(10, .bold))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(board(9, .medium))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.ruleStrong).frame(height: 1)
            }

            Grid(horizontalSpacing: 14, verticalSpacing: 0) {
                ForEach(0..<rowCount, id: \.self) { row in
                    GridRow {
                        cell(at: row * 2)
                        cell(at: row * 2 + 1)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func cell(at index: Int) -> some View {
        if index < shown.count {
            let item = shown[index]
            let state = states[item.id] ?? .unknown
            confirm(item) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(board(9))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        Text(statusWord(item: item, state: state))
                            .font(board(11.5, .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.color(for: state))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        Text(shortAge(state))
                            .font(board(9, .medium))
                            .foregroundStyle(Palette.muted)
                    }
                    .invalidatableContent()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(spokenLabel(item: item, state: state))
                .accessibilityHint(Copy.confirmHint)
            }
        } else {
            Color.clear
        }
    }
}

// MARK: - accessoryCircular

/// One item: symbol + hours-since (architecture §5). iOS renders the lock screen
/// in monochrome, so state is carried by the glyph and by opacity, never colour.
public struct CircularFace: View {
    @Environment(\.confirmAction) private var confirm

    let item: Item
    let state: ItemState

    public init(item: Item, state: ItemState) {
        self.item = item
        self.state = state
    }

    var isUnknown: Bool { state == .unknown }

    public var body: some View {
        confirm(item) {
            VStack(spacing: 1) {
                Image(systemName: item.symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(isUnknown ? "—" : shortAge(state))
                    .font(board(11, .bold))
                    .invalidatableContent()
            }
            .opacity(isUnknown ? 0.55 : 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(spokenLabel(item: item, state: state))
            .accessibilityHint(Copy.confirmHint)
        }
    }
}

// MARK: - accessoryRectangular

/// Summary: "3 of 4 handled" (architecture §5). Not per-item, so not tappable —
/// it opens the app.
public struct RectangularFace: View {
    let items: [Item]
    let states: [UUID: ItemState]

    public init(items: [Item], states: [UUID: ItemState]) {
        self.items = items
        self.states = states
    }

    var handled: Int {
        items.filter { (states[$0.id] ?? .unknown) != .unknown }.count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Did I?")
                .font(board(9, .bold))
                .tracking(2.5)
                .textCase(.uppercase)
                .opacity(0.65)
            Text(Copy.summary(handled: handled, of: items.count))
                .font(board(13, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.summary(handled: handled, of: items.count))
    }
}

// MARK: - Shared bits

func shortAge(_ state: ItemState) -> String {
    if case .confirmed(let age, _) = state { return Copy.shortAge(age) }
    return ""
}

/// The word the flaps spell, in text form for the families too small for flaps.
func statusWord(item: Item, state: ItemState) -> String {
    state == .unknown ? "———" : "✓ \(item.word)"
}

func spokenLabel(item: Item, state: ItemState) -> String {
    "\(item.name), \(Copy.status(for: state, item: item))"
}
