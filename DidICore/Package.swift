// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DidICore",
    // `defaultLocalization` is what makes `Bundle.module` resolve a catalog, and
    // what `String(localized:)` falls back to for any key a locale has not
    // translated yet. Every key's default value is its own English text, so a
    // missing translation degrades to English rather than to a raw key.
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DidICore", targets: ["DidICore"])
    ],
    targets: [
        .target(name: "DidICore", resources: [.process("Resources")]),
        .testTarget(name: "DidICoreTests", dependencies: ["DidICore"]),
    ]
)
