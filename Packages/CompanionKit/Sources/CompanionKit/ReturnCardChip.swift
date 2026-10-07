import HubCore
import SwiftUI

/// One thing recorded while Mike was away, as a chip with its picture.
struct ReturnCardChip: View {
    let card: ReturnCard

    var body: some View {
        HStack(spacing: 8) {
            ReturnCardIcon(card: card)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(Mode.chill.color))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Toy.ink, lineWidth: 2))
            Text(card.text)
                .font(Toy.body(15, weight: .bold))
                .foregroundStyle(Toy.ink)
                .lineLimit(2)
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .toyCard(fill: Toy.paper, radius: 10, shadow: 3)
    }
}

/// The cans earned while Mike was away, opened together.
struct CansChip: View {
    let cans: Int

    var body: some View {
        HStack(spacing: 6) {
            CanIcon().frame(height: 20)
            Text("\(cans) 罐，一起打开")
                .font(Toy.body(15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Toy.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .toyCard(fill: RunnerPalette.monsterGreen, radius: 10, shadow: 3)
    }
}

/// The picture on a return card: the keepsake itself, or HAKU's own part for what happened.
struct ReturnCardIcon: View {
    let card: ReturnCard

    var body: some View {
        if card.kind == .keepsake, let id = card.item, let item = ShopItem.item(id) {
            WardrobeItemIcon(item: item).padding(3)
        } else {
            let parts = Self.parts(card)
            Canvas { context, size in
                let crop = Self.crop(parts)
                let scale = min(size.width / crop.width, size.height / crop.height)
                let inset = CGSize(width: size.width - crop.width * scale, height: size.height - crop.height * scale)
                context.translateBy(x: inset.width / 2, y: inset.height / 2)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -crop.minX, y: -crop.minY)
                for part in parts {
                    RunnerDrawing.draw(part, in: context)
                }
            }
            .padding(3)
            .accessibilityHidden(true)
        }
    }

    /// The parts that picture `card`.
    nonisolated static func parts(_ card: ReturnCard) -> [RunnerPart] {
        switch card.kind {
        case .boxing: [.backFist]
        case .run5k: [.runShoe]
        case .gym: [.dumbbell]
        case .sleptWell: [.zzz]
        case .plannedTask: [.stickyNote]
        case .keepsake: [.sparkle]
        case .trace:
            switch card.item.flatMap(CompanionTrace.init(rawValue:)) {
            case .wornGloves: [.gloveR, .gloveTapeRight]
            case .runningShoes: [.runningShoes]
            case .deskMonitor: [.deskMonitor]
            case .bandage: [.bandage]
            case .pcGlow: [.roomPc]
            case .sunlight: [.sunlight]
            case nil: [.sparkle]
            }
        }
    }

    /// The square of figure space around `parts`, in SVG units.
    nonisolated static func crop(_ parts: [RunnerPart]) -> CGRect {
        let box = parts.flatMap(RunnerArt.cachedInks).reduce(CGRect.null) { $0.union($1.path.boundingRect) }
        guard !box.isNull else { return RunnerArt.bounds }
        let side = max(box.width, box.height) + 6
        return CGRect(x: box.midX - side / 2, y: box.midY - side / 2, width: side, height: side)
    }
}
