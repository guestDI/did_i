import SwiftUI

/// Palette from the design project (`Did I.dc.html`), with one override.
///
/// No red anywhere; amber is the strongest colour in the product. The design
/// reserved amber for the toast and the CTA and drew unknown as a neutral grey
/// dash — architecture §1 and day-3 both make amber the expiry signal, and the
/// docs win. Unknown is amber. The dash glyph stays: it reads as absence of
/// information, not as failure.
public enum Palette {
    public static let ink = Color(hex: 0x131317)        // screen background
    public static let panel = Color(hex: 0x1A1A20)      // grouped rows
    public static let text = Color(hex: 0xEBE9E1)
    public static let sub = Color(hex: 0xA0A0AA)
    public static let muted = Color(hex: 0x8A8A94)
    public static let dim = Color(hex: 0x80808A)
    public static let rule = Color(hex: 0x212127)
    public static let ruleStrong = Color(hex: 0x26262C)

    public static let amber = Color(hex: 0xD9A03F)
    /// Text sitting on top of amber — the CTA's own ink.
    public static let onAmber = Color(hex: 0x171512)

    public static let fresh = Color(hex: 0x71D095)
    public static let aging = Color(hex: 0x95A698)
    public static let unknown = amber

    public static func color(for state: ItemState) -> Color {
        switch state {
        case .unknown: unknown
        case .confirmed(_, .fresh): fresh
        case .confirmed(_, .aging): aging
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The board typeface. IBM Plex Mono is not on iOS and is not bundled yet —
/// see decisions.md. SF Mono stands in and keeps the same tabular rhythm.
public func board(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}

/// `board`'s counterpart for lock screen accessories: a fixed `size:` never
/// grows with the user's text size setting, and on the surface most likely to
/// be read without glasses that reads as "too small", not compact.
public func boardScaled(_ style: Font.TextStyle, _ weight: Font.Weight = .semibold) -> Font {
    .system(style, design: .monospaced).weight(weight)
}

/// Preserves the design's tuned point size at the default text setting while
/// still following Dynamic Type. Replacing a 9pt/12pt/21pt hierarchy with the
/// nearest semantic presets changes the default UI; `@ScaledMetric` lets the
/// original hierarchy and accessibility coexist.
private struct ScaledBoardFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(board(size, weight))
    }
}

private struct ScaledAppFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

public extension View {
    func boardFont(
        _ size: CGFloat,
        _ weight: Font.Weight = .semibold,
        relativeTo style: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledBoardFontModifier(size: size, weight: weight, relativeTo: style))
    }

    func appFont(
        _ size: CGFloat,
        _ weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledAppFontModifier(size: size, weight: weight, relativeTo: style))
    }
}

/// One split-flap cell: the vertical gradient plus the hairline seam at 50%.
public struct FlapCell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let character: String
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat

    public init(
        _ character: String,
        color: Color,
        width: CGFloat,
        height: CGFloat,
        fontSize: CGFloat
    ) {
        self.character = character
        self.color = color
        self.width = width
        self.height = height
        self.fontSize = fontSize
    }

    /// A character change reads as the flap turning over: the old glyph leaves
    /// upward, the new one arrives from below. Reduced motion gets the cross-fade
    /// the Day 0 doc asks for on the practice card.
    private var flip: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .push(from: .bottom).combined(with: .opacity),
                removal: .push(from: .top).combined(with: .opacity)
            )
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x2A2A31), location: 0),
                    .init(color: Color(hex: 0x26262D), location: 0.47),
                    .init(color: Color(hex: 0x17171C), location: 0.53),
                    .init(color: Color(hex: 0x202026), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Rectangle()
                .fill(.black.opacity(0.55))
                .frame(height: 1)
            Text(character)
                .font(board(fontSize, .bold))
                .foregroundStyle(color)
                .id(character)
                .transition(flip)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.11, style: .continuous))
        .animation(.snappy(duration: 0.28), value: character)
    }
}

/// The word rendered as flaps, or three dashes when there is no record.
public struct FlapWord: View {
    let item: Item
    let state: ItemState
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let fontSize: CGFloat
    /// Total width the whole word must fit inside. A nine-cell word like
    /// UNPLUGGED otherwise runs over the item name; cells shrink to fit rather
    /// than the board losing its left column.
    let maxWidth: CGFloat?

    public init(
        item: Item,
        state: ItemState,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        fontSize: CGFloat,
        maxWidth: CGFloat? = nil
    ) {
        self.item = item
        self.state = state
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.fontSize = fontSize
        self.maxWidth = maxWidth
    }

    /// Uniform scale so the cells stay square-ish and the row stays a grid.
    private var scale: CGFloat {
        guard let maxWidth, characters.count > 1 else { return 1 }
        let spacing = cellWidth * 0.09
        let needed = cellWidth * CGFloat(characters.count)
            + spacing * CGFloat(characters.count - 1)
        return needed > maxWidth ? maxWidth / needed : 1
    }

    var characters: [String] {
        if case .unknown = state { return ["—", "—", "—"] }
        return item.word.uppercased().map(String.init)
    }

    public var body: some View {
        HStack(spacing: cellWidth * 0.09 * scale) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                FlapCell(
                    character,
                    color: Palette.color(for: state),
                    width: cellWidth * scale,
                    height: cellHeight,
                    fontSize: fontSize * scale
                )
            }
        }
    }
}
