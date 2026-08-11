import WidgetKit
import SwiftUI
import DidICore

struct BoardEntry: TimelineEntry {
    let date: Date
    let store: Store
    let selectedID: UUID?

    /// The item the single-item families show: the configured one, else the first.
    var selected: Item? {
        store.active.first { $0.id == selectedID } ?? store.active.first
    }

    var states: [UUID: ItemState] {
        Dictionary(uniqueKeysWithValues: store.active.map {
            ($0.id, store.state($0, now: date))
        })
    }
}

/// Entries are precomputed at every boundary the store already knows about, so
/// nothing has to execute at 04:00 for the widget to be correct at 04:00.
/// Capped at 20 entries and 24 hours; the reload policy picks up the rest.
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BoardEntry {
        entry(at: .now, selectedID: nil)
    }

    func snapshot(for configuration: SelectItemIntent, in context: Context) async -> BoardEntry {
        entry(at: .now, selectedID: configuration.itemID)
    }

    func timeline(for configuration: SelectItemIntent, in context: Context) async -> Timeline<BoardEntry> {
        let store = StoreIO.read()
        let now = Date()
        let horizon = now.addingTimeInterval(24 * 3600)
        let dates = [now] + store.allBoundaries(after: now).filter { $0 < horizon }.prefix(20)
        let entries = dates.map {
            BoardEntry(date: $0, store: store, selectedID: configuration.itemID)
        }
        return Timeline(entries: entries, policy: .after(dates.last ?? horizon))
    }

    private func entry(at date: Date, selectedID: UUID?) -> BoardEntry {
        BoardEntry(date: date, store: StoreIO.read(), selectedID: selectedID)
    }
}

extension SelectItemIntent {
    var itemID: UUID? { item.flatMap { UUID(uuidString: $0.id) } }
}

struct DidIWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKind.board,
            intent: SelectItemIntent.self,
            provider: Provider()
        ) { entry in
            BoardWidgetView(entry: entry)
                .environment(\.confirmAction, .widgetButton)
        }
        .configurationDisplayName("Did I?")
        .description("One tap on your way out.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular,
        ])
    }
}

extension ConfirmAction {
    /// The real tap. `perform()` reads, mutates, writes, reloads, returns.
    @MainActor
    static var widgetButton: ConfirmAction { ConfirmAction { item, content in
        AnyView(
            Button(intent: ConfirmItemIntent(itemID: item.id.uuidString)) { content }
                .buttonStyle(.plain)
        )
    } }
}

struct BoardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BoardEntry

    var body: some View {
        switch family {
        case .systemSmall:
            single { SmallFace(item: $0, state: $1) }
                .padding(2)
                .containerBackground(Palette.ink, for: .widget)

        case .systemMedium:
            MediumFace(items: entry.store.active, states: entry.states, date: entry.date)
                .containerBackground(Palette.ink, for: .widget)

        case .accessoryCircular:
            single { CircularFace(item: $0, state: $1) }
                .containerBackground(.clear, for: .widget)

        default:
            RectangularFace(items: entry.store.active, states: entry.states)
                .containerBackground(.clear, for: .widget)
        }
    }

    /// Single-item families, with the empty board handled once.
    @ViewBuilder
    private func single(@ViewBuilder _ face: (Item, ItemState) -> some View) -> some View {
        if let item = entry.selected {
            face(item, entry.store.state(item, now: entry.date))
        } else {
            Text(Copy.summary(handled: 0, of: 0))
                .font(board(9))
                .foregroundStyle(Palette.muted)
        }
    }
}

@main
struct DidIWidgetBundle: WidgetBundle {
    var body: some Widget {
        DidIWidget()
    }
}
