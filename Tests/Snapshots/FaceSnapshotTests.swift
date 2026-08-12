import XCTest
import SwiftUI
@testable import DidICore

/// architecture.md §8: every state × every family × both colour schemes.
/// "The widget is the product; a layout break there is a total failure, and it
/// is the surface you will look at least often during development."
@MainActor
final class FaceSnapshotTests: XCTestCase {

    // The design's own dimensions (Did I.dc.html, 1c–1e).
    static let small = CGSize(width: 158, height: 158)
    static let medium = CGSize(width: 338, height: 158)
    static let circular = CGSize(width: 72, height: 72)
    static let rectangular = CGSize(width: 172, height: 72)

    let schemes: [(ColorScheme, String)] = [(.dark, "dark"), (.light, "light")]

    /// The faces do not paint their own background — the widget supplies it via
    /// `containerBackground`. Snapshots must composite on the same ground, or
    /// they test near-white text on white and prove nothing.
    func homeScreen(_ view: some View) -> some View {
        view
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.ink)
    }

    /// The lock screen renders accessory families in monochrome over the
    /// wallpaper. Approximated: white on black, so opacity carries the state.
    func lockScreen(_ view: some View) -> some View {
        view
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
    }

    // MARK: - Fixtures

    /// Fixed instants, so "14M" and "6H" never drift with the wall clock.
    static let now = Date(timeIntervalSince1970: 1_786_000_000)

    func fixture(
        _ name: String,
        word: String,
        symbol: String,
        state: Fixture,
        order: Int = 0
    ) -> Item {
        var item = Item(
            name: name, word: word, symbol: symbol,
            resetRule: .dailyAt(hour: 4),
            createdAt: Self.now.addingTimeInterval(-86_400),
            order: order
        )
        switch state {
        case .unknown:
            item.lastConfirmedAt = nil
        case .fresh:
            item.lastConfirmedAt = Self.now.addingTimeInterval(-14 * 60)
            item.confirmationLine = "Yep. Consider it handled."
        case .aging:
            item.lastConfirmedAt = Self.now.addingTimeInterval(-6 * 3600)
        }
        return item
    }

    enum Fixture: String, CaseIterable {
        case unknown, fresh, aging

        var state: ItemState {
            switch self {
            case .unknown: .unknown
            case .fresh: .confirmed(age: 14 * 60, freshness: .fresh)
            case .aging: .confirmed(age: 6 * 3600, freshness: .aging)
            }
        }
    }

    /// The longest line in the pool, to catch the two-line overflow case.
    func worstCaseFresh() -> Item {
        var item = fixture("The space heater", word: "Off", symbol: "flame", state: .fresh)
        item.confirmationLine = "Got it. Nothing is on fire, probably because of you."
        return item
    }

    func board() -> ([Item], [UUID: ItemState]) {
        let items = [
            fixture("Front door", word: "Locked", symbol: "lock", state: .fresh, order: 0),
            fixture("The stove", word: "Off", symbol: "flame", state: .unknown, order: 1),
            fixture("Iron", word: "Unplugged", symbol: "powerplug", state: .aging, order: 2),
            fixture("Garage door", word: "Down", symbol: "door.garage.closed", state: .fresh, order: 3),
        ]
        let states: [UUID: ItemState] = [
            items[0].id: Fixture.fresh.state,
            items[1].id: Fixture.unknown.state,
            items[2].id: Fixture.aging.state,
            items[3].id: Fixture.fresh.state,
        ]
        return (items, states)
    }

    // MARK: - systemSmall

    func testSmallFace() {
        for fixture in Fixture.allCases {
            let item = self.fixture("The stove", word: "Off", symbol: "flame", state: fixture)
            for (scheme, schemeName) in schemes {
                assertSnapshot(
                    of: homeScreen(SmallFace(item: item, state: fixture.state)),
                    size: Self.small, scheme: scheme,
                    named: "small-\(fixture.rawValue)-\(schemeName)"
                )
            }
        }
    }

    func testSmallFaceWithTheLongestLineInThePool() {
        let item = worstCaseFresh()
        for (scheme, schemeName) in schemes {
            assertSnapshot(
                of: homeScreen(SmallFace(item: item, state: Fixture.fresh.state)),
                size: Self.small, scheme: scheme,
                named: "small-longest-line-\(schemeName)"
            )
        }
    }

    // MARK: - systemMedium

    func testMediumFace() {
        for fixture in Fixture.allCases {
            let items = (0..<4).map {
                self.fixture("Item \($0 + 1)", word: "Off", symbol: "flame", state: fixture, order: $0)
            }
            let states = Dictionary(uniqueKeysWithValues: items.map { ($0.id, fixture.state) })
            for (scheme, schemeName) in schemes {
                assertSnapshot(
                    of: homeScreen(MediumFace(items: items, states: states, date: Self.now)),
                    size: Self.medium, scheme: scheme,
                    named: "medium-\(fixture.rawValue)-\(schemeName)"
                )
            }
        }
    }

    func testMediumFaceMixedBoard() {
        let (items, states) = board()
        for (scheme, schemeName) in schemes {
            assertSnapshot(
                of: homeScreen(MediumFace(items: items, states: states, date: Self.now)),
                size: Self.medium, scheme: scheme,
                named: "medium-mixed-\(schemeName)"
            )
        }
    }

    func testMediumFacePartialBoard() {
        // Two items must not leave a lopsided grid.
        let (all, states) = board()
        let items = Array(all.prefix(2))
        for (scheme, schemeName) in schemes {
            assertSnapshot(
                of: homeScreen(MediumFace(items: items, states: states, date: Self.now)),
                size: Self.medium, scheme: scheme,
                named: "medium-two-items-\(schemeName)"
            )
        }
    }

    func testMediumFaceFullBoard() {
        // Six is the cap, and all six have to be on the face. This is the layout
        // most likely to overflow — three rows into the same height.
        let (four, states) = board()
        var items = four
        var states6 = states
        for extra in [
            fixture("Bathroom window", word: "Shut", symbol: "window.vertical.closed",
                    state: .unknown, order: 4),
            fixture("Straighteners", word: "Off", symbol: "powerplug", state: .aging, order: 5),
        ] {
            items.append(extra)
            states6[extra.id] = extra.order == 4 ? Fixture.unknown.state : Fixture.aging.state
        }
        for (scheme, schemeName) in schemes {
            assertSnapshot(
                of: homeScreen(MediumFace(items: items, states: states6, date: Self.now)),
                size: Self.medium, scheme: scheme,
                named: "medium-six-items-\(schemeName)"
            )
        }
    }

    // MARK: - accessoryCircular

    func testCircularFace() {
        for fixture in Fixture.allCases {
            let item = self.fixture("The stove", word: "Off", symbol: "flame", state: fixture)
            for (scheme, schemeName) in schemes {
                assertSnapshot(
                    of: lockScreen(CircularFace(item: item, state: fixture.state)),
                    size: Self.circular, scheme: scheme,
                    named: "circular-\(fixture.rawValue)-\(schemeName)"
                )
            }
        }
    }

    // MARK: - accessoryRectangular

    func testRectangularFace() {
        let (items, states) = board()
        let cases: [(String, [UUID: ItemState])] = [
            ("mixed", states),
            ("none", Dictionary(uniqueKeysWithValues: items.map { ($0.id, ItemState.unknown) })),
            ("all", Dictionary(uniqueKeysWithValues: items.map { ($0.id, Fixture.fresh.state) })),
        ]
        for (label, states) in cases {
            for (scheme, schemeName) in schemes {
                assertSnapshot(
                    of: lockScreen(RectangularFace(items: items, states: states).padding(9)),
                    size: Self.rectangular, scheme: scheme,
                    named: "rectangular-\(label)-\(schemeName)"
                )
            }
        }
    }

    func testRectangularFaceEmptyBoard() {
        for (scheme, schemeName) in schemes {
            assertSnapshot(
                of: lockScreen(RectangularFace(items: [], states: [:]).padding(9)),
                size: Self.rectangular, scheme: scheme,
                named: "rectangular-empty-\(schemeName)"
            )
        }
    }
}
