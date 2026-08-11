import XCTest
import SwiftUI
import UIKit

/// A minimal snapshot harness. No third-party dependency, so: render with
/// `ImageRenderer`, decode both sides into RGBA8, and compare with a tolerance.
///
/// **To re-record:** delete the reference PNG (or the whole `__Snapshots__`
/// directory) and re-run. A missing reference is written and reported as a
/// failure, so a new or re-recorded case can never pass on its first run.
/// There is deliberately no environment-variable switch — `xcodebuild` does not
/// forward shell environment to the simulator test runner, so one would look
/// like it worked while silently doing nothing.
enum Snapshot {
    /// Antialiasing shifts a handful of pixels between OS point releases.
    /// A byte has to move by more than this to count, and more than
    /// `maxDifferingFraction` of them have to move to fail.
    static let channelTolerance = 12
    static let maxDifferingFraction = 0.02

    static func directory(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .appending(path: "__Snapshots__")
    }
}

@MainActor
func assertSnapshot(
    of view: some View,
    size: CGSize,
    scheme: ColorScheme,
    named name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let content = view
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, scheme)
        .environment(\.locale, Locale(identifier: "en_GB"))
        .environment(\.timeZone, TimeZone(identifier: "UTC")!)

    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    renderer.isOpaque = false

    guard let rendered = renderer.cgImage else {
        return XCTFail("ImageRenderer produced nothing for \(name)", file: file, line: line)
    }

    let directory = Snapshot.directory()
    let reference = directory.appending(path: "\(name).png")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    guard let data = try? Data(contentsOf: reference),
          let stored = UIImage(data: data)?.cgImage
    else {
        write(rendered, to: reference)
        return XCTFail(
            "Recorded \(name). Re-run to compare.",
            file: file, line: line
        )
    }

    guard stored.width == rendered.width, stored.height == rendered.height else {
        write(rendered, to: directory.appending(path: "\(name).failed.png"))
        return XCTFail(
            "\(name): size changed, \(stored.width)×\(stored.height) → \(rendered.width)×\(rendered.height)",
            file: file, line: line
        )
    }

    let a = pixels(of: stored)
    let b = pixels(of: rendered)
    let differing = zip(a, b).reduce(into: 0) { count, pair in
        if abs(Int(pair.0) - Int(pair.1)) > Snapshot.channelTolerance { count += 1 }
    }
    let fraction = Double(differing) / Double(max(a.count, 1))

    if fraction > Snapshot.maxDifferingFraction {
        write(rendered, to: directory.appending(path: "\(name).failed.png"))
        XCTFail(
            String(format: "%@: %.2f%% of channels differ", name, fraction * 100),
            file: file, line: line
        )
    }
}

private func pixels(of image: CGImage) -> [UInt8] {
    let width = image.width, height = image.height
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    buffer.withUnsafeMutableBytes { raw in
        let context = CGContext(
            data: raw.baseAddress,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return buffer
}

private func write(_ image: CGImage, to url: URL) {
    guard let data = UIImage(cgImage: image).pngData() else { return }
    try? data.write(to: url)
}
