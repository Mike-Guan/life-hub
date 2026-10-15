#if os(iOS) || os(macOS)
import HubCore
import SpriteKit
import SwiftUI

/// The model and the scene of one home, made together and kept for the view's life.
@MainActor
@Observable
final class HomeStage {
    let model: HomeModel
    let scene: HomeScene

    init(model: HomeModel = HomeModel()) {
        self.model = model
        scene = HomeScene(model: model)
    }
}

/// A panel opened from the room.
enum HomeSheet: String, Identifiable {
    case wardrobe, shop, shelf, decorate, settings

    var id: String { rawValue }
}

/// A label floating over the room that opens what it names.
struct HomeChip: Identifiable {
    let hotspot: HomeHotspot?
    let title: String
    let symbol: String
    let at: GridPoint

    var id: String { title }

    static let all = [
        HomeChip(hotspot: .shelf, title: "奖励", symbol: "trophy.fill", at: GridPoint(x: 0.3, y: 5.8, z: 5.7)),
        HomeChip(hotspot: .wardrobe, title: "衣柜", symbol: "tshirt.fill", at: GridPoint(x: 7.8, y: 0.65, z: 5.6)),
        HomeChip(hotspot: .shop, title: "商城", symbol: "cart.fill", at: GridPoint(x: 9.5, y: 0.65, z: 4.4)),
        HomeChip(hotspot: .bed, title: "休息", symbol: "zzz", at: GridPoint(x: 8.6, y: 6.4, z: 2.5)),
        HomeChip(hotspot: nil, title: "家具", symbol: "sofa.fill", at: GridPoint(x: 1.4, y: 6.2, z: 2.4)),
        HomeChip(hotspot: .exit, title: "出门", symbol: "figure.walk", at: GridPoint(x: 4.6, y: 9.5, z: 0.7)),
    ]
}

/// HAKU's home: the room in SpriteKit, the rest of the screen in SwiftUI. A prototype on mock data.
public struct HakuHomeView: View {
    private let onExit: () -> Void
    @State private var stage = HomeStage()
    @State private var sheet: HomeSheet?
    @State private var carrying = false
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameter onExit: Called when the user leaves the home for the dashboard.
    public init(onExit: @escaping () -> Void) {
        self.onExit = onExit
    }

    public var body: some View {
        let model = stage.model
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(model)
                room
                lineCard(model)
                modeGrid(model)
                today(model)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Toy.paper.ignoresSafeArea())
        .sheet(item: $sheet) { which in
            HomeSheetView(which: which, model: model, onExit: onExit)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: model.revision) {
            stage.scene.sync()
        }
    }

    // MARK: Header

    private func header(_ model: HomeModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: "\(Self.dateLine) · \(model.title(model.mode))")
                    .font(Toy.body(13))
                    .foregroundStyle(Toy.muted)
                Spacer()
                Button {
                    sheet = .shop
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").foregroundStyle(Color(hex: 0x7CFF4F))
                        Text(verbatim: "\(model.cans)").font(Toy.body(15, weight: .heavy)).monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: 0x1B1C26)))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button {
                    model.toggleNight()
                } label: {
                    Image(systemName: model.isNight ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Toy.ink)
                }
                .buttonStyle(.plain)
                Button {
                    sheet = .settings
                } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Toy.ink)
                }
                .buttonStyle(.plain)
            }
            Text(model.isNight ? "晚上好" : "你好")
                .font(Toy.display(28))
                .foregroundStyle(Toy.ink)
        }
    }

    private static var dateLine: String {
        let format = Date.FormatStyle().month(.defaultDigits).day().weekday(.abbreviated)
        return Date.now.formatted(format)
    }

    // MARK: Room

    private var room: some View {
        let canvas = HomeGrid.canvas
        return GeometryReader { geo in
            let scale = geo.size.width / canvas.width
            ZStack(alignment: .topLeading) {
                SpriteView(
                    scene: stage.scene, isPaused: scenePhase != .active, preferredFramesPerSecond: 60,
                    options: [.allowsTransparency]
                )
                .frame(width: geo.size.width, height: geo.size.height)
                if !carrying {
                    ForEach(HomeChip.all) { chip in
                        let p = HomeGrid.plan(chip.at)
                        chipButton(chip)
                            .position(x: (p.x - canvas.minX) * scale, y: (p.y - canvas.minY) * scale)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let toScene = { (v: CGPoint) in CGPoint(x: v.x / scale, y: (geo.size.height - v.y) / scale) }
                        let moved = hypot(value.translation.width, value.translation.height)
                        if !carrying, moved > 8 {
                            carrying = stage.scene.beginDrag(at: toScene(value.startLocation))
                        }
                        if carrying { stage.scene.drag(to: toScene(value.location)) }
                    }
                    .onEnded { value in
                        let p = CGPoint(x: value.location.x / scale, y: (geo.size.height - value.location.y) / scale)
                        if carrying {
                            stage.scene.endDrag(at: p)
                            carrying = false
                        } else if hypot(value.translation.width, value.translation.height) < 10 {
                            open(stage.scene.hotspot(at: p))
                        }
                    }
            )
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
    }

    private func chipButton(_ chip: HomeChip) -> some View {
        Button {
            if let hotspot = chip.hotspot { open(hotspot) } else { sheet = .decorate }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: chip.symbol).font(.system(size: 10, weight: .bold))
                Text(chip.title).font(Toy.body(11, weight: .bold))
            }
            .foregroundStyle(Toy.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Toy.card))
            .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                Circle().fill(Color(hex: 0x58C25A)).frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Toy.ink, lineWidth: 1.2))
                    .offset(x: 2, y: -2)
            }
        }
        .buttonStyle(.plain)
    }

    private func open(_ hotspot: HomeHotspot?) {
        guard let hotspot else { return }
        switch hotspot {
        case .exit:
            onExit()
            return
        case .wardrobe: sheet = .wardrobe
        case .shop: sheet = .shop
        case .shelf: sheet = .shelf
        default: break
        }
        stage.model.tap(hotspot)
    }

    // MARK: Below the room

    private func lineCard(_ model: HomeModel) -> some View {
        Button {
            model.tap(.haku)
        } label: {
            HStack(spacing: 12) {
                CompanionPortrait(mode: model.mode, energy: model.energy, idles: false, framing: .head)
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "HAKU").font(Toy.body(12, weight: .heavy)).foregroundStyle(Toy.muted)
                    Text(model.line)
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                        .id(model.line)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity))
                }
                .animation(.spring(duration: 0.35), value: model.line)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Toy.ink)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .toyCard(fill: Color(hex: 0xE4F5E1))
        }
        .buttonStyle(.plain)
    }

    private func modeGrid(_ model: HomeModel) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Mode.allCases) { mode in
                Button {
                    model.switchMode(mode)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: mode == .boxing ? model.card.symbol : mode.symbol).font(
                            .system(size: 20, weight: .bold)
                        ).frame(width: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.title(mode)).font(Toy.body(17, weight: .heavy))
                            Text(verbatim: mode.code).font(Toy.body(11, weight: .bold)).foregroundStyle(Toy.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(ToyButtonStyle(fill: mode.color, isSelected: model.mode == mode))
            }
        }
    }

    private func today(_ model: HomeModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "TODAY").font(Toy.body(14, weight: .black))
            ForEach(model.timeline.suffix(4).reversed()) { entry in
                HStack(spacing: 10) {
                    Text(verbatim: entry.time).font(Toy.body(13)).monospacedDigit().foregroundStyle(Toy.muted)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(entry.mode?.color ?? Color(hex: 0xC3C8D2))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Toy.ink, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                    Text(entry.title).font(Toy.body(14)).foregroundStyle(Toy.ink)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .toyCard()
    }
}

/// The panels: wardrobe, shop, reward shelf, decorating and settings.
private struct HomeSheetView: View {
    let which: HomeSheet
    let model: HomeModel
    let onExit: () -> Void
    @State private var confirming: HomeProduct?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Toy.display(22)).foregroundStyle(Toy.ink)
            ScrollView {
                content.padding(.bottom, 20)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Toy.paper.ignoresSafeArea())
    }

    private var title: String {
        switch which {
        case .wardrobe: "衣柜"
        case .shop: "商城 · \(model.cans) 罐"
        case .shelf: "奖励架"
        case .decorate: "家具换颜色"
        case .settings: "设置"
        }
    }

    @ViewBuilder private var content: some View {
        switch which {
        case .wardrobe: wardrobe
        case .shop: shop
        case .shelf: shelf
        case .decorate: decorate
        case .settings: settings
        }
    }

    private var wardrobe: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
            ForEach(HomeOutfit.allCases, id: \.self) { outfit in
                let owned = model.ownedOutfits.contains(outfit)
                Button {
                    model.wear(outfit)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        OutfitPreview(outfit: outfit).frame(height: 56).opacity(owned ? 1 : 0.35)
                        Text(outfit.name).font(Toy.body(12, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        Text(owned ? (model.outfit == outfit ? "穿着" : "换上") : "商城有")
                            .font(Toy.body(11)).foregroundStyle(Toy.muted)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ToyButtonStyle(fill: Color(hex: 0xE4F5E1), isSelected: model.outfit == outfit))
                .disabled(!owned)
            }
        }
    }

    private var shop: some View {
        VStack(spacing: 12) {
            if let product = confirming {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verbatim: "花 \(product.price) 罐买「\(product.name)」？")
                        .font(Toy.body(17, weight: .heavy))
                    Text(verbatim: "会放在\(product.place)。").font(Toy.body(14)).foregroundStyle(Toy.muted)
                    HStack(spacing: 12) {
                        Button {
                            confirming = nil
                        } label: {
                            Text("算了").font(Toy.body(15, weight: .bold)).frame(maxWidth: .infinity).padding(12)
                        }
                        .buttonStyle(ToyButtonStyle(fill: Toy.card))
                        Button {
                            if model.buy(product) { dismiss() }
                            confirming = nil
                        } label: {
                            Text("买").font(Toy.body(15, weight: .heavy)).frame(maxWidth: .infinity).padding(12)
                        }
                        .buttonStyle(ToyButtonStyle(fill: Color(hex: 0x7CC77F), isSelected: true))
                    }
                }
                .padding(14)
                .toyCard()
            }
            ForEach(HomeProduct.offered(card: model.card), id: \.self) { product in
                let owned = model.owns(product)
                let affordable = model.cans >= product.price
                HStack(spacing: 12) {
                    Image(systemName: Self.symbol(product)).font(.system(size: 20, weight: .bold)).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(Toy.body(15, weight: .heavy))
                        Text(product.place).font(Toy.body(12)).foregroundStyle(Toy.muted)
                    }
                    Spacer(minLength: 0)
                    Button {
                        confirming = product
                    } label: {
                        Text(owned ? "已有" : affordable ? "\(product.price) 罐" : "罐子不够")
                            .font(Toy.body(13, weight: .heavy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(ToyButtonStyle(fill: Color(hex: 0xFFD23F), isSelected: !owned && affordable))
                    .disabled(owned || !affordable)
                }
                .padding(12)
                .toyCard()
            }
        }
    }

    private static func symbol(_ product: HomeProduct) -> String {
        switch product {
        case .item(.plant): "leaf.fill"
        case .item(.bag): "figure.boxing"
        case .item(.cactus): "camera.macro"
        case .item(.speaker): "hifispeaker.fill"
        case .outfit: "tshirt.fill"
        }
    }

    private var shelf: some View {
        VStack(spacing: 12) {
            Text("每一件都是真的发生过的事换来的。").font(Toy.body(13)).foregroundStyle(Toy.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(model.keepsakes) { keepsake in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(keepsake.name).font(Toy.body(16, weight: .heavy))
                        Spacer()
                        Text(keepsake.date).font(Toy.body(12)).foregroundStyle(Toy.muted)
                    }
                    Text(keepsake.earned).font(Toy.body(13)).foregroundStyle(Toy.muted)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .toyCard()
            }
        }
    }

    private var decorate: some View {
        VStack(spacing: 12) {
            ForEach(HomePaintable.allCases, id: \.self) { piece in
                HStack(spacing: 12) {
                    Text(piece.name).font(Toy.body(15, weight: .heavy)).frame(width: 44, alignment: .leading)
                    ForEach(Array(piece.swatches.enumerated()), id: \.offset) { index, hex in
                        let picked = model.color(piece) == hex
                        Button {
                            model.paint(piece, index)
                        } label: {
                            Circle().fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(Toy.ink, lineWidth: picked ? 4 : 2))
                                .scaleEffect(picked ? 1.1 : 1)
                                .animation(.spring(duration: 0.25), value: picked)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .toyCard()
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { model.isNight }, set: { _ in model.toggleNight() })) {
                Text("夜晚").font(Toy.body(16, weight: .bold))
            }
            .tint(Color(hex: 0x58C25A))
            Button {
                dismiss()
                onExit()
            } label: {
                Text("出门，回首页").font(Toy.body(15, weight: .heavy)).frame(maxWidth: .infinity).padding(12)
            }
            .buttonStyle(ToyButtonStyle(fill: Toy.card))
            Text("这是「家」的原型：罐子、衣服和记录都是假数据，不影响真实记录。")
                .font(Toy.body(12)).foregroundStyle(Toy.muted)
        }
        .padding(14)
        .toyCard()
    }
}

/// A small drawing of a top from the wardrobe.
private struct OutfitPreview: View {
    let outfit: HomeOutfit

    var body: some View {
        Canvas { context, size in
            let rect = HakuNode.torsoRect
            let scale = min(size.width / rect.width, size.height / rect.height)
            context.translateBy(x: (size.width - rect.width * scale) / 2, y: (size.height - rect.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -rect.minX, y: -rect.minY)
            for part in outfit.parts {
                RunnerDrawing.draw(part, in: context, fillOverride: part == .jacket ? outfit.base : nil)
            }
        }
    }
}
#endif
