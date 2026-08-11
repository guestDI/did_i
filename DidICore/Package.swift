// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DidICore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DidICore", targets: ["DidICore"])
    ],
    targets: [
        .target(name: "DidICore"),
        .testTarget(name: "DidICoreTests", dependencies: ["DidICore"]),
    ]
)
