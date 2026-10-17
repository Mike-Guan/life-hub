#if os(iOS) || os(macOS)
import SpriteKit
import SwiftUI

/// A room item as the home draws it, for the shop's small icons.
public struct HomeItemIcon: View {
    let item: HomeItem

    /// - Parameter itemID: the shop catalog id, such as `room.bench`. `nil` when the home has no such item.
    public init?(itemID: String) {
        guard let item = HomeItem(shopID: itemID) else { return nil }
        self.item = item
    }

    public var body: some View {
        let layers = Self.layers(item)
        let crop = Self.square(layers.map(\.rect).reduce(CGRect.null) { $0.union($1) })
        Canvas { context, size in
            let scale = min(size.width / crop.width, size.height / crop.height)
            context.translateBy(x: (size.width - crop.width * scale) / 2, y: (size.height - crop.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -crop.minX, y: -crop.minY)
            for layer in layers { layer.draw(context, night: false) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// The layers that draw `item`: the bench comes with its bar on the rack.
    static func layers(_ item: HomeItem) -> [HomeLayer] {
        item == .bench ? [.item(.bench), .barbell] : [.item(item)]
    }

    /// The square around `rect`'s middle that holds it.
    static func square(_ rect: CGRect) -> CGRect {
        let side = max(rect.width, rect.height)
        return CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    }
}

/// The real room around one item where it stands, circled, with HAKU breathing and blinking next to it, over a still
/// of the same room. For the shop's preview before buying.
public struct HomeItemPreview: View {
    let item: HomeItem
    @State private var stage: HomeStage
    // Under the live room, so the preview still shows where SpriteKit can't draw (the CI simulator has no GPU).
    @State private var still: CGImage?
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameter itemID: the shop catalog id, such as `room.bench`. `nil` when the home has no such item.
    public init?(itemID: String) {
        guard let item = HomeItem(shopID: itemID) else { return nil }
        self.item = item
        let model = HomeModel(night: false, cans: 999)
        _ = model.buy(.item(item))
        model.standBeside(item)
        let stage = HomeStage(model: model)
        stage.scene.sync(animated: false)
        stage.scene.settle()
        _stage = State(initialValue: stage)
    }

    public var body: some View {
        let canvas = HomeGrid.canvas
        let ring = Self.ring(item)
        let crop = Self.crop(item, haku: stage.model.dropPoint)
        GeometryReader { geo in
            let scale = geo.size.width / crop.width
            ZStack(alignment: .topLeading) {
                if let still {
                    Image(decorative: still, scale: 2)
                        .resizable()
                        .frame(width: canvas.width * scale, height: canvas.height * scale)
                }
                SpriteView(scene: stage.scene, isPaused: scenePhase != .active, options: [.allowsTransparency])
                    .frame(width: canvas.width * scale, height: canvas.height * scale)
                Ellipse()
                    .stroke(Toy.pink, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                    .frame(width: ring.width * scale, height: ring.height * scale)
                    .offset(x: (ring.minX - canvas.minX) * scale, y: (ring.minY - canvas.minY) * scale)
            }
            .offset(x: -(crop.minX - canvas.minX) * scale, y: -(crop.minY - canvas.minY) * scale)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .onAppear { if still == nil { still = stage.scene.still(scale: 2) } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The plan rectangle the ring goes round.
    static func ring(_ item: HomeItem) -> CGRect {
        HomeGrid.bounds(HomeArt.boxes(item), margin: 8)
    }

    /// The square of the plan shown: the item, and HAKU standing at `haku`.
    static func crop(_ item: HomeItem, haku: GridPoint?) -> CGRect {
        var shown = ring(item)
        if let haku {
            let feet = HomeGrid.plan(haku)
            // He stands about 95 points tall.
            shown = shown.union(CGRect(x: feet.x - 30, y: feet.y - 105, width: 60, height: 112))
        }
        let square = HomeItemIcon.square(shown.insetBy(dx: -16, dy: -16))
        let side = max(square.width, 200)
        return CGRect(x: square.midX - side / 2, y: square.midY - side / 2, width: side, height: side)
    }
}
#endif
