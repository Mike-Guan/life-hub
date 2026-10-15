import CoreText
import HubCore
import SwiftUI

/// Style E tokens: thick black outline, flat bright colors, hard offset shadow.
public enum Toy {
    public static let ink = Color(hex: 0x111111)
    public static let paper = Color(hex: 0xFFF4DF)
    public static let card = Color(hex: 0xFFFFFF)
    public static let muted = Color(hex: 0x6B6257)
    public static let pink = Color(hex: 0xFF3EA5)
    public static let alert = Color(hex: 0xFF4D4D)

    public static let outline: CGFloat = 3
    public static let shadow: CGFloat = 5
    public static let radius: CGFloat = 18

    public static func display(_ size: CGFloat) -> Font {
        font(size, weight: .black)
    }

    public static func body(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        font(size, weight: weight)
    }

    private static func font(_ size: CGFloat, weight: Font.Weight) -> Font {
        if let face = japaneseFace(weight, language: Languages.locale.language), isRegistered(face) {
            return .custom(face, fixedSize: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    // The watch app does not register the fonts; there Japanese keeps the system font instead of a plain fallback.
    private static func isRegistered(_ face: String) -> Bool {
        CTFontCopyPostScriptName(CTFontCreateWithName(face as CFString, 12, nil)) as String == face
    }

    // Three-language typesetting spec §1 (UI 二组): Japanese text uses Zen Maru Gothic, Bold for semibold and bold,
    // Black for heavy and black. Lighter weights, Chinese and English keep the rounded system font.
    /// The bundled Japanese face for `weight` in `language`.
    /// - Parameters:
    ///   - weight: The weight the text asks for.
    ///   - language: The language the text is shown in.
    /// - Returns: The face's PostScript name, or `nil` to use the system font.
    static func japaneseFace(_ weight: Font.Weight, language: Locale.Language) -> String? {
        guard language.languageCode == .japanese else { return nil }
        switch weight {
        case .semibold, .bold: return AppFonts.japaneseBold
        case .heavy, .black: return AppFonts.japaneseBlack
        default: return nil
        }
    }

    /// Extra space between lines of text at `size` points, for `language`.
    /// - Parameters:
    ///   - size: The font size in points.
    ///   - language: The language of the text. Defaults to the current locale's language.
    /// - Returns: 4 pt for Chinese or Japanese text at 14 pt and up, 3 pt below that, 2 pt for other languages.
    public static func lineSpacing(_ size: CGFloat, language: Locale.Language = Locale.current.language) -> CGFloat {
        // Values come from the three-language typesetting spec (UI 二组).
        switch language.languageCode {
        case .chinese?, .japanese?: size >= 14 ? 4 : 3
        default: 2
        }
    }
}

extension Color {
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Outlined card with a hard shadow.
public struct ToyCard: ViewModifier {
    var fill: Color
    var radius: CGFloat
    var shadow: CGFloat

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(fill))
            .clipShape(shape)
            .overlay(shape.stroke(Toy.ink, lineWidth: Toy.outline))
            .background(shape.fill(Toy.ink).offset(x: shadow, y: shadow))
    }
}

extension View {
    public func toyCard(fill: Color = Toy.card, radius: CGFloat = Toy.radius, shadow: CGFloat = Toy.shadow) -> some View
    {
        modifier(ToyCard(fill: fill, radius: radius, shadow: shadow))
    }
}

/// A button that physically presses into its shadow.
public struct ToyButtonStyle: ButtonStyle {
    var fill: Color
    var isSelected: Bool

    public init(fill: Color, isSelected: Bool = false) {
        self.fill = fill
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed || isSelected
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        configuration.label
            .foregroundStyle(Toy.ink)
            .background(shape.fill(isSelected ? fill : Toy.card))
            .overlay(shape.stroke(Toy.ink, lineWidth: Toy.outline))
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .background(shape.fill(Toy.ink).offset(x: 4, y: 4))
            .animation(.smooth(duration: 0.18), value: pressed)
    }
}
