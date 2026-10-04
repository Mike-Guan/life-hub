import HubCore
import SwiftUI

/// The Monster can, the shop's currency. Size it with `.frame`.
public struct CanIcon: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            // Drawn in a 20 x 24 box, scaled to fit.
            let scale = min(size.width / 20, size.height / 24)
            context.translateBy(x: (size.width - 20 * scale) / 2, y: (size.height - 24 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let can = Path(roundedRect: CGRect(x: 3, y: 2, width: 14, height: 20), cornerRadius: 3)
            context.fill(can, with: .color(RunnerPalette.mask))
            context.stroke(can, with: .color(RunnerPalette.ink), lineWidth: 2.5)
            let lid = Path(roundedRect: CGRect(x: 3, y: 2, width: 14, height: 4), cornerRadius: 1.5)
            context.fill(lid, with: .color(RunnerPalette.canLid))
            context.stroke(lid, with: .color(RunnerPalette.ink), lineWidth: 2.5)
            var bolt = Path()
            bolt.move(to: CGPoint(x: 11, y: 8))
            bolt.addLine(to: CGPoint(x: 7.5, y: 14))
            bolt.addLine(to: CGPoint(x: 10.5, y: 14))
            bolt.addLine(to: CGPoint(x: 9, y: 19))
            bolt.addLine(to: CGPoint(x: 13, y: 12.5))
            bolt.addLine(to: CGPoint(x: 10, y: 12.5))
            bolt.closeSubpath()
            context.fill(bolt, with: .color(RunnerPalette.neonCyan))
        }
        .aspectRatio(20.0 / 24.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// Drawn from HAKU's own vector parts, cropped to the part the item changes, so the icon always
// matches what HAKU wears.
/// A wardrobe item as a small square picture, for the shop and wardrobe screens.
public struct WardrobeItemIcon: View {
    let picture: ItemPicture

    /// - Parameter item: the catalog item to draw.
    public init(item: ShopItem) {
        var wardrobe = Wardrobe()
        wardrobe.equip(item)
        picture = ItemPicture(slot: item.slot, outfit: Outfit(wardrobe), itemID: item.id)
    }

    /// The default look of `slot`, before anything is worn there. Draws nothing for `.room`.
    public init(slotDefault slot: Slot) {
        picture = ItemPicture(slot: slot, outfit: Outfit(), itemID: nil)
    }

    public var body: some View {
        Canvas { context, size in
            let crop = picture.crop
            let scale = min(size.width / crop.width, size.height / crop.height)
            context.translateBy(x: (size.width - crop.width * scale) / 2, y: (size.height - crop.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -crop.minX, y: -crop.minY)
            for part in picture.parts {
                RunnerDrawing.draw(part, in: context, red: picture.red)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Which parts an item icon draws, in which color, and the square of figure space it shows.
struct ItemPicture: Equatable {
    var parts: [RunnerPart]
    /// Replaces boxing red, for gloves and headbands.
    var red: Color?
    /// The square shown, in SVG units.
    var crop: CGRect

    init(slot: Slot, outfit: Outfit, itemID: String?) {
        switch slot {
        case .gloves:
            parts = [.gloveR]
            red = outfit.gloves
            crop = CGRect(x: 66, y: 101, width: 40, height: 40)
        case .headband:
            parts = [.headband]
            red = outfit.headband
            crop = CGRect(x: 23, y: -0.5, width: 86, height: 86)
        case .mask:
            parts = [.maskUp, outfit.stripedMask ? .maskStripes : .panelLines, .ledLine]
            crop = CGRect(x: 29, y: 51, width: 62, height: 62)
        case .room:
            parts = outfit.room.map { [$0] } ?? []
            crop = CGRect(x: -8, y: 94, width: 48, height: 48)
        case .celebration:
            // The first get-up keepsake adds a sneaky peace sign; the default is the sparkle burst.
            let peace = itemID == "celebrate.up"
            parts = peace ? [.peaceHand] : [.sparkle]
            crop = peace ? CGRect(x: 77, y: 48, width: 40, height: 40) : CGRect(x: 3, y: 14, width: 20, height: 20)
        }
    }
}

extension Slot {
    /// The tile color behind items of this slot in the shop and wardrobe.
    public var tileColor: Color {
        switch self {
        case .gloves: Mode.boxing.color
        case .headband: Mode.work.color
        case .mask: Mode.money.color
        case .room: Mode.chill.color
        case .celebration: Toy.pink
        }
    }

    /// The mode in which HAKU shows items of this slot, for the unboxing.
    public var showcaseMode: Mode {
        switch self {
        case .gloves, .headband: .boxing
        case .mask: .work
        case .room, .celebration: .chill
        }
    }
}
