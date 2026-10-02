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
        .system(size: size, weight: .black, design: .rounded)
    }

    public static func body(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}
