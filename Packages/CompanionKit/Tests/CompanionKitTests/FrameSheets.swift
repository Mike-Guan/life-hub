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
        try write("haku-6-watch", rows, size: CGSize(width: 198, height: 242))
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

    // Preview for KURO-03 / KURO-04 one-offs: each event plays her look's tap move once, from 0.4 s.
    @Test func kuroOneOffs() throws {
        let kinds: [(String, Bool)] = [("offWork", false)] + KuroOneOff.Kind.allCases.map {
            ("\($0)", KuroOneOff(kind: $0, id: "x").heart)
        }
        var rows: [Row] = []
        for look in KuroLook.allCases {
            for (name, heart) in kinds {
                rows.append(Row(label: "kuro \(look) · \(name)", start: Self.base) {
                    AnyView(OneOffFrame(look: look, heart: heart, start: Self.base.addingTimeInterval(0.4)))
                })
            }
        }
        try write("kuro-6-oneoffs", rows, frames: 8, step: 0.2)
    }

    // Preview for UI-01: the shop and wardrobe tile behind each slot, for each character.
    @Test func shopTiles() throws {
        let sheet = VStack(alignment: .leading, spacing: 12) {
            ForEach(Persona.allCases, id: \.self) { persona in
                HStack(spacing: 12) {
                    Text(persona.rawValue)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .frame(width: 80, alignment: .leading)
                    ForEach(Slot.allCases, id: \.self) { slot in
                        VStack(spacing: 6) {
                            Color.clear
                                .frame(width: 96, height: 64)
                                .toyCard(fill: slot.tileColor(for: persona), radius: 12, shadow: 0)
                            Text(slot.rawValue).font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "shop-tiles", scale: 2)
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

/// KURO in `look` playing her one-off move from `start`: her look's tap move with its hop.
struct OneOffFrame: View {
    let look: KuroLook
    let heart: Bool
    let start: Date
    @Environment(\.frameClock) private var frameClock

    var body: some View {
        let tap = KuroTap(look: look, sleepy: false)
        let progress = ((frameClock ?? start).timeIntervalSince(start)) / tap.duration
        let playing = (0..<1).contains(progress) ? (tap, progress) : nil
        let base = KuroPose(look: look, energy: 50)
        ZStack {
            Rectangle().fill(look.color)
            KuroFigure(look: look, pose: playing.map { base.reacting($0.0, progress: $0.1, heart: heart) } ?? base)
                .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
                .offset(y: KuroView.hop(playing))
                .padding(.top, 24)
                .padding(.horizontal, 12)
        }
    }
}
#endif
