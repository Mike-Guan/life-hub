import HubCore
import SwiftUI

// 动画精修计划 v1 第 5 批 (KURO-26): her face stays calm and what she thinks shows in a thought bubble over her
// head (搭档角色 人设与动作 v0 §40-41). The rain cloud is never played for an ignored invite: rain then would read as
// blaming the user.
/// A thought she has without saying it, shown once in a bubble.
enum KuroThought: String, Sendable {
    /// A little rain cloud: a low-energy day.
    case rain
    /// A tangle of lines that smooths out and goes: scrolling for a long while.
    case tangle

    /// How long the bubble shows, in seconds; shorter and still with reduced motion.
    func duration(reduceMotion: Bool) -> TimeInterval {
        switch self {
        case .rain: reduceMotion ? 2 : 4
        case .tangle: reduceMotion ? 1.5 : 3.8
        }
    }

    /// The thought for `energy` and `need`, if any: the tangle while scrolling, else the rain on a low day.
    static func pick(energy: Double?, need: CompanionNeed?) -> KuroThought? {
        if need == .couchScroll { return .tangle }
        return EnergyFace(energy: energy) == .low ? .rain : nil
    }

    /// The day to play `thought` on at `date`, as `yyyy-MM-dd`, or nil when it already played that day (`last`).
    static func newDay(at date: Date, last: String, calendar: Calendar = .current) -> String? {
        let day = DailyAgenda.key(for: date, calendar: calendar)
        return day == last ? nil : day
    }
}

/// Her thought bubble `time` seconds into `thought`: dots, then a cloud with a rain cloud or a tangle inside.
struct KuroThoughtBubble: View {
    let thought: KuroThought
    var time: TimeInterval
    var reduceMotion = false

    var body: some View {
        Canvas { context, size in
            // Drawn in a 72 x 54 box, scaled to fit, like the star bubble.
            let scale = min(size.width / 72, size.height / 54)
            context.scaleBy(x: scale, y: scale)
            let length = thought.duration(reduceMotion: reduceMotion)
            // With reduced motion the timeline stands still, so the bubble shows whole until it is taken away.
            context.opacity = reduceMotion ? 1 : Self.fade(time, length: length)
            let ink = GraphicsContext.Shading.color(Toy.ink)
            let white = GraphicsContext.Shading.color(.white)
            // The small dot sits up and right of the box corner, clear of her right ear tip.
            let dots = [CGRect(x: 5, y: 43, width: 6, height: 6), CGRect(x: 10, y: 33, width: 10, height: 10)]
            for dot in dots.map({ Path(ellipseIn: $0) }) {
                context.fill(dot, with: white)
                context.stroke(dot, with: ink, lineWidth: 2.5)
            }
            // The cloud pops open after the dots, from 0.6 to full size.
            let open = reduceMotion ? 1 : min(max((time - 0.1) / 0.2, 0), 1)
            guard open > 0 else { return }
            var cloud = context
            let grow = 0.6 + 0.4 * open
            cloud.translateBy(x: 44, y: 20)
            cloud.scaleBy(x: grow, y: grow)
            cloud.translateBy(x: -44, y: -20)
            let shape = Path(ellipseIn: CGRect(x: 18, y: 2, width: 52, height: 36))
            cloud.fill(shape, with: white)
            cloud.stroke(shape, with: ink, lineWidth: 3)
            switch thought {
            case .rain: Self.rain(in: cloud, time: reduceMotion ? 0 : time)
            case .tangle: Self.tangle(in: cloud, time: time, reduceMotion: reduceMotion)
            }
        }
        .aspectRatio(72 / 54, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// The bubble's opacity: in over 0.15 s, out over the last 0.4 s of `length`.
    nonisolated static func fade(_ time: TimeInterval, length: TimeInterval) -> Double {
        min(max(time / 0.15, 0), 1, max((length - time) / 0.4, 0))
    }

    // A grey cloud that bobs 1.5 every 1.6 s, three drops falling 0.8 s each, a third of a fall apart.
    private static func rain(in context: GraphicsContext, time: TimeInterval) {
        let bob = 1.5 * sin(time * 2 * .pi / 1.6)
        // Sky alone was too pale on a light blue screen, so the drops take a third of navy.
        let drops = KuroPalette.sky.mix(with: KuroPalette.navy, by: 0.35)
        for (index, x) in [37.0, 44, 51].enumerated() {
            let fall = (time / 0.8 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
            let y = 23 + fall * 9
            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y))
            drop.addLine(to: CGPoint(x: x - 1.2, y: y + 3.5))
            var faded = context
            faded.opacity *= 1 - fall * 0.6
            faded.stroke(drop, with: .color(drops), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        var cloud = Path()
        cloud.move(to: CGPoint(x: 31, y: 21 + bob))
        cloud.addQuadCurve(to: CGPoint(x: 36, y: 13 + bob), control: CGPoint(x: 30, y: 14 + bob))
        cloud.addQuadCurve(to: CGPoint(x: 46, y: 10 + bob), control: CGPoint(x: 39, y: 7 + bob))
        cloud.addQuadCurve(to: CGPoint(x: 56, y: 15 + bob), control: CGPoint(x: 55, y: 9 + bob))
        cloud.addQuadCurve(to: CGPoint(x: 55, y: 22 + bob), control: CGPoint(x: 60, y: 19 + bob))
        cloud.closeSubpath()
        context.fill(cloud, with: .color(KuroPalette.tablet))
        context.stroke(cloud, with: .color(Toy.ink), lineWidth: 2)
    }

    // The tangle winds in over 0.8 s, sways ±4° every 2 s, then from 2.7 s smooths into one wave and fades.
    private static func tangle(in context: GraphicsContext, time: TimeInterval, reduceMotion: Bool) {
        let style = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        let smooth = reduceMotion ? 1 : min(max((time - 2.7) / 0.6, 0), 1)
        if smooth < 1 {
            var knot = Path()
            knot.move(to: CGPoint(x: 28, y: 22))
            knot.addCurve(to: CGPoint(x: 42, y: 18), control1: CGPoint(x: 30, y: 8), control2: CGPoint(x: 43, y: 8))
            knot.addCurve(to: CGPoint(x: 37, y: 18), control1: CGPoint(x: 41, y: 28), control2: CGPoint(x: 34, y: 26))
            knot.addCurve(to: CGPoint(x: 51, y: 19), control1: CGPoint(x: 40, y: 8), control2: CGPoint(x: 52, y: 9))
            knot.addCurve(to: CGPoint(x: 47, y: 18), control1: CGPoint(x: 50, y: 28), control2: CGPoint(x: 44, y: 26))
            knot.addCurve(to: CGPoint(x: 60, y: 20), control1: CGPoint(x: 50, y: 10), control2: CGPoint(x: 59, y: 12))
            let sway = 4 * sin(time * 2 * .pi / 2) * .pi / 180
            var turned = context
            turned.opacity *= 1 - smooth
            turned.translateBy(x: 44, y: 18)
            turned.rotate(by: .radians(sway))
            turned.translateBy(x: -44, y: -18)
            turned.stroke(knot.trimmedPath(from: 0, to: min(time / 0.8, 1)), with: .color(Toy.ink), style: style)
        }
        guard smooth > 0 else { return }
        var wave = Path()
        wave.move(to: CGPoint(x: 28, y: 20))
        wave.addQuadCurve(to: CGPoint(x: 44, y: 20), control: CGPoint(x: 36, y: 20 - 5 * (1 - smooth)))
        wave.addQuadCurve(to: CGPoint(x: 60, y: 20), control: CGPoint(x: 52, y: 20 + 5 * (1 - smooth)))
        var faded = context
        faded.opacity *= reduceMotion ? 1 : smooth * (1 - min(max((time - 3.3) / 0.4, 0), 1))
        faded.stroke(wave, with: .color(Toy.ink), style: style)
    }
}
