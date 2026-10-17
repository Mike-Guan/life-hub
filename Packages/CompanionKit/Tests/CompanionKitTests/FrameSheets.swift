#if os(macOS)
import Foundation
import HubCore
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import CompanionKit

/// Draws the companion's real views frame by frame into PNG sheets for the UI review.
/// Runs only when `FRAME_SHEETS` names the folder to write to (the frames workflow sets it).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FRAME_SHEETS"] != nil))
@MainActor
struct FrameSheets {
    /// One row of a sheet: a label and the view at each frame time.
    struct Row {
        let label: String
        let start: Date
        let draw: () -> AnyView
    }

    // A Tuesday at 10:00 UTC, so the Sunday-afternoon idle bit never shows by accident.
    static let base = Date(timeIntervalSinceReferenceDate: 812_973_600)
    static let frames = 10
    static let step: TimeInterval = 0.4
    static let energies: [(String, Double)] = [("累 20", 20), ("中 50", 50), ("满 85", 85)]

    @Test func hakuModes() throws {
        var rows: [Row] = []
        for mode in Mode.allCases {
            for (name, energy) in Self.energies {
                rows.append(
                    Row(label: "\(mode.rawValue) · \(name)", start: Self.base) {
                        AnyView(CompanionView(mode: mode, energy: energy))
                    })
            }
        }
        try write("haku-1-modes", rows)
    }

    @Test func hakuChillIdle() throws {
        let lives: [IdleLife?] = [nil, .handheld, .snack, .drawing, .nap, .practice]
        let rows = lives.map { life in
            Row(label: "chill · \(life.map { "\($0)" } ?? "plain")", start: Self.start(for: life)) {
                AnyView(CompanionView(mode: .chill, energy: 50))
            }
        }
        try write("haku-2-chill-idle", rows)
    }

    @Test func hakuNeeds() throws {
        let needs: [(CompanionNeed, Mode)] = [
            (.couchScroll, .chill), (.boxingWarmup, .boxing), (.gymDay, .chill), (.slacking, .work), (.sitting, .work),
        ]
        let rows = needs.map { need, mode in
            Row(label: "\(mode.rawValue) · need \(need)", start: Self.base) {
                AnyView(CompanionView(mode: mode, energy: 50, need: need))
            }
        }
        try write("haku-3-needs", rows)
    }

    @Test func hakuMoments() throws {
        let moments: [(CompanionMoment, Mode)] = [
            (.slacking, .work), (.drowsy, .work), (.overtime, .work), (.gymInvite, .work), (.heading, .work),
            (.timeToLeave, .work), (.stiff, .work), (.packingUp, .work), (.vibeCoding, .money), (.flow, .money),
            (.lateCoding, .money), (.shooting, .money), (.collapsed, .chill), (.blanket, .chill), (.morning, .chill),
        ]
        // One sheet per moment, with a line on stderr before each, so a moment that hangs the renderer
        // shows up by name in the log and the others still get drawn.
        for (moment, mode) in moments {
            FileHandle.standardError.write(Data("drawing moment \(moment)\n".utf8))
            let row = Row(label: "\(mode.rawValue) · moment \(moment)", start: Self.base) {
                AnyView(CompanionView(mode: mode, energy: 50, moment: moment))
            }
            try write("haku-4-moment-\(moment)", [row])
        }
    }

    @Test func hakuActivitiesAndBedtime() throws {
        let activities: [(CompanionActivity, Mode)] = [
            (.boxingAtGym, .boxing), (.gymSession, .chill), (.running, .chill), (.gymDay, .chill), (.runDay, .chill),
        ]
        var rows = activities.map { activity, mode in
            Row(label: "\(mode.rawValue) · activity \(activity)", start: Self.base) {
                AnyView(CompanionView(mode: mode, energy: 50, activity: activity))
            }
        }
        for mode in Mode.allCases {
            rows.append(
                Row(label: "\(mode.rawValue) · bedtime", start: Self.base) {
                    AnyView(CompanionView(mode: mode, energy: 50, bedtime: .on))
                })
        }
        try write("haku-5-activities-bedtime", rows)
    }

    @Test func hakuWatch() throws {
        var rows: [Row] = []
        for mode in Mode.allCases {
            for (name, energy) in Self.energies {
                rows.append(
                    Row(label: "watch · \(mode.rawValue) · \(name)", start: Self.base) {
                        AnyView(CompanionView(mode: mode, energy: energy, style: .watch))
                    })
            }
        }
        rows.append(
            Row(label: "watch · no mode", start: Self.base) {
                AnyView(CompanionView(mode: nil, style: .watch))
            })
        try write("haku-6-watch", rows, size: CGSize(width: 198, height: 242))
    }

    // Mike 2026-10-15: the bigger room bag, and card backdrops without items, on the phone and the watch.
    @Test func hakuBackdrops() throws {
        let bag = Wardrobe(equipped: [.room: "room.bag"])
        var rows = [
            Row(label: "chill · 房间小沙袋", start: Self.base) {
                AnyView(CompanionView(mode: .chill, energy: 50, wardrobe: bag))
            },
            Row(label: "boxing · 拳馆", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, energy: 50, activity: .boxingAtGym))
            },
        ]
        let cards: [IdentityKind] = [.fitness, .dance, .music]
        rows += cards.map { card in
            Row(label: "card \(card)", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, card: card, energy: 50))
            }
        }
        try write("haku-8-backdrops", rows)
        let watch = cards.map { card in
            Row(label: "watch · card \(card)", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, card: card, energy: 50, style: .watch))
            }
        }
        try write("haku-8-backdrops-watch", watch, size: CGSize(width: 198, height: 242))
    }

    // HAKU-03 (UI 审核 2026-10-13): the last 0.5 s of the welcome back and 0.3 s of idle after it, 0.05 s apart.
    @Test func hakuWelcomeEnd() throws {
        let cases: [(WelcomeScene, Mode)] = [
            (.sofa, .chill), (.quiet, .chill), (.glance, .chill), (.desk, .work), (.quiet, .work),
        ]
        let rows = cases.map { scene, mode in
            Row(label: "welcome end · \(scene) · \(mode.rawValue)", start: Self.base) {
                AnyView(WelcomeEndFrame(scene: scene, mode: mode, start: Self.base))
            }
        }
        try write("haku-7-welcome-end", rows, frames: 16, step: 0.05)
    }

    @Test func kuroLooks() throws {
        var rows: [Row] = []
        for look in KuroLook.allCases {
            for (name, energy) in Self.energies {
                rows.append(
                    Row(label: "kuro \(look) · \(name)", start: Self.base) {
                        AnyView(KuroView(look: look, energy: energy))
                    })
            }
            rows.append(
                Row(label: "kuro \(look) · bedtime", start: Self.base) {
                    AnyView(KuroView(look: look, energy: 50, bedtime: .on))
                })
        }
        rows.append(
            Row(label: "kuro work · overtime", start: Self.base) {
                let until = Self.base.addingTimeInterval(9 * 3600)
                return AnyView(KuroView(look: .work, energy: 50, moment: .overtime, overtimeUntil: until))
            })
        try write("kuro-1-looks", rows)
    }

    @Test func kuroWatch() throws {
        var rows: [Row] = []
        for look in KuroLook.allCases {
            for (name, energy) in Self.energies {
                rows.append(
                    Row(label: "watch · kuro \(look) · \(name)", start: Self.base) {
                        AnyView(KuroView(look: look, energy: energy, style: .watch))
                    })
            }
        }
        try write("kuro-2-watch", rows, size: CGSize(width: 198, height: 242))
    }

    // QA §1b: everything owned and every trace on at once, one still per state, with the placement test's
    // conflicts in red under each cell. One page per mode and room item for HAKU, per look for KURO.
    @Test func allItemsOn() throws {
        let traces = Set(CompanionTrace.allCases)
        let outfits = PlacementPoses.outfits.filter { $0.1.room != nil && $0.1.mask == .stripes && $0.1.peaceSign }
        for mode in Mode.allCases {
            for (outfitLabel, outfit) in outfits {
                let cells = PlacementPoses.hakuStates(face: .mid).map { label, pose in
                    let worn = pose.wearing(outfit).leaving(traces)
                    let parts = RunnerFigure.parts(for: mode, pose: worn)
                    return Cell(
                        label: label,
                        conflicts: Placement.conflicts(
                            in: parts, spots: Placement.haku, forbidden: Placement.hakuForbidden),
                        figure: AnyView(RunnerFigure(mode: mode, pose: worn))
                    )
                }
                try writeStills("items-haku-\(mode.rawValue)-\(outfitLabel)", cells)
            }
        }
        for look in KuroLook.allCases {
            let cells = PlacementPoses.kuro
                .filter { $0.look == look && $0.pose.items.count == KuroItem.allCases.count }
                .filter { $0.label.hasPrefix("\(look.rawValue) 50 ") }
                .map { state in
                    Cell(
                        label: String(state.label.dropFirst("\(look.rawValue) 50 ".count).dropLast(" items".count)),
                        conflicts: Placement.conflicts(
                            in: KuroFigure.parts(for: look, pose: state.pose), spots: Placement.kuro,
                            forbidden: Placement.kuroForbidden),
                        figure: AnyView(KuroFigure(look: look, pose: state.pose))
                    )
                }
            try writeStills("items-kuro-\(look.rawValue)", cells)
        }
    }

    @Test func lockScreenHeads() throws {
        let poses: [(String, CompanionPortrait)] = [
            ("lockscreen-half-awake", CompanionPortrait(mode: .chill, energy: 20, moment: .morning, framing: .head)),
            ("lockscreen-off-work", CompanionPortrait(mode: .work, energy: 50, moment: .packingUp, framing: .head)),
            (
                "lockscreen-asleep",
                CompanionPortrait(mode: .chill, energy: 50, moment: .blanket, bedtime: .on, framing: .head)
            ),
        ]
        for (name, portrait) in poses {
            try save(portrait.frame(width: 160, height: 160), as: name, scale: 3)
        }
    }

    // UI-03: the tinted Lock Screen keeps only alpha. StatusWidget turns the head into a line drawing with
    // colorInvert + luminanceToAlpha; this draws that result as the system would, in white (vibrant) and blue
    // (accented), on a dark and a light wallpaper.
    // ImageRenderer ignores luminanceToAlpha inside a mask, so the tinted look is computed per pixel here:
    // the same colorInvert + luminanceToAlpha the widget applies, then the tint over a wallpaper.
    @Test func lockScreenTinted() throws {
        let tints: [(String, (Double, Double, Double, Double), Double)] = [
            ("vibrant 深", (1, 1, 1, 0.9), 0.15), ("vibrant 浅", (1, 1, 1, 0.9), 0.7),
            ("accented", (0.35, 0.6, 1, 1), 0.1),
        ]
        var images: [(String, [CGImage])] = []
        for persona in Persona.allCases {
            for (name, tint, wallpaper) in tints {
                let row = try Mode.allCases.map { mode in
                    let renderer = ImageRenderer(content: Self.head(persona, mode).frame(width: 68, height: 68))
                    renderer.scale = 3
                    let head = try #require(renderer.cgImage)
                    return try #require(Self.tinted(head, tint: tint, wallpaper: wallpaper))
                }
                images.append(("\(persona.rawValue) · \(name)", row))
            }
        }
        let sheet = VStack(alignment: .leading, spacing: 10) {
            Text("lockscreen-tinted · 锁屏着色（StatusWidget head，逐像素算 colorInvert + luminanceToAlpha）")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            ForEach(images.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    Text(images[index].0)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(width: 190, alignment: .leading)
                    ForEach(images[index].1.indices, id: \.self) { column in
                        Image(decorative: images[index].1[column], scale: 3)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "lockscreen-tinted", scale: 3)
    }

    /// `head` as a tinted Lock Screen shows it: alpha from the inverted luminance, filled with `tint`
    /// (r, g, b, opacity) over a gray `wallpaper` with a faint circle behind, as `AccessoryWidgetBackground`.
    static func tinted(_ head: CGImage, tint: (Double, Double, Double, Double), wallpaper: Double) -> CGImage? {
        let (width, height) = (head.width, head.height)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: info
            )
        else { return nil }
        context.draw(head, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let center = (Double(width) / 2, Double(height) / 2)
        for index in stride(from: 0, to: width * height * 4, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            // Premultiplied channels: inverting keeps alpha, so the inverted color is alpha - channel.
            let red = alpha - Double(pixels[index]) / 255
            let green = alpha - Double(pixels[index + 1]) / 255
            let blue = alpha - Double(pixels[index + 2]) / 255
            let mask = min(max(0.2126 * red + 0.7152 * green + 0.0722 * blue, 0), 1) * tint.3
            let pixel = index / 4
            let dx = Double(pixel % width) - center.0
            let dy = Double(pixel / width) - center.1
            let ring = (dx * dx + dy * dy).squareRoot() < Double(width) / 2 ? 0.18 : 0
            let back = wallpaper + (1 - wallpaper) * ring
            let channels = [tint.0, tint.1, tint.2]
            for channel in 0..<3 {
                pixels[index + channel] = UInt8(((channels[channel] * mask + back * (1 - mask)) * 255).rounded())
            }
            pixels[index + 3] = 255
        }
        return context.makeImage()
    }

    @ViewBuilder static func head(_ persona: Persona, _ mode: Mode) -> some View {
        if persona == .kuro {
            KuroPortrait(look: KuroLook(mode: mode), energy: 50, framing: .head)
        } else {
            CompanionPortrait(mode: mode, energy: 50, framing: .head)
        }
    }

    /// The first time from `base` whose idle slot shows `life` in chill.
    static func start(for life: IdleLife?) -> Date {
        var date = base
        for _ in 0..<500 where IdleLife.at(date) != life {
            date += IdleLife.slotLength
        }
        return date
    }

    /// HAKU at the end of the welcome back scene: frame 0 is 0.5 s before it ends; after it ends, the idle pose.
    struct WelcomeEndFrame: View {
        let scene: WelcomeScene
        let mode: Mode
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            let length = scene.length(cards: 2, cans: 3)
            let t = CGFloat((clock ?? start).timeIntervalSince(start)) + length - 0.5
            let open = scene.open(cards: 2, cans: 3)
            let pose =
                t < length
                ? RunnerPose.welcome(scene, time: t, open: open, face: .mid, mode: mode, length: length)
                : RunnerPose(face: .mid)
            RunnerFigure(mode: mode, pose: pose)
                .padding(12)
                .background(mode.color)
        }
    }

    /// Renders `rows` into `<name>.png`: one row per case, `frames` frames `step` apart.
    func write(
        _ name: String, _ rows: [Row], size: CGSize = CGSize(width: 180, height: 240), frames: Int = Self.frames,
        step: TimeInterval = Self.step
    ) throws {
        let commit = ProcessInfo.processInfo.environment["FRAME_SHA"].map { String($0.prefix(7)) } ?? "local"
        let sheet = VStack(alignment: .leading, spacing: 10) {
            let frame = "\(Int(size.width))×\(Int(size.height)) pt"
            Text("\(name) · \(commit) · \(frame) · 每格 \(step, specifier: "%.1f") s")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            HStack(spacing: 6) {
                Text("").frame(width: 190)
                ForEach(0..<frames, id: \.self) { index in
                    Text(String(format: "%.1f s", Double(index) * step))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: size.width)
                }
            }
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack(spacing: 6) {
                    Text(row.label)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(width: 190, alignment: .leading)
                    ForEach(0..<frames, id: \.self) { frame in
                        row.draw()
                            .environment(\.frameClock, row.start + Double(frame) * step)
                            .environment(\.scenePhase, .active)
                            .frame(width: size.width, height: size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: name, scale: 2)
    }

    /// One still on a stills page: what it shows, the placement conflicts in it, and the drawing.
    struct Cell {
        let label: String
        let conflicts: [String]
        let figure: AnyView
    }

    /// Renders `cells` as stills into `<name>.png`, `columns` to a row.
    func writeStills(_ name: String, _ cells: [Cell], columns: Int = 8) throws {
        let commit = ProcessInfo.processInfo.environment["FRAME_SHA"].map { String($0.prefix(7)) } ?? "local"
        let found = cells.filter { !$0.conflicts.isEmpty }.count
        let sheet = VStack(alignment: .leading, spacing: 10) {
            Text("\(name) · \(commit) · 物品和痕迹全开 · 红字 = 同一位置两件（\(found) / \(cells.count) 格）")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            ForEach(Array(stride(from: 0, to: cells.count, by: columns)), id: \.self) { start in
                HStack(alignment: .top, spacing: 6) {
                    ForEach(start..<min(start + columns, cells.count), id: \.self) { index in
                        let cell = cells[index]
                        VStack(spacing: 2) {
                            Text(cell.label)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .lineLimit(2)
                            cell.figure
                                .frame(width: 120, height: 160)
                            Text(cell.conflicts.sorted().joined(separator: "\n"))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.red)
                        }
                        .frame(width: 130, alignment: .top)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: name, scale: 2)
    }

    // Issue #352 PR B, for UI 审核: each card in both shapes, plus the longest Japanese keepsake name to check the
    // 85% shrink and the line breaks.
    @Test func shareCards() throws {
        let fonts = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Apps/iOS/Fonts")
        #expect(AppFonts.register(in: fonts).isEmpty)
        let look = Look(mode: .boxing, wardrobe: Wardrobe(), card: .boxing)
        let gloves = try #require(ShopItem.item("gloves.gold"))
        let keepsake = try #require(ShareCard(persona: .haku, look: look, item: gloves))
        let hoodie = try #require(ShopItem.item("kuro.top.chill.hoodie"))
        let chill = Look(mode: .chill, wardrobe: Wardrobe(), card: nil)
        let outfit = try #require(ShareCard(persona: .kuro, look: chill, item: hoodie))
        // The longest Japanese keepsake name with the writers' phrase breaks; the count line is made up until
        // the writers translate it.
        let runner = try #require(ShopItem.item("keepsake.headband.runner"))
        let runnerCard = try #require(ShareCard(persona: .haku, look: look, item: runner))
        let japanese = ShareCard.Words(
            name: "HAKU", title: "ランナーのヘッドバンド", subtitle: "5 km ラン 4 回目", line: "……やる。ついでだ。")
        let ja = Locale.Language(identifier: "ja")
        let cards: [(String, ShareCard, ShareCard.Words, Locale.Language)] = [
            ("zh-keepsake", keepsake, keepsake.words(counting: "拳击"), Locale.Language(identifier: "zh-Hans")),
            ("ja-keepsake-longest", runnerCard, japanese, ja),
            ("zh-outfit", outfit, outfit.words(counting: "网球"), Locale.Language(identifier: "zh-Hans")),
        ]
        for (name, card, words, language) in cards {
            for shape in ShareCard.Shape.allCases {
                let view = ShareCardView(card: card, words: words, shape: shape, language: language)
                try save(view, as: "share-\(name)-\(shape.rawValue)", scale: 3)
            }
        }
    }

    /// Writes `view` to `<name>.png` in the sheets folder.
    func save(_ view: some View, as name: String, scale: CGFloat) throws {
        let folder = try #require(ProcessInfo.processInfo.environment["FRAME_SHEETS"])
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        let image = try #require(renderer.cgImage)
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        print("frame sheet \(name): \(image.width)×\(image.height)")
        let type = UTType.png.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
#endif
