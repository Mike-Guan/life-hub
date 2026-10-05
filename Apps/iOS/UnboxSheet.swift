import CompanionKit
import HubCore
import SwiftUI

/// Shows a new item: HAKU pops out of a gift box wearing it, then Mike wears it now or keeps it for later.
struct UnboxSheet: View {
    let entry: CanEntry
    let item: ShopItem
    @Binding var wardrobe: Wardrobe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            if item.keepsake != nil {
                Text("纪念品")
                    .font(Toy.body(14, weight: .black))
                    .foregroundStyle(Toy.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(Capsule().fill(Mode.money.color))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
            }
            Text("新东西：\(item.title)")
                .font(Toy.display(30))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(Toy.body(15, weight: .heavy))
                .foregroundStyle(Toy.paper.opacity(0.75))

            // HAKU keeps wearing the item after the animation, so the preview has it equipped.
            CompanionView(
                mode: item.slot.showcaseMode,
                event: .unlock(id: entry.id.uuidString, item: item.id),
                wardrobe: wearing,
                showsBubble: true
            )
            .frame(height: 380)
            .toyCard()

            Spacer(minLength: 0)
            Button {
                wardrobe = wearing
                dismiss()
            } label: {
                Text("现在戴上")
                    .font(Toy.body(18, weight: .black))
                    .foregroundStyle(Toy.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(UnboxButtonStyle(fill: Mode.money.color, shadow: Toy.pink))
            Button {
                dismiss()
            } label: {
                Text("先放衣柜")
                    .font(Toy.body(16, weight: .black))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(UnboxButtonStyle(fill: Toy.ink, shadow: Toy.ink))
        }
        .foregroundStyle(Toy.paper)
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
        .background(Toy.ink.ignoresSafeArea())
        .onAppear { UnboxLog.markSeen(entry) }
    }

    private var wearing: Wardrobe {
        var copy = wardrobe
        copy.equip(item)
        return copy
    }

    private var subtitle: String {
        if let keepsake = item.keepsake {
            return "\(keepsake.count) 次\(keepsake.win.shopTitle)"
        }
        return "用 \(entry.cans) 个能量罐换的"
    }
}

/// The unboxing for `entry`, or nothing when its item isn't in this build's catalog.
struct UnboxCover: View {
    let entry: CanEntry
    @Binding var wardrobe: Wardrobe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let item = entry.itemID.flatMap(ShopItem.item) {
            UnboxSheet(entry: entry, item: item, wardrobe: $wardrobe)
        } else {
            Color.clear.onAppear {
                UnboxLog.markSeen(entry)
                dismiss()
            }
        }
    }
}

// The toy button style draws its shadow in ink, which disappears on this dark sheet.
/// An outlined button with a colored hard shadow, for dark backgrounds.
private struct UnboxButtonStyle: ButtonStyle {
    var fill: Color
    var shadow: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let offset: CGFloat = configuration.isPressed ? 4 : 0
        configuration.label
            .background(shape.fill(fill))
            .overlay(shape.stroke(fill == Toy.ink ? Toy.paper : Toy.ink, lineWidth: Toy.outline))
            .offset(x: offset, y: offset)
            .background(shape.fill(shadow).offset(x: 4, y: 4))
    }
}
