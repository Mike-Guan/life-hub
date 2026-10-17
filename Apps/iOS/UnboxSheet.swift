import CompanionKit
import HubCore
import SwiftUI

/// Shows a new item: its character pops out of a gift box with it, then Mike wears it now or keeps it for later.
struct UnboxSheet: View {
    let entry: CanEntry
    let item: ShopItem
    @Binding var wardrobe: Wardrobe
    let persona: Persona
    /// The mode HAKU is in now, so it pops out in that mode's look when the item shows there.
    var mode: Mode?
    /// Opens scrolled to the buttons. Only screenshots set it.
    var startsAtBottom = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Scrolls so the buttons stay reachable on small phones, where the 380 pt stage leaves no room.
        ScrollView {
            content
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(startsAtBottom ? .bottom : nil)
        .foregroundStyle(Toy.paper)
        .background(Toy.ink.ignoresSafeArea())
        .onAppear { UnboxLog.markSeen(entry) }
    }

    private var content: some View {
        VStack(spacing: 18) {
            if item.keepsake != nil {
                Text("纪念品")
                    .font(Toy.body(14, weight: .black))
                    .foregroundStyle(Toy.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(Capsule().fill(Mode.money.color(for: persona)))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
            }
            Text("新东西：\(item.title)")
                .font(Toy.display(30))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(Toy.body(15, weight: .heavy))
                .foregroundStyle(Toy.paper.opacity(0.75))

            // The character keeps wearing the item after the animation, so the preview has it equipped.
            // Clothes show in the mode they are worn in.
            Group {
                if let kuro = KuroItem(rawValue: item.id) {
                    KuroView(
                        look: kuro.look,
                        wearing: wearing.worn(in: item.previewMode(current: nil, card: card)),
                        event: .unlock(id: entry.id.uuidString, item: item.id)
                    )
                } else {
                    CompanionView(
                        mode: shownMode,
                        card: card,
                        event: .unlock(id: entry.id.uuidString, item: item.id),
                        wardrobe: wearing,
                        showsBubble: true,
                        notices: false
                    )
                }
            }
            // UI 二组 交付差距 v1 #8: VoiceOver read the character's mode, not the item coming out of the box.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: "开箱：%@".localized, item.title))
            // UI 审核 R1: on small phones, at any text size, both buttons stay on the first screen,
            // so the stage gives up height.
            .containerRelativeFrame(.vertical) { [chrome] height, _ in min(380, max(240, height - chrome)) }
            .toyCard()

            Button {
                // Room items live in the home page, which places every owned one, so nothing is equipped.
                if item.slot != .room {
                    wardrobe = wearing
                }
                dismiss()
            } label: {
                Text(buttons.use)
                    .font(Toy.body(18, weight: .black))
                    .foregroundStyle(Toy.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(UnboxButtonStyle(fill: Mode.money.color(for: persona), shadow: Toy.pink))
            if let keep = buttons.keep {
                Button {
                    dismiss()
                } label: {
                    Text(keep)
                        .font(Toy.body(16, weight: .black))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(UnboxButtonStyle(fill: Toy.ink, shadow: Toy.ink))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
    }

    // Grows with the text size, so large type still leaves both buttons on the first screen.
    /// Height of everything on the sheet but the stage.
    @ScaledMetric(relativeTo: .body) private var chrome: CGFloat = 360

    private var card: IdentityKind? { .picked(for: persona) }

    // Friends test (写死作息 #3): HAKU no longer always pops out in the boxing kit.
    private var shownMode: Mode { item.previewMode(current: mode, card: card) }

    private var wearing: Wardrobe {
        var copy = wardrobe
        copy.equip(item)
        return copy
    }

    // PM 10-15: a room item isn't worn and a celebration is played, so the buttons say what happens to each.
    // A room item goes into the home page by itself (商店与家 同步方案 §4), so it has no second button.
    /// The two button titles for the item's kind; `keep` is `nil` when there is nothing to choose.
    private var buttons: (use: LocalizedStringKey, keep: LocalizedStringKey?) {
        switch item.slot {
        case .room: ("摆进家里", nil)
        case .celebration: ("现在用上", "先放衣柜")
        default: ("现在戴上", "先放衣柜")
        }
    }

    private var subtitle: String {
        if let keepsake = item.keepsake {
            return "\(keepsake.count) 次\(keepsake.title(for: persona))"
        }
        return "用 \(entry.cans) 个能量罐换的"
    }
}

/// The unboxing for `entry`, or nothing when its item isn't in this build's catalog.
struct UnboxCover: View {
    let entry: CanEntry
    @Binding var wardrobe: Wardrobe
    let persona: Persona
    var mode: Mode?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let item = entry.itemID.flatMap(ShopItem.item) {
            UnboxSheet(entry: entry, item: item, wardrobe: $wardrobe, persona: persona, mode: mode)
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
