import XCTest
import UIKit
@testable import DidICore

/// The Day 0 doc names icons conceptually — "iron", "window", "check" — and none
/// of those are SF Symbol names. An unresolved symbol renders as nothing, silently,
/// so the mapping is asserted against the real catalogue rather than trusted.
final class SymbolTests: XCTestCase {
    func testEveryChipSymbolResolves() {
        for chip in Chip.all {
            XCTAssertNotNil(
                UIImage(systemName: chip.symbol),
                "\(chip.label) points at missing SF Symbol \"\(chip.symbol)\""
            )
        }
    }
}
