import CompanionKit
import CoreTransferable
import HubCore
import SwiftUI
import UniformTypeIdentifiers

// Issue #352 PR B, 衣柜与纪念品预览 (UI 二组) and 分享卡与合影样张 v3.1. Sharing starts only from a tap on 「分享」:
// no prompt asks for it, and it gives no cans, no notification and no pop-up.

/// The bottom sheet that turns a card into a picture and hands it to the system share sheet.
struct ShareCardSheet: View {
    let card: ShareCard
    let words: ShareCard.Words
    @State private var pictures: [ShareCard.Shape: (picture: SharePicture, preview: Image)] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("分享")
                .font(Toy.display(22))
            ForEach(ShareCard.Shape.allCases, id: \.self) { shape in
                row(shape)
            }
            Text("卡上不放日期和地点。")
                .font(Toy.body(12, weight: .bold))
                .foregroundStyle(Toy.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
        .presentationDetents([.medium])
        .task { draw() }
    }

    @ViewBuilder private func row(_ shape: ShareCard.Shape) -> some View {
        let label = HStack(spacing: 12) {
            Image(systemName: shape == .story ? "iphone" : "square")
                .font(.system(size: 20, weight: .bold))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(shape == .story ? "竖版 9:16" : "方形 1:1")
                    .font(Toy.body(16, weight: .heavy))
                Text(shape == .story ? "快拍、朋友圈" : "发帖")
                    .font(Toy.body(12, weight: .bold))
                    .foregroundStyle(Toy.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 56)
        .toyCard(radius: 16, shadow: 3)
        if let drawn = pictures[shape] {
            ShareLink(item: drawn.picture, preview: SharePreview(words.title, image: drawn.preview)) { label }
                .buttonStyle(.plain)
        } else {
            label.opacity(0.5)
        }
    }

    private func draw() {
        for shape in ShareCard.Shape.allCases {
            let view = ShareCardView(card: card, words: words, shape: shape)
            if let image = view.image(), let png = SharePNG.data(image) {
                pictures[shape] = (SharePicture(png: png), Image(decorative: image, scale: 3))
            }
        }
    }
}

/// A rendered card, shared as a PNG.
struct SharePicture: Transferable, Sendable {
    let png: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
    }
}

/// A keepsake's page: how its character looked the day it arrived, its name and how it was earned.
struct KeepsakeDetailView: View {
    let item: ShopItem
    let persona: Persona
    /// How the keepsake was earned, such as "2026-11-02 · 累计 10 次拳击日".
    let earned: String
    /// The look kept from the day it arrived, `nil` when none was kept.
    let snapshot: Look?
    /// What the character wears now, shown when no look was kept.
    let wardrobe: Wardrobe
    @State private var sharing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                if let card {
                    stage(card)
                }
                // A keepsake from before snapshots shows her look now and never claims it was that day's.
                if snapshot != nil {
                    Text("那天的样子")
                        .font(Toy.body(13, weight: .heavy))
                        .foregroundStyle(Toy.muted)
                }
                Text(item.title)
                    .font(Toy.display(30))
                    .multilineTextAlignment(.center)
                Text(earned)
                    .font(Toy.body(14, weight: .bold))
                    .foregroundStyle(Toy.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
        .sheet(isPresented: $sharing) {
            if let card {
                ShareCardSheet(card: card, words: card.words(counting: counted))
            }
        }
    }

    private var card: ShareCard? {
        let look = snapshot ?? Look(mode: nil, wardrobe: wardrobe, card: .picked(for: persona))
        return ShareCard(persona: persona, look: look, item: item)
    }

    private var counted: String { item.keepsake?.title(for: persona) ?? "" }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .black))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("返回")
            Spacer()
            Button {
                sharing = true
            } label: {
                Text("分享")
                    .font(Toy.body(17, weight: .black))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(card == nil)
        }
        .buttonStyle(.plain)
    }

    // Dynamic: she breathes and blinks as at home, wearing the keepsake in the mode that shows it.
    private func stage(_ card: ShareCard) -> some View {
        let look = card.wornLook
        return Group {
            if persona == .kuro {
                KuroView(
                    look: KuroLook(mode: card.mode, card: look.card),
                    wearing: look.wardrobe.worn(in: card.mode),
                    showsBubble: false
                )
            } else {
                CompanionView(mode: card.mode, card: look.card, wardrobe: look.wardrobe, showsBubble: false)
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(card.mode.color(for: persona))
        .toyCard()
    }
}
