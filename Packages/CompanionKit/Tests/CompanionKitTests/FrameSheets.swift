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

    // HAKU's identity card tops, each with a card that wears it: the idle from the front, then a still from behind.
    @Test func hakuCardTops() throws {
        var rows: [Row] = []
        for (id, card, _) in CompanionKitTests.cardTops {
            let wardrobe = Wardrobe(clothes: [.boxing: id])
            rows.append(
                Row(label: "\(id) · \(card)", start: Self.base) {
                    AnyView(CompanionView(mode: .boxing, card: card, energy: 50, wardrobe: wardrobe))
                })
            rows.append(
                Row(label: "\(id) · 背面", start: Self.base) {
                    var pose = RunnerPose(face: .mid).wearing(Outfit(wardrobe)).dressed(for: card, in: .boxing)
                    pose.turnedAway = true
                    return AnyView(
                        RunnerFigure(mode: .boxing, pose: pose)
                            .padding(12)
                            .background(Mode.boxing.color))
                })
        }
        try write("haku-9-card-tops", rows)
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

    // HAKU-19 (UI 审核 2026-10-08): hands and props come up into view and go down again, 0.1 s apart.
    @Test func hakuHandsIn() throws {
        let work = IdleClockTests.firstStart(kind: 1, lengths: RunnerPose.workBeats) ?? 0
        let chill = IdleClockTests.firstStart(kind: 1, lengths: RunnerPose.chillBeats) ?? 0
        // The cue rows start where no idle beat plays, so only the cue's own hands move.
        let quiet =
            (0..<6000).lazy.map { Double($0) * 0.01 }.first { t in
                stride(from: t, through: t + 3, by: 0.1).allSatisfy {
                    IdleClock.beat(
                        at: $0, every: 14, spread: 3, lengths: RunnerPose.chillBeats, seed: RunnerPose.seed) == nil
                }
            } ?? 0
        let soon = DailyCue(stage: .soon, prop: .note, id: "frames")
        let now = DailyCue(stage: .now, prop: .note, id: "frames")
        let rows: [(String, Mode, (TimeInterval) -> RunnerPose)] = [
            ("phone glance", .work, { RunnerPose(mode: .work, time: work + $0, face: .mid, react: 0) }),
            ("scratch in", .chill, { RunnerPose(mode: .chill, time: chill + $0, face: .mid, react: 0) }),
            ("scratch out", .chill, { RunnerPose(mode: .chill, time: chill + 0.8 + $0, face: .mid, react: 0) }),
            (
                "watch tap in", .chill,
                { t in
                    var pose = RunnerPose(mode: .chill, time: quiet + t, face: .mid, react: 0)
                    pose.cue(soon, time: t, slap: nil)
                    return pose
                }
            ),
            (
                "watch tap out", .chill,
                { t in
                    var pose = RunnerPose(mode: .chill, time: quiet + t, face: .mid, react: 0)
                    pose.cue(soon, time: 1.8 + t, slap: nil)
                    return pose
                }
            ),
            (
                "can out, note up", .chill,
                { t in
                    var pose = RunnerPose(mode: .chill, time: quiet + t, face: .mid, react: 0)
                    pose.cue(now, time: 5, slap: nil, entered: CGFloat(min(1, t / 0.8)))
                    return pose
                }
            ),
        ]
        let sheet = rows.map { label, mode, pose in
            Row(label: label, start: Self.base) {
                AnyView(PoseFrame(mode: mode, start: Self.base, pose: pose))
            }
        }
        // UI 审核 HAKU-27: the scene effects breathe instead of blinking.
        let effects: [(String, DailyScene)] = [
            ("coffee breath", .coffee), ("shop shine", .shopping), ("wave arcs", .friends), ("haircut buzz", .haircut),
            ("ouch lines", .doctor),
        ]
        let effectRows = effects.map { label, scene in
            Row(label: label, start: Self.base) {
                AnyView(
                    PoseFrame(mode: .chill, start: Self.base) { t in
                        var pose = RunnerPose(mode: .chill, time: quiet + t, face: .mid, react: 0)
                        pose.cue(
                            DailyCue(stage: .now, prop: .note, scene: scene, id: "frames"), time: 0.5 + t, slap: nil)
                        return pose
                    })
            }
        }
        try write("haku-9-hands-in", sheet + effectRows, frames: 13, step: 0.1)
    }

    // 第2批 身份卡 for UI 审核: each look's own idle from its start, then the look in the app and on the watch.
    @Test func hakuCardsBatch2() throws {
        let cards: [IdentityKind] = [.swimming, .yoga, .ball, .outdoor]
        var rows = cards.map { card in
            Row(label: "card \(card) · 待机", start: Self.base) {
                AnyView(CardBeatFrame(card: card, start: Self.base))
            }
        }
        rows += cards.map { card in
            Row(label: "card \(card)", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, card: card, energy: 50))
            }
        }
        try write("haku-9-cards-batch2", rows)
        let watch = cards.map { card in
            Row(label: "watch · card \(card)", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, card: card, energy: 50, style: .watch))
            }
        }
        try write("haku-9-cards-batch2-watch", watch, size: CGSize(width: 198, height: 242))
    }

    // HAKU-23 (UI 审核 2026-10-08): the sports celebration crouches before each hop and lands pressed down.
    @Test func hakuCelebration() throws {
        let kinds: [(WorkoutSummary.Kind, Mode)] = [(.boxing, .boxing), (.running, .chill), (.strength, .chill)]
        let rows = kinds.map { kind, mode in
            Row(label: "celebrate · \(kind)", start: Self.base) {
                AnyView(CelebrationFrame(kind: kind, mode: mode, start: Self.base))
            }
        }
        try write("haku-8-celebration", rows, frames: 13, step: CompanionView.celebrationDuration / 12)
    }

    // The same sparkles on a mode switch, 0.5 s.
    @Test func hakuSwapSparkles() throws {
        let rows = [Mode.work, .chill].map { mode in
            Row(label: "swap · \(mode.rawValue)", start: Self.base) {
                AnyView(SwapFrame(mode: mode, start: Self.base))
            }
        }
        try write("haku-8-swap-sparkles", rows, frames: 6, step: 0.1)
    }

    // Frames run 40765011148: with every look on one page the sheet was too big to write, so each page holds five.
    /// Her looks, five to a page.
    static var kuroPages: [ArraySlice<KuroLook>] {
        let looks = KuroLook.allCases
        return stride(from: 0, to: looks.count, by: 5).map { looks[$0..<min($0 + 5, looks.count)] }
    }

    @Test func kuroLooks() throws {
        for (page, looks) in Self.kuroPages.enumerated() {
            var rows: [Row] = []
            for look in looks {
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
            if page == 0 {
                rows.append(
                    Row(label: "kuro work · overtime", start: Self.base) {
                        let until = Self.base.addingTimeInterval(9 * 3600)
                        return AnyView(KuroView(look: .work, energy: 50, moment: .overtime, overtimeUntil: until))
                    })
            }
            try write("kuro-1-looks-\(page + 1)", rows)
        }
    }

    @Test func kuroWatch() throws {
        for (page, looks) in Self.kuroPages.enumerated() {
            var rows: [Row] = []
            for look in looks {
                for (name, energy) in Self.energies {
                    rows.append(
                        Row(label: "watch · kuro \(look) · \(name)", start: Self.base) {
                            AnyView(KuroView(look: look, energy: energy, style: .watch))
                        })
                }
            }
            try write("kuro-2-watch-\(page + 1)", rows, size: CGSize(width: 198, height: 242))
        }
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

    /// HAKU in the pose `pose` gives for the seconds since `start`.
    struct PoseFrame: View {
        let mode: Mode
        let start: Date
        let pose: (TimeInterval) -> RunnerPose
        @Environment(\.frameClock) private var clock

        var body: some View {
            RunnerFigure(mode: mode, pose: pose((clock ?? start).timeIntervalSince(start)))
                .padding(12)
                .background(mode.color)
        }
    }

    /// HAKU in a card look, playing the look's own idle from `start`.
    struct CardBeatFrame: View {
        let card: IdentityKind
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            RunnerFigure(mode: .boxing, pose: pose)
                .padding(12)
                .background(Mode.boxing.color)
        }

        private var pose: RunnerPose {
            var pose = RunnerPose(face: .mid).dressed(for: card, in: .boxing)
            if let look = RunnerCardLook(card: card) {
                pose.play(look, nil, at: CGFloat((clock ?? start).timeIntervalSince(start)))
            }
            return pose
        }
    }

    /// HAKU celebrating `kind`, moved and squashed the way `CompanionView` does it.
    struct CelebrationFrame: View {
        let kind: WorkoutSummary.Kind
        let mode: Mode
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            let t = (clock ?? start).timeIntervalSince(start) / CompanionView.celebrationDuration
            let p = min(t, 0.999)
            let motion = IdleMotion.celebrating(progress: p)
            var pose = RunnerPose(face: .mid)
            pose.celebrate(kind, progress: CGFloat(p))
            return RunnerFigure(mode: mode, pose: pose)
                .rotationEffect(.degrees(motion.angle), anchor: .bottom)
                .offset(y: motion.dy)
                .scaleEffect(x: 1 + 0.08 * motion.squash, y: 1 - 0.12 * motion.squash, anchor: .bottom)
                .padding(12)
                .background(mode.color)
        }
    }

    /// HAKU in `mode` with the mode-switch sparkles, 0.5 s long.
    struct SwapFrame: View {
        let mode: Mode
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            var pose = RunnerPose(mode: mode, time: 0, face: .mid, react: 0)
            pose.burst = CGFloat(min((clock ?? start).timeIntervalSince(start) / 0.5, 0.999))
            pose.swapping = true
            return RunnerFigure(mode: mode, pose: pose)
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
