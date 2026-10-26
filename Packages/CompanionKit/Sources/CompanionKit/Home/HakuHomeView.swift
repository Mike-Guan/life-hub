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

    init(model: HomeModel) {
        self.model = model
        scene = HomeScene(model: model)
    }
}

/// A panel opened from the room.
enum HomeSheet: String, Identifiable {
    case shelf, decorate, settings

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
        HomeChip(hotspot: .shop, title: "商店", symbol: "cart.fill", at: GridPoint(x: 9.5, y: 0.65, z: 4.4)),
        HomeChip(hotspot: .bed, title: "休息", symbol: "zzz", at: GridPoint(x: 8.6, y: 6.4, z: 2.5)),
        HomeChip(hotspot: nil, title: "家具", symbol: "sofa.fill", at: GridPoint(x: 1.4, y: 6.2, z: 2.4)),
        HomeChip(hotspot: .exit, title: "出门", symbol: "figure.walk", at: GridPoint(x: 4.6, y: 9.5, z: 0.7)),
    ]

    // Japanese and English labels run wider than two Chinese characters; "Furniture" is the widest.
    /// Half the drawn size of a label, in view points.
    static var half: CGSize { CGSize(width: Languages.isOn ? 46 : 30, height: 12) }
    /// The space kept between a label that stepped aside and the character, in view points.
    static let gap: CGFloat = 4

    // Mike 2026-10-18: the labels covered the character. One that would cover him steps above him, or below him
    // when there is no room above.
    /// How far a label centred at `center` moves down to clear `figure`, both in view points with y down; 0 when
    /// it doesn't cover it.
    static func dodge(_ center: CGPoint, figure: CGRect) -> CGFloat {
        let label = CGRect(
            x: center.x - half.width, y: center.y - half.height, width: 2 * half.width, height: 2 * half.height)
        guard !figure.isNull, label.intersects(figure) else { return 0 }
        let above = figure.minY - gap - half.height - center.y
        if center.y + above - half.height >= 0 { return above }
        return figure.maxY + gap + half.height - center.y
    }
}

/// What a label over the room shows: its symbol and title in a capsule.
struct HomeChipLabel: View {
    let chip: HomeChip

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: chip.symbol).font(.system(size: 10, weight: .bold))
            Text(chip.title.localized).font(Toy.body(11, weight: .bold))
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
}

/// A label over the room that steps aside while the character would be under it.
private struct HomeChipSpot<Label: View>: View {
    let model: HomeModel
    let center: CGPoint
    let scale: CGFloat
    let height: CGFloat
    @ViewBuilder let label: Label

    var body: some View {
        // The scene's y runs up from the bottom of the room; the view's runs down from its top.
        let f = model.figureFrame
        let figure =
            f.isNull
            ? CGRect.null
            : CGRect(x: f.minX * scale, y: height - f.maxY * scale, width: f.width * scale, height: f.height * scale)
        let dy = HomeChip.dodge(center, figure: figure)
        label
            .position(x: center.x, y: center.y + dy)
            .animation(.easeOut(duration: 0.25), value: dy)
    }
}

/// HAKU's home: the room in SpriteKit, the rest of the screen in SwiftUI, on the app's real data.
public struct HakuHomeView: View {
    private let snapshot: HomeSnapshot
    private let onSwitch: (Mode) -> Void
    private let onShop: (() -> Void)?
    private let onWardrobe: (() -> Void)?
    private let onSave: (RoomLayout) -> Void
    private let onExit: () -> Void
    @State private var stage: HomeStage
    @State private var sheet: HomeSheet?
    @State private var carrying = false
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameters:
    ///   - snapshot: What the page shows; pass a new one whenever the data changes.
    ///   - onSwitch: Switches the mode by hand, as the home screen's mode cards do.
    ///   - onShop: Opens the shop; without it the page shows no way into the shop.
    ///   - onWardrobe: Opens the wardrobe; without it the page shows no way into the wardrobe.
    ///   - onSave: Saves the room after a colour change.
    ///   - onExit: Called when the user leaves the home for the dashboard.
    public init(
        snapshot: HomeSnapshot,
        onSwitch: @escaping (Mode) -> Void,
        onShop: (() -> Void)?,
        onWardrobe: (() -> Void)?,
        onSave: @escaping (RoomLayout) -> Void,
        onExit: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onSwitch = onSwitch
        self.onShop = onShop
        self.onWardrobe = onWardrobe
        self.onSave = onSave
        self.onExit = onExit
        _stage = State(initialValue: HomeStage(model: HomeModel(snapshot: snapshot)))
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
            HomeSheetView(which: which, model: model, onSave: onSave, onExit: onExit)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: model.revision) {
            stage.scene.sync()
        }
        .onChange(of: snapshot) {
            model.apply(snapshot)
        }
    }

    // MARK: Header

    private func header(_ model: HomeModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verbatim: [Self.dateLine, model.mode.map(model.title)].compactMap { $0 }.joined(separator: " · "))
                    .font(Toy.body(13))
                    .foregroundStyle(Toy.muted)
                Spacer()
                Button {
                    onShop?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").foregroundStyle(Color(hex: 0x7CFF4F))
                        Text(verbatim: "\(model.cans)").font(Toy.body(15, weight: .heavy)).monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: 0x1B1C26)))
                    .foregroundStyle(.white)
                    .frame(minHeight: HomeGrid.minTap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onShop == nil)
                #if DEBUG
                Button {
                    model.toggleNight()
                } label: {
                    Image(systemName: model.isNight ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Toy.ink)
                        .frame(minWidth: HomeGrid.minTap, minHeight: HomeGrid.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                #endif
                Button {
                    sheet = .settings
                } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Toy.ink)
                        .frame(minWidth: HomeGrid.minTap, minHeight: HomeGrid.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text((model.isNight ? "晚上好" : "你好").localized)
                .font(Toy.display(28))
                .foregroundStyle(Toy.ink)
        }
    }

    // UI 审核 10-26: the order and comma follow each language (周一，10/26 · 10/26（月） · Mon, 10/26).
    private static var dateLine: String {
        let locale = Languages.locale
        let day = Date.now.formatted(Date.FormatStyle(locale: locale).month(.defaultDigits).day())
        let weekday = Date.now.formatted(Date.FormatStyle(locale: locale).weekday(.abbreviated))
        return String(format: "%1$@，%2$@".localized, weekday, day)
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
                    ForEach(chips) { chip in
                        let p = HomeGrid.plan(chip.at)
                        HomeChipSpot(
                            model: stage.model,
                            center: CGPoint(x: (p.x - canvas.minX) * scale, y: (p.y - canvas.minY) * scale),
                            scale: scale, height: geo.size.height
                        ) {
                            chipButton(chip)
                        }
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
                            open(stage.scene.hotspot(at: p, minSide: HomeGrid.minTap / scale))
                        }
                    }
            )
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
    }

    /// The labels over the room, without the ones whose page has nothing to open.
    private var chips: [HomeChip] {
        HomeChip.all.filter {
            switch $0.hotspot {
            case .shop: onShop != nil
            case .wardrobe: onWardrobe != nil
            default: true
            }
        }
    }

    private func chipButton(_ chip: HomeChip) -> some View {
        Button {
            if let hotspot = chip.hotspot { open(hotspot) } else { sheet = .decorate }
        } label: {
            HomeChipLabel(chip: chip)
                .frame(minWidth: HomeGrid.minTap, minHeight: HomeGrid.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func open(_ hotspot: HomeHotspot?) {
        guard let hotspot else { return }
        switch hotspot {
        case .exit:
            onExit()
            return
        case .wardrobe: onWardrobe?()
        case .shop: onShop?()
        case .shelf: sheet = .shelf
        default: break
        }
        stage.model.tap(hotspot)
    }

    // MARK: Below the room

    // UI 三组 10-26: the card shows whoever lives here, head only, in her mode's look.
    @ViewBuilder private func portrait(_ model: HomeModel) -> some View {
        let mode = model.mode ?? .chill
        let snapshot = model.snapshot
        if snapshot.persona == .kuro {
            KuroPortrait(
                look: KuroLook(mode: mode, card: model.card), energy: snapshot.energy?.value,
                wearing: snapshot.wardrobe.worn(in: mode), framing: .head)
        } else {
            CompanionPortrait(
                mode: mode, card: model.card, energy: snapshot.energy?.value, wardrobe: snapshot.wardrobe,
                idles: false, framing: .head)
        }
    }

    func lineCard(_ model: HomeModel) -> some View {
        Button {
            model.tap(.haku)
        } label: {
            HStack(spacing: 12) {
                portrait(model).frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: model.snapshot.persona.title).font(Toy.body(12, weight: .heavy))
                        .foregroundStyle(Toy.muted)
                    Text(model.line.localized(for: model.snapshot.persona))
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
                    onSwitch(mode)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: mode == .boxing ? (model.card?.symbol ?? mode.symbol) : mode.symbol).font(
                            .system(size: 20, weight: .bold)
                        ).frame(width: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.title(mode)).font(Toy.body(17, weight: .heavy))
                            Text(verbatim: model.snapshot.cards.code(for: mode, persona: model.snapshot.persona)).font(
                                Toy.body(11, weight: .bold)
                            ).foregroundStyle(Toy.muted)
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

/// The panels: reward shelf, decorating and settings.
private struct HomeSheetView: View {
    let which: HomeSheet
    let model: HomeModel
    let onSave: (RoomLayout) -> Void
    let onExit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.localized).font(Toy.display(22)).foregroundStyle(Toy.ink)
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
        case .shelf: "奖励架"
        case .decorate: "家具换颜色"
        case .settings: "设置"
        }
    }

    @ViewBuilder private var content: some View {
        switch which {
        case .shelf: shelf
        case .decorate: decorate
        case .settings: settings
        }
    }

    private var shelf: some View {
        VStack(spacing: 12) {
            Text("每一件都是真的发生过的事换来的。".localized).font(Toy.body(13)).foregroundStyle(Toy.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(model.keepsakes) { keepsake in
                Text(keepsake.name.localized).font(Toy.body(16, weight: .heavy))
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
                    Text(piece.name.localized).font(Toy.body(15, weight: .heavy))
                        .frame(width: Languages.isOn ? 72 : 44, alignment: .leading)
                    ForEach(Array(piece.swatches.enumerated()), id: \.offset) { index, hex in
                        let picked = model.color(piece) == hex
                        Button {
                            onSave(model.paint(piece, index))
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
            #if DEBUG
            Toggle(isOn: Binding(get: { model.isNight }, set: { _ in model.toggleNight() })) {
                Text(verbatim: "夜晚（DEBUG）").font(Toy.body(16, weight: .bold))
            }
            .tint(Color(hex: 0x58C25A))
            Toggle(isOn: Binding(get: { model.previewsAllItems }, set: { _ in model.togglePreviewItems() })) {
                Text(verbatim: "摆满所有物品（DEBUG）").font(Toy.body(16, weight: .bold))
            }
            .tint(Color(hex: 0x58C25A))
            #endif
            Button {
                dismiss()
                onExit()
            } label: {
                Text("出门，回首页".localized).font(Toy.body(15, weight: .heavy)).frame(maxWidth: .infinity).padding(12)
            }
            .buttonStyle(ToyButtonStyle(fill: Toy.card))
        }
        .padding(14)
        .toyCard()
    }
}

#endif
