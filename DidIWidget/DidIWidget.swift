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

    /// State boundaries alone left the "3M"/"1H" age readout frozen at whatever
    /// it was when the entry was generated — correct at the moment, stale for
    /// however long until the next aging/expiry transition, which reads as "the
    /// widget only updates when you tap it". 15-minute ticks keep it moving;
    /// state boundaries are still merged in so a transition never lands late.
    func timeline(for configuration: SelectItemIntent, in context: Context) async -> Timeline<BoardEntry> {
        let store = StoreIO.read()
        let now = Date()
        let horizon = now.addingTimeInterval(24 * 3600)
        let ticks = stride(from: TimeInterval(0), to: 5 * 3600, by: 15 * 60).map { now.addingTimeInterval($0) }
        let boundaries = store.allBoundaries(after: now).filter { $0 < horizon }
        let dates = Set(ticks + boundaries).sorted().prefix(20)
        let entries = dates.map {
            BoardEntry(date: $0, store: store, selectedID: configuration.itemID)
        }
        return Timeline(entries: entries, policy: .after(dates.last ?? horizon))
    }

    /// One ready-made widget per item in the gallery.
    ///
    /// Without these, every small widget lands unconfigured and falls back to the
    /// first item on the board, so a two-item user gets the same face twice and no
    /// hint that it can be changed — "Edit Widget" is not something anyone thinks
    /// to look for. Picking the item at placement time is the whole point of a
    /// per-item widget, so the gallery has to offer it.
    ///
    /// Empty board returns nothing and the gallery falls back to the placeholder.
    func recommendations() -> [AppIntentRecommendation<SelectItemIntent>] {
        StoreIO.read().active.prefix(6).map { item in
            let intent = SelectItemIntent()
            intent.item = ItemEntity(id: item.id.uuidString, name: item.name)
            return AppIntentRecommendation(intent: intent, description: Text(item.name))
        }
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
        .description(Copy.Widget.description)
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
            single { item, _ in
                RectangularFace(item: item, items: entry.store.counted, states: entry.states)
            }
            .containerBackground(.clear, for: .widget)
        }
    }

    /// Single-item families, with the empty board handled once.
    @ViewBuilder
    private func single(@ViewBuilder _ face: (Item, ItemState) -> some View) -> some View {
        if let item = entry.selected {
            face(item, entry.store.state(item, now: entry.date))
        } else {
            EmptyFace()
        }
    }
}

@main
struct DidIWidgetBundle: WidgetBundle {
    var body: some Widget {
        DidIWidget()
    }
}
