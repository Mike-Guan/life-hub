import HubCore
import SwiftUI

/// One filled and/or stroked shape of a `RunnerPart` or `KuroPart`, in SVG units.
struct RunnerInk: Sendable {
    var path: Path
    var fill: Color?
    var stroke: Color?
    var lineWidth: CGFloat
    var cap: CGLineCap
    var join: CGLineJoin
    var dash: [CGFloat]
    var opacity: Double
    /// Opacity of the fill alone.
    var fillOpacity: Double
    /// Fills the shape instead of `fill`.
    var gradient: RunnerGradient?
    /// Only the inside of this path is painted.
    var clip: Path?

    init(
        path: Path,
        fill: Color? = nil,
        stroke: Color? = nil,
        lineWidth: CGFloat = 1,
        cap: CGLineCap = .butt,
        join: CGLineJoin = .miter,
        dash: [CGFloat] = [],
        opacity: Double = 1,
        fillOpacity: Double = 1,
        gradient: RunnerGradient? = nil,
        clip: Path? = nil
    ) {
        self.path = path
        self.fill = fill
        self.stroke = stroke
        self.lineWidth = lineWidth
        self.cap = cap
        self.join = join
        self.dash = dash
        self.opacity = opacity
        self.fillOpacity = fillOpacity
        self.gradient = gradient
        self.clip = clip
    }
}

/// A linear gradient fill, with end points in SVG units.
struct RunnerGradient: Sendable {
    var colors: [Color]
    var locations: [CGFloat]
    var start: CGPoint
    var end: CGPoint

    /// The gradient as a SwiftUI shading.
    var shading: GraphicsContext.Shading {
        let stops = zip(colors, locations).map { Gradient.Stop(color: $0, location: $1) }
        return .linearGradient(Gradient(stops: stops), startPoint: start, endPoint: end)
    }
}

extension RunnerArt {
    /// The inks of `part`, built once instead of on every frame.
    static func cachedInks(_ part: RunnerPart) -> [RunnerInk] {
        inkCache[part] ?? []
    }

    private static let inkCache: [RunnerPart: [RunnerInk]] = Dictionary(
        uniqueKeysWithValues: RunnerPart.allCases.map { ($0, inks($0)) }
    )
}

/// Text inside a part, such as the ¥¥ on the mask LED. `y` is the baseline.
struct RunnerText: Sendable {
    var string: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
}

/// RUNNER's face for an energy value: low, mid or high.
enum EnergyFace: Sendable {
    /// Heavier eyelids, eye bags, slower moves, sweat on boxing day.
    case low
    case mid
    /// Bright eyes, sparkles by the head, quicker moves.
    case high

    static let lowBelow = 30.0
    static let highFrom = 70.0

    /// The face for `energy` (0-100). Unknown energy is `.mid`.
    init(energy: Double?) {
        guard let energy else {
            self = .mid
            return
        }
        if energy < Self.lowBelow {
            self = .low
        } else if energy >= Self.highFrom {
            self = .high
        } else {
            self = .mid
        }
    }

    /// How fast idle loops run compared with `.mid`.
    var speed: Double {
        switch self {
        case .low: 0.6
        case .mid: 1
        case .high: 1.25
        }
    }
}

/// Where each part of RUNNER sits and how it is posed right now. All lengths are SVG units.
struct RunnerPose {
    /// Head nod, applied to every head part around the neck.
    var headDy: CGFloat = 0
    /// 1 = eyes open, near 0 = closed.
    var blink: CGFloat = 1
    /// Eyes looking up (work tap: eye roll).
    var eyesDy: CGFloat = 0
    /// Eyes looking sideways; negative is toward the door on the left.
    var eyesDx: CGFloat = 0
    var ledOpacity: Double = 1
    /// Work tap: the LED shows dots instead of the line.
    var ledDots = false
    var yenDx: CGFloat = 0
    var canAngle: Double = 0
    var canOffset: CGSize = .zero
    var gloveL: CGSize = .zero
    var gloveR: CGSize = .zero
    var gloveRScale: CGFloat = 1
    /// Position of the shine sweeping over the gold chain, as a fraction of the figure width.
    var glint: CGFloat = -1
    var coinTurn: Double = 0
    var face = EnergyFace.mid
    /// What RUNNER acts out on top of the mode's outfit.
    var need: CompanionNeed?
    /// Brightness of the sparkles by the head on high energy, 0...1.
    var sparkle: Double = 1
    /// Progress of the celebration sparkle burst, 0..<1, or -1 when none is playing.
    var burst: CGFloat = -1
    /// The workout being celebrated, which picks the move: gloves up, a peace sign or a lift.
    var cheerKind: WorkoutSummary.Kind?
    /// Scroll position of the feed on the phone screen while couch scrolling, 0...1.
    var feed: CGFloat = 0
    /// Bedtime overlay: sleepy eyes, mask down, the mode's outfit stays.
    var bedtime = false
    /// 0 = headset on, 1 = taken off.
    var headsetOff: CGFloat = 0
    /// 0 = mouth closed, 1 = widest yawn.
    var yawn: CGFloat = 0
    /// 0 = normal height, 1 = stretched up.
    var stretch: CGFloat = 0
    /// 0 = head upright, 1 = resting on the pillow.
    var lie: CGFloat = 0
    /// Rise of the floating Z z z, 0...1, or -1 when hidden.
    var zzz: CGFloat = -1
    /// Rise of the sleep-talk "…" while napping, 0...1, or -1 when hidden.
    var sleepTalk: CGFloat = -1
    /// The gym bag: -1 = not shown, 0 = on the floor by the door, 1 = over the shoulder.
    var bagLift: CGFloat = -1
    /// Progress of the off-work animation, 0...1, or -1 when none is playing.
    var offWork: CGFloat = -1
    /// Progress of giving up on leaving for work, 0...1, or -1 when none is playing.
    var stayHome: CGFloat = -1
    /// Seconds into getting up from the sofa, or -1 when HAKU isn't getting up.
    var revive: CGFloat = -1
    /// What HAKU wears from the wardrobe.
    var outfit = Outfit()

    /// The same pose in `outfit`.
    func wearing(_ outfit: Outfit) -> RunnerPose {
        var pose = self
        pose.outfit = outfit
        return pose
    }

    /// The same pose with today's `traces`.
    func leaving(_ traces: Set<CompanionTrace>) -> RunnerPose {
        var pose = self
        pose.traces = traces
        return pose
    }
    /// 0 = mask up, 1 = pulled down to the chin.
    var maskDrop: CGFloat = 0
    var canOpacity: Double = 1
    /// What HAKU does on its own at home, or nil.
    var life: IdleLife?
    /// Offset of the prop HAKU is holding in its own time (console, snack, cloth).
    var prop: CGSize = .zero
    /// Offset of the pencil while drawing.
    var pencil: CGSize = .zero
    /// 0 = prop in view, 1 = hidden because someone looked.
    var propHidden: CGFloat = 0
    /// What HAKU does alongside Mike, which replaces the need and its own time.
    var activity: CompanionActivity?
    /// Swing of the heavy bag in degrees after a hit.
    var bagSwing: Double = 0
    /// Height of the dumbbell while lifting: 0 = down, 1 = curled up.
    var lift: CGFloat = 0
    /// Speed lines drifting back while running, 0...1.
    var dash: CGFloat = 0
    /// Progress of the unboxing, 0...1, or -1 when none is playing.
    var unbox: CGFloat = -1
    /// The state within the mode HAKU acts out; it replaces the need and its own time.
    var moment: CompanionMoment?
    /// Monster cans piled up while vibe coding; up to 3 are drawn.
    var codingCans = 0
    /// Offset of the hands on the keyboard while typing.
    var typing: CGSize = .zero
    /// 0 = laptop on the desk, 1 = held up to peek over.
    var peek: CGFloat = 0
    /// 0 = upright, 1 = head down on the desk.
    var slump: CGFloat = 0
    /// Rise of the soul leaving while slumped, 0...1, or -1 when hidden.
    var soulRise: CGFloat = -1
    /// Brightness of the floating code brackets in flow, 0...1.
    var codeGlow: Double = 1
    /// Staring at an empty can: deadpan eyes instead of the smile.
    var emptyCan = false
    /// A quick look at the phone at work, held low in front.
    var phoneGlance = false
    /// Turned away from you: only the back of the head and the room show.
    var turnedAway = false
    /// Horizontal squeeze while turning around, 1 = full width.
    var turnSqueeze: CGFloat = 1
    /// Progress of rubbing an eye with the fist, 0...1, or -1 when not rubbing.
    var rubEye: CGFloat = -1
    /// Rise of a hummed music note, 0...1, or -1 when hidden.
    var hum: CGFloat = -1
    /// Progress of scratching the head, 0...1, or -1 when not scratching.
    var scratch: CGFloat = -1
    /// Height of the tuft of hair left sticking up after a scratch, 0 = settled, 1 = upright.
    var tuft: CGFloat = 0
    /// Rise of the note whistled after hiding a snack or sketchbook, 0...1, or -1 when not whistling.
    var whistle: CGFloat = -1
    /// Fist on the right shoulder while stiff: 0 = resting, 1 = thumped down, or -1 when hidden.
    var thump: CGFloat = -1
    /// Impact lines by the fist as it lands.
    var thumpHit = false
    /// Head tilt in degrees around the neck; negative leans left.
    var headTilt: Double = 0
    /// Eyes shut in comfort, replacing the open eyes.
    var eyesShut = false
    /// 0 = arms down, 1 = raised over the head with the hands clasped.
    var armsUp: CGFloat = 0
    /// Sideways shift of the whole figure, for rolling the shoulders.
    var shift: CGFloat = 0
    /// Packing up before the end of work: 0 = closing the laptop, 1 = wiping the desk, 2 = headset off and
    /// bag on, 3 = watching the clock.
    var packStep = 3
    /// 0 = laptop open, 1 = closed.
    var lidClose: CGFloat = 0
    /// What HAKU holds up for a planned Daily Widget task, or nil.
    var dailyProp: DailyProp?
    /// What HAKU acts out instead of holding up the prop, or nil.
    var dailyScene: DailyScene?
    /// Seconds into the scene's loop.
    var sceneTime: CGFloat = 0
    /// Forward lean of the whole figure in degrees, around the feet.
    var lean: Double = 0
    /// Vertical hop of the whole figure, in SVG units; negative is up.
    var bounce: CGFloat = 0
    /// The place HAKU is walking away from, or nil when it isn't walking.
    var walkFrom: HubPlace.Kind?
    /// Seconds into the walk.
    var walkTime: CGFloat = 0
    /// Seconds into the bath call loop, or -1 when HAKU isn't calling Mike to the bath.
    var bathCall: CGFloat = -1
    /// Seconds into drying the hair after the bath, or -1.
    var bathDry: CGFloat = -1
    /// Opacity of the whole figure, 0...1.
    var presence = 1.0
    /// 0 = the planned task's prop down (bag on the floor, note out of view), 1 = held up.
    var propRaise: CGFloat = 0
    /// Tapping the watch before a planned task.
    var watchTap = false
    /// Progress of the sticky note slapped on the screen as a planned task starts, 0..<1, or -1 when none.
    var noteSlap: CGFloat = -1
    /// Height of the fist pumped for the day's focus done: 0 = low, 1 = high, or -1 when hidden.
    var fistPump: CGFloat = -1
    /// Flare of the mask LED, 0...1.
    var ledFlare: CGFloat = 0
    /// The watch poke HAKU reacts to, or nil.
    var pokeKind: WatchPoke?
    /// Progress of the watch poke, 0...1, or -1 when none is playing.
    var pokeProgress: CGFloat = -1
    /// How far the right headset cup is pushed up, 0...1.
    var cupRUp: CGFloat = 0
    /// Size of the can, 1 = as drawn; larger when held out to the screen.
    var canScale: CGFloat = 1
    /// What today left in HAKU's world: a bandage, the monitor on, sunlight.
    var traces: Set<CompanionTrace> = []

    var tired: Bool { face == .low }
    var offWorking: Bool { offWork >= 0 }
    var stayingHome: Bool { stayHome >= 0 }
    var reviving: Bool { revive >= 0 }
    /// Whether the mask slides between the face and the chin: going off work, staying home or getting up.
    var unmasking: Bool { offWorking || stayingHome || reviving }
    /// How high the dumbbell is: the celebration reps while one plays, else the lift.
    var dumbbellRise: CGFloat { burst >= 0 ? abs(sin(burst * 2 * .pi)) : lift }
    /// HAKU's height while unboxing: 0 = inside the box, then a pop past full height that settles at 1.
    var popOut: CGFloat {
        guard unbox >= 0 else { return 1 }
        let x = Self.ramp(unbox, from: 0.3, to: 0.5)
        guard x < 1 else { return 1 }
        return x < 0.6 ? x / 0.6 * 1.15 : 1.15 - 0.15 * (x - 0.6) / 0.4
    }

    /// The still pose, used for reduced motion and static renders.
    init(
        face: EnergyFace = .mid,
        need: CompanionNeed? = nil,
        life: IdleLife? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil
    ) {
        self.face = face
        self.activity = activity
        self.moment = activity == nil ? moment : nil
        self.need = activity == nil && moment == nil ? need : nil
        self.life = self.need == nil && self.moment == nil && activity == nil ? life : nil
        if tired { blink = 0.75 }
        switch self.moment {
        case .slacking:
            peek = 1
            eyesDx = -3
        case .drowsy:
            yawn = 0.7
            blink = 0.5
        case .overtime:
            slump = 1
            soulRise = 0.4
        case .gymInvite:
            bagLift = 1
            eyesDx = -3
            lift = 0.3
        case .heading:
            bagLift = 1
            headDy = 1
        case .vibeCoding, .flow, .lateCoding:
            // Eyes down on the screen.
            headDy = 2
            eyesDy = 1.5
            if self.moment == .flow { canOpacity = 0 }
        case .collapsed:
            slump = Self.collapse
            blink = 0.15
        case .blanket:
            blink = 0.4
            headDy = 2
        case .morning:
            blink = 0.6
        case .timeToLeave:
            eyesDx = -3
        case .packingUp:
            // The Lock Screen frame: laptop shut, bag on, eyes on the watch.
            lidClose = 1
            headsetOff = 1
            bagLift = 1
            eyesDx = 3
            eyesDy = 1.5
        case .stiff:
            // The Lock Screen frame: fist landing on the shoulder, head tilted, eyes squeezed.
            thump = 1
            thumpHit = true
            headTilt = -6
            blink = 0.4
        case .shooting, nil:
            break
        }
        switch activity {
        case .gymDay: bagLift = 1
        case .gymSession: lift = 0.6
        case .running:
            headDy = 1
            dash = 0.4
        case .boxingAtGym:
            gloveL = CGSize(width: -8, height: -6)
            bagSwing = 4
        case .runDay, nil: break
        }
        if self.need == .boxingWarmup { eyesDx = -2 }
        if self.need == .couchScroll {
            // Slumped, eyes down on the phone.
            headDy = 3
            eyesDy = 1.5
        }
        switch self.life {
        case .nap:
            blink = 0.15
            lie = 0.6
            zzz = 0.35
        case .handheld, .drawing:
            // Eyes down on the screen or the page.
            headDy = 2
            eyesDy = 1.5
        default:
            break
        }
    }

    /// Pose at `time` for `mode`. `react` runs 0 → 1 → 0 after a tap.
    init(
        mode: Mode,
        time: TimeInterval,
        face: EnergyFace,
        need: CompanionNeed? = nil,
        life: IdleLife? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        react: Double
    ) {
        self.init(face: face, need: need, life: life, activity: activity, moment: moment)
        let t = time * face.speed
        let open: CGFloat = tired ? 0.75 : 1
        let r = CGFloat(react)
        blink = open * Self.blink(at: t)
        // Sparkles twinkle out of step with the blink, 1.6 s period.
        sparkle = 0.55 + 0.45 * sin(time * 2 * .pi / 1.6)

        // Shooting keeps the ¥¥ look of the old money mode, motion included.
        switch self.moment == .shooting ? .money : mode {
        case .work:
            // Nod to the music every 0.5 s; LED breathes over 2.4 s; tap = eye roll + "•••".
            headDy = CGFloat(abs(sin(t * .pi / 0.5))) * 1.5
            let breath = 0.5 + 0.5 * sin(t * 2 * .pi / 2.4)
            ledOpacity = (0.6 + 0.4 * breath) * (tired ? 0.5 : 1)
            eyesDy = -2 * r
            ledDots = react > 0.05
            // Every third 12 s cycle: two bigger nods, a still beat, then a push of the headset.
            let cycle = (t / 12).rounded(.down)
            let phase = t - cycle * 12
            let plain = self.need == nil && self.life == nil && self.moment == nil && activity == nil
            if plain, r == 0, cycle.truncatingRemainder(dividingBy: 3) == 2, phase >= 8, phase < 11 {
                headDy = phase < 9 ? CGFloat(abs(sin(phase * .pi / 0.5))) * 2.5 : 0
                headsetOff = 0.1 * Self.bump(CGFloat(phase), from: 10, to: 11)
            }
            // Every third cycle, offset from the headset push: a quick look at the phone, then it's away.
            if plain, r == 0, cycle > 0, cycle.truncatingRemainder(dividingBy: 3) == 0, phase >= 4.3, phase < 5.5 {
                phoneGlance = true
                eyesDy = 2
                headDy = 1
            }
        case .chill:
            // A sip every 8 s; tap = raise the can.
            let phase = t.truncatingRemainder(dividingBy: 8)
            let sip = CGFloat(phase > 6.8 ? sin((phase - 6.8) / 1.2 * .pi) : 0)
            canAngle = Double(-28 * sip - 22 * r + (tired ? 14 : 0))
            canOffset = CGSize(width: -6 * sip, height: -6 * sip - 10 * r + (tired ? 4 : 0))
            // After every fourth sip the can is empty: a shake by the ear, then a deadpan stare at it.
            let cycle = (t / 8).rounded(.down)
            let plain = self.need == nil && self.life == nil && self.moment == nil && activity == nil
            if plain, cycle > 0, cycle.truncatingRemainder(dividingBy: 4) == 0, phase < Self.emptyCanLength {
                let shake = max(0, 1 - phase / 1.2)
                canAngle = Double(-8 + 10 * sin(phase * 2 * .pi / 0.3) * shake)
                canOffset = CGSize(width: -6, height: -10)
                emptyCan = phase >= 1.2
                eyesDx = emptyCan ? 3 : 0
            }
            // Every 18 s: a scratch of the head, then a tuft of hair that settles slowly.
            let itch = t.truncatingRemainder(dividingBy: 18)
            if plain, r == 0, !emptyCan, itch >= 5, itch < 12 {
                if itch < 7 { scratch = CGFloat((itch - 5) / 2) }
                tuft = Self.ramp(CGFloat(itch), from: 5.5, to: 7) * (1 - Self.ramp(CGFloat(itch), from: 7, to: 12))
            }
        case .boxing:
            // Guard bounce every 0.6 s, gloves alternate; tap = right jab.
            let bounce = CGFloat(sin(t * 2 * .pi / 0.6)) * 3
            gloveL = CGSize(width: 0, height: bounce)
            gloveR = CGSize(width: -14 * r, height: -bounce - 10 * r)
            gloveRScale = 1 + 0.2 * r
            // Every third 10 s cycle: shake the wrists out, then a glove up to fix the headband.
            let cycle = (t / 10).rounded(.down)
            let phase = t - cycle * 10
            let plain = self.need == nil && self.life == nil && self.moment == nil && activity == nil
            if plain, r == 0, cycle.truncatingRemainder(dividingBy: 3) == 1, phase >= 6, phase < 9.5 {
                if phase < 7.5 {
                    let shake = CGFloat(sin(phase * 2 * .pi / 0.15)) * 3
                    gloveL = CGSize(width: shake, height: 8)
                    gloveR = CGSize(width: -shake, height: 8)
                } else {
                    let fix = Self.bump(CGFloat(phase), from: 7.5, to: 9.5)
                    gloveL = .zero
                    gloveR = CGSize(width: 10 * fix, height: -70 * fix)
                    eyesDx = 3 * fix
                }
            }
        case .money:
            // ¥¥ drifts on the LED, a shine runs along the chain every 3 s; tap = coin flip.
            yenDx = CGFloat(sin(t * 2 * .pi / 4)) * 2
            let sweep = t.truncatingRemainder(dividingBy: 3) / 3
            glint = sweep < 0.6 ? 0.28 + CGFloat(sweep / 0.6) * 0.5 : -1
            coinTurn = 360 * react
        }
        if self.need == .boxingWarmup { warmUp(time: t, react: r) }
        if self.need == .couchScroll { scroll(time: t) }
        if let life = self.life { live(life, time: t, react: r) }
        if let moment = self.moment { play(moment, time: t) }
        if let activity { act(activity, time: t) }
        // Choreographed eyes (needs, moments, its own time, activities) keep their own look.
        if self.need == nil, self.moment == nil, self.life == nil, activity == nil { eyesDx += Self.drift(at: t) }
    }

    /// Now and then the eyes drift off to one side and come back: every 13 s, left and right in turn.
    static func drift(at t: TimeInterval) -> CGFloat {
        let cycle = (t / 13).rounded(.down)
        let side: CGFloat = cycle.truncatingRemainder(dividingBy: 2) == 0 ? 1 : -1
        return 3 * side * bump(CGFloat(t - cycle * 13), from: 9, to: 10.4)
    }

    /// The state within the mode: peeking, dozing, slumped, at the door, walking, or vibe coding.
    private mutating func play(_ moment: CompanionMoment, time t: TimeInterval) {
        switch moment {
        case .slacking:
            // Laptop up to the eyes, ducking down every 3 s; the eyes dart left and right.
            peek = 1 - 0.3 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 3)), from: 2.2, to: 3)
            eyesDx = CGFloat(sin(t * 2 * .pi / 2.4)) * 3
            eyesDy = 0
        case .drowsy:
            // A yawn every 6 s, then a sip of the Monster.
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 6))
            yawn = Self.bump(phase, from: 0, to: 1.4)
            let sip = Self.bump(phase, from: 3.6, to: 4.8)
            canAngle = Double(-28 * sip)
            canOffset = CGSize(width: -6 * sip, height: -6 * sip)
            blink = max(0.15, (1 - 0.7 * yawn) * 0.55 * Self.blink(at: t))
            headDy = 1.5 * yawn
        case .overtime:
            // Head on the desk, slow breaths, the soul drifting up every 4 s.
            slump = 1
            blink = 0.15
            headDy = CGFloat(sin(t * 2 * .pi / 4))
            soulRise = CGFloat(t.truncatingRemainder(dividingBy: 4) / 4)
        case .gymInvite:
            // Bag on, a lazy curl of the hand weight, looking at the door and back every 4 s.
            bagLift = 1
            lift = CGFloat(abs(sin(t * .pi / 2.4)))
            headDy = CGFloat(abs(sin(t * .pi / 0.5))) * 1.5
            eyesDx = -4 + 4 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 4)), from: 2.8, to: 4)
        case .heading:
            // Walking: the head bobs with each step.
            bagLift = 1
            headDy = CGFloat(abs(sin(t * 2 * .pi / 0.9))) * 2
        case .vibeCoding, .flow, .lateCoding:
            // Fast typing, slower when it's late; in flow a can is handed over every 10 s.
            let period = moment == .lateCoding ? 0.6 : moment == .flow ? 0.2 : 0.28
            typing = CGSize(width: 0, height: -1.5 * CGFloat(abs(sin(t * .pi / period))))
            headDy = 2
            eyesDy = 1.5
            ledOpacity = 1
            if moment == .lateCoding { blink = max(0.15, 0.5 * Self.blink(at: t * 0.5)) }
            if moment == .vibeCoding {
                // Every 14 s: stop typing, a stretch with the hands up, then back to the keys.
                let rest = Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 14)), from: 11, to: 13.5)
                if rest > 0 {
                    stretch = 0.6 * rest
                    typing = CGSize(width: 0, height: -4 * rest)
                    headDy = 2 - 3 * rest
                    eyesDy = 1.5 - 2.5 * rest
                }
            }
            guard moment == .flow else { return }
            codeGlow = 0.5 + 0.5 * sin(t * 2 * .pi / 2)
            let hand = Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 10)), from: 8, to: 10)
            canOpacity = hand > 0 ? 1 : 0
            canOffset = CGSize(width: -14 * hand, height: 24 * (1 - hand) - 6)
            canAngle = Double(-12 * hand)
        case .shooting:
            break
        case .collapsed:
            // Head down on the sofa arm, slow breaths.
            slump = Self.collapse
            blink = 0.15
            headDy = CGFloat(sin(t * 2 * .pi / 4))
        case .blanket:
            // Wrapped up, eyes half shut, sinking a little.
            blink = max(0.15, 0.4 * Self.blink(at: t * 0.5))
            headDy = 2 + CGFloat(sin(t * 2 * .pi / 5))
        case .morning:
            // Brushing, half asleep.
            prop = CGSize(width: CGFloat(sin(t * 2 * .pi / 0.35)) * 3, height: 0)
            blink = max(0.3, 0.6 * Self.blink(at: t))
        case .timeToLeave:
            // Tapping the watch, a look at the door every 4 s.
            prop = CGSize(width: 0, height: 3 * CGFloat(abs(sin(t * .pi / 0.4))))
            eyesDx = -3 + 3 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 4)), from: 3, to: 4)
        case .stiff:
            stiffen(time: t)
        case .packingUp:
            // Packed and waiting: tapping the watch, a look at the door every 4 s.
            headDy = 0
            let k = CGFloat(t.truncatingRemainder(dividingBy: 4))
            prop = CGSize(width: 0, height: 3 * abs(sin(k * .pi / 0.4)))
            eyesDx = 3 - 6 * Self.bump(k, from: 3, to: 4)
            eyesDy = 1.5 * (1 - Self.bump(k, from: 3, to: 4))
        }
    }

    /// How long closing the laptop, wiping the desk and putting the bag on take, in seconds.
    static let packUpLength: TimeInterval = 6.6

    /// Packing up `elapsed` seconds after it started: closing the laptop, wiping the desk, headset off and bag
    /// on. From `packUpLength` on, the moment's own loop of watching the clock plays.
    mutating func packUp(elapsed: TimeInterval) {
        let t = CGFloat(elapsed)
        if t < 2.2 {
            packStep = 0
            lidClose = Self.ramp(t, from: 0.9, to: 2)
            headsetOff = 0
            bagLift = -1
            // Last few keys, then the hands lift off the keyboard.
            let lift = t < 0.7 ? -1.5 * abs(sin(t * .pi / 0.28)) : -6 * Self.ramp(t, from: 0.7, to: 1.2)
            typing = CGSize(width: 0, height: lift)
            eyesDx = 0
            eyesDy = 1.5
            headDy = 2
        } else if t < 4.6 {
            packStep = 1
            headsetOff = 0
            bagLift = -1
            let sweep = sin((t - 2.2) / 1.2 * 2 * .pi)
            prop = CGSize(width: -26 + 22 * sweep, height: 6)
            eyesDx = -2 + 2.5 * sweep
            eyesDy = 2
            headDy = 2
        } else if t < CGFloat(Self.packUpLength) {
            packStep = 2
            let k = t - 4.6
            headsetOff = Self.ramp(k, from: 0, to: 0.7)
            bagLift = Self.ramp(k, from: 0.8, to: 1.7)
            eyesDx = -3 * Self.bump(k, from: 0.8, to: 1.9)
            eyesDy = -Self.bump(k, from: 0, to: 0.7)
            headDy = 0
        }
    }

    /// How long the sticky note stays on the screen as a planned task starts, in seconds.
    static let noteSlapLength: TimeInterval = 3

    /// Size of the slapped sticky note `t` seconds in: it flies in past full size and settles at 1.
    static func noteSize(at t: CGFloat) -> CGFloat {
        if t < 0.25 { return 0.3 + 0.8 * ramp(t, from: 0, to: 0.25) }
        return 1.1 - 0.1 * ramp(t, from: 0.25, to: 0.4)
    }

    /// The planned task's prop at `time`. Soon: a 10 s loop of tapping the watch, then the prop held up. Now: the
    /// prop held up, with the sticky note slapped on the screen at `slap` (0..<1), or nil when it isn't.
    mutating func cue(_ cue: DailyCue, time t: TimeInterval, slap: Double?) {
        dailyProp = cue.prop
        dailyScene = cue.scene
        sceneTime = CGFloat(t)
        noteSlap = slap.map { CGFloat($0) } ?? -1
        propRaise = 1
        if cue.stage == .soon {
            let c = CGFloat(t.truncatingRemainder(dividingBy: 10))
            watchTap = c < 2.4
            if watchTap {
                prop = CGSize(width: 0, height: 3 * abs(sin(c * .pi / 0.4)))
                eyesDx = 3
                eyesDy = 1.5
            }
            propRaise = Self.ramp(c, from: 2.4, to: 2.9) * (1 - Self.ramp(c, from: 9.4, to: 10))
        }
        if let scene = cue.scene {
            playScene(scene, time: CGFloat(t))
        } else if cue.prop == .gymBag {
            bagLift = max(bagLift, propRaise)
        }
    }

    /// Cheering the day's focus done at `progress` (0..<1): the mask LED flares, then three fist pumps with the
    /// eyes shut and a burst of sparkles.
    mutating func cheerFocus(progress: Double) {
        let t = CGFloat(min(max(progress, 0), 1)) * 3
        let pumping = t > 1 && t < 2.8
        ledFlare = max(Self.bump(t, from: 0, to: 1), pumping ? 0.5 : 0)
        eyesShut = pumping
        fistPump = pumping ? abs(sin((t - 1) * .pi / 0.6)) : -1
        burst = t > 1 && t < 2.4 ? (t - 1) / 1.4 : -1
    }

    /// Sitting too long, a 4 s loop: two twists of the waist, then three thumps on the right shoulder.
    private mutating func stiffen(time t: TimeInterval) {
        headDy = 0
        thump = -1
        thumpHit = false
        let c = t.truncatingRemainder(dividingBy: 4)
        guard c >= 1.6 else {
            // The twist itself is the figure's sway; the head leans against it.
            headTilt = -3 * sin(c / 1.6 * 2 * .pi)
            blink = min(blink, 0.55)
            return
        }
        let k = CGFloat(c - 1.6)
        let beat = k.truncatingRemainder(dividingBy: 0.6) / 0.6
        let thumping = k < 1.8
        if k < 2.2 { thump = thumping ? abs(sin(beat * .pi)) : 0 }
        thumpHit = thumping && beat > 0.35 && beat < 0.7
        headTilt = Double(-6 * Self.ramp(k, from: 0, to: 0.2) * (1 - Self.ramp(k, from: 2.1, to: 2.4)))
        blink = min(blink, 0.4)
    }

    /// Sway of the whole figure while stiff at `t`: the waist twist, then a dip with each thump.
    static func stiffSway(at t: TimeInterval) -> (angle: Double, dy: CGFloat) {
        let c = t.truncatingRemainder(dividingBy: 4)
        guard c >= 1.6 else { return (4 * sin(c / 1.6 * 2 * .pi), 0) }
        let k = CGFloat(c - 1.6)
        let down = k < 1.8 ? abs(sin(k.truncatingRemainder(dividingBy: 0.6) / 0.6 * .pi)) : 0
        return (0, 1.5 * down)
    }

    /// Standing up from a long sit at `progress` (0...1): up, the arms swing over the head with the eyes shut,
    /// the arms come down, then a straight look.
    mutating func stretchUp(progress: Double) {
        let t = CGFloat(min(max(progress, 0), 1)) * 6
        thump = -1
        thumpHit = false
        headTilt = 0
        stretch = Self.smooth(Self.ramp(t, from: 0, to: 0.7)) * (1 - Self.smooth(Self.ramp(t, from: 5.4, to: 6)))
        armsUp = Self.ramp(t, from: 0.7, to: 1.6) * (1 - Self.ramp(t, from: 2.8, to: 3.4))
        headDy = -2 * Self.bump(t, from: 0.9, to: 2.9)
        eyesShut = t > 1 && t < 3
        if t >= 3 {
            blink = 1
            eyesDx = 0
            eyesDy = 0
        }
    }

    /// Rolling the shoulders at `progress` (0...1) after Mike stood up: two rolls with the eyes shut, then a
    /// pleased squint.
    static func limber(time: TimeInterval, progress: Double, face: EnergyFace) -> RunnerPose {
        var pose = RunnerPose(face: face)
        let t = CGFloat(min(max(progress, 0), 1)) * 4.6
        let angle = t / 1.2 * 2 * .pi
        let r = t < 2.4 ? 2.4 * ramp(t, from: 0, to: 0.3) * (1 - ramp(t, from: 2.1, to: 2.4)) : 0
        pose.shift = r * cos(angle)
        pose.stretch = 0.5 * r / 2.4 * abs(sin(angle))
        pose.headDy = -0.8 * r * abs(sin(angle - 0.5))
        pose.eyesShut = t > 0.2 && t < 2.6
        if !pose.eyesShut { pose.blink = min(0.7, blink(at: time)) }
        return pose
    }

    /// How long the empty-can shake and stare lasts, in seconds of the chill cycle.
    static let emptyCanLength: TimeInterval = 3.2

    /// How far the head drops onto the sofa arm when collapsed, as a fraction of the desk slump.
    private static let collapse: CGFloat = 0.85

    /// Doing it alongside Mike: heavy-bag combos, curls, running, or getting ready for the gym or the run.
    private mutating func act(_ activity: CompanionActivity, time t: TimeInterval) {
        switch activity {
        case .boxingAtGym:
            // Jab, jab, cross every 1.6 s into the bag on the left; the bag swings after each hit.
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 1.6))
            let jab = Self.bump(phase, from: 0, to: 0.25) + Self.bump(phase, from: 0.35, to: 0.6)
            let cross = Self.bump(phase, from: 0.8, to: 1.1)
            gloveL = CGSize(width: -14 * jab, height: -10 * jab)
            gloveR = CGSize(width: -40 * cross, height: -12 * cross)
            gloveRScale = 1 + 0.15 * cross
            bagSwing = Double(5 * Self.bump(phase, from: 0.15, to: 0.75) + 9 * Self.bump(phase, from: 1, to: 1.6))
            eyesDx = -2
        case .gymSession:
            // A slow curl every 2 s, the head pushing along at the top.
            lift = CGFloat(abs(sin(t * .pi / 2)))
            headDy = lift
        case .running:
            // Quick strides: the head bobs and the speed lines stream back.
            headDy = CGFloat(abs(sin(t * 2 * .pi / 0.72))) * 2.5
            dash = CGFloat(t.truncatingRemainder(dividingBy: 0.5) / 0.5)
        case .gymDay:
            // Bag over the shoulder, a look at the door every 5 s.
            bagLift = 1
            eyesDx = -4 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 5)), from: 3.4, to: 5)
        case .runDay:
            // Bouncing the running shoe, a calf stretch every 4 s.
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 4))
            prop = CGSize(width: 0, height: -4 * CGFloat(abs(sin(t * 2 * .pi / 1))))
            stretch = 0.4 * Self.bump(phase, from: 2.6, to: 4)
        }
    }

    /// HAKU's own time. A tap catches it: it wakes, hides the snack, closes the sketchbook or
    /// drops the gloves.
    private mutating func live(_ life: IdleLife, time t: TimeInterval, react r: CGFloat) {
        switch life {
        case .nap:
            // Breathing in the sofa corner, Z z z every 3 s; a tap half wakes it.
            blink = 0.15 + 0.85 * r
            lie = 0.6 * (1 - r)
            headDy = 1.5 + CGFloat(sin(t * 2 * .pi / 4))
            zzz = r > 0.05 ? -1 : CGFloat(t.truncatingRemainder(dividingBy: 3) / 3)
            // Every fourth Z z z is a mumbled "…" instead.
            if zzz >= 0, (t / 3).rounded(.down).truncatingRemainder(dividingBy: 4) == 3 {
                sleepTalk = zzz
                zzz = -1
            }
        case .handheld:
            // Button mashing: the console jitters, eyes glued to it.
            headDy = 2
            eyesDy = 1.5
            prop = CGSize(
                width: CGFloat(sin(t * 2 * .pi / 0.3)) * 0.8,
                height: CGFloat(sin(t * 2 * .pi / 0.45)) * 0.6
            )
        case .snack:
            // A bite every 3 s; a tap whips the snack away and the eyes slide off.
            let bite = Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 3)), from: 0, to: 0.7)
            prop = CGSize(width: -12 * bite, height: -8 * bite)
            propHidden = r
            eyesDx = -3 * r
        case .drawing:
            headDy = 2
            eyesDy = 1.5
            pencil = CGSize(width: CGFloat(sin(t * 7)) * 2, height: CGFloat(cos(t * 5)) * 1.5)
            propHidden = r
        case .practice:
            // Left and right jabs every 1.2 s; a tap drops the gloves and looks away.
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 1.2))
            let left = Self.bump(phase, from: 0, to: 0.35)
            let right = Self.bump(phase, from: 0.6, to: 0.95)
            gloveL = CGSize(width: 10 * left, height: -12 * left + 30 * r)
            gloveR = CGSize(width: -10 * right, height: -12 * right + 30 * r)
            gloveRScale = 1 + 0.2 * right
            eyesDx = -3 * r
        case .tidying:
            // Wiping in small circles, 1.2 s a round, head following along.
            let a = t * 2 * .pi / 1.2
            prop = CGSize(width: CGFloat(cos(a)) * 8, height: CGFloat(sin(a)) * 5)
            headDy = CGFloat(sin(a)) * 1
        }
    }

    /// Couch scrolling with the gym bag in view, glancing at it every 5 s.
    mutating func peekAtBag(time t: TimeInterval) {
        bagLift = 0
        eyesDx = -4 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 5)), from: 3.4, to: 5)
    }

    /// Slumped over the phone: a thumb flick every 2.5 s, slow blinks.
    private mutating func scroll(time t: TimeInterval) {
        headDy = 3
        eyesDy = 1.5
        blink = 0.85 * Self.blink(at: t * 0.6)
        feed = Self.ramp(CGFloat(t.truncatingRemainder(dividingBy: 2.5)), from: 0, to: 0.4)
    }

    /// Gloves up and bouncing whatever the mode; a look at the door every 4 s.
    private mutating func warmUp(time t: TimeInterval, react r: CGFloat) {
        let bounce = CGFloat(sin(t * 2 * .pi / 0.6)) * 3
        gloveL = CGSize(width: 0, height: bounce)
        gloveR = CGSize(width: -14 * r, height: -bounce - 10 * r)
        gloveRScale = 1 + 0.2 * r
        eyesDx = -3 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 4)), from: 2.6, to: 4)
    }

    /// Bedtime pose at `time`.
    /// - Parameters:
    ///   - goodnight: progress of the good-night animation, 0...1.
    ///   - liesDown: whether the head comes to rest on the pillow at the end.
    static func bedtime(time: TimeInterval, goodnight: Double, liesDown: Bool) -> RunnerPose {
        var pose = RunnerPose()
        pose.bedtime = true
        let g = CGFloat(min(max(goodnight, 0), 1))
        // Take the headset off, stretch while yawning, then lean onto the pillow.
        pose.headsetOff = ramp(g, from: 0, to: 0.25)
        pose.stretch = bump(g, from: 0.25, to: 0.55)
        // After that, a yawn every 6 s and Z z z rising every 3 s.
        let phase = time.truncatingRemainder(dividingBy: 6)
        let loopYawn = g >= 1 && phase < 1.2 ? CGFloat(sin(phase / 1.2 * .pi)) : 0
        pose.yawn = max(bump(g, from: 0.3, to: 0.65), loopYawn)
        pose.lie = liesDown ? ramp(g, from: 0.65, to: 0.9) : 0
        pose.zzz = g >= 0.9 ? CGFloat(time.truncatingRemainder(dividingBy: 3) / 3) : -1
        // Slow, heavy blinks; eyes squeeze shut in a yawn.
        pose.blink = max(0.15, (1 - 0.7 * pose.yawn) * blink(at: time * 0.5))
        pose.headDy = 1.5 * (1 - pose.lie) + 1.5 * pose.yawn
        return pose
    }

    /// Plays the celebration for `kind` at `progress` (0..<1) on top of the current pose.
    mutating func celebrate(_ kind: WorkoutSummary.Kind?, progress: CGFloat) {
        burst = progress
        cheerKind = kind
        guard kind == .boxing else { return }
        // Acts cool, then the right glove pumps up twice anyway.
        let pump = abs(sin(progress * 2 * .pi))
        gloveL = CGSize(width: 0, height: -6 * pump)
        gloveR = CGSize(width: -6 * pump, height: -24 * pump)
        gloveRScale = 1
    }

    /// Plays the unboxing at `progress` (0...1) on top of the current pose: the box shakes and opens,
    /// HAKU pops out with sparkles and holds its gloves up over the box.
    mutating func unbox(progress: CGFloat) {
        unbox = progress
        burst = progress >= 0.32 && progress < 0.82 ? (progress - 0.32) / 0.5 : -1
        let up = Self.ramp(progress, from: 0.45, to: 0.6)
        gloveL = CGSize(width: 0, height: -26 * up)
        gloveR = CGSize(width: -4 * up, height: -30 * up)
        gloveRScale = 1
    }

    /// Off-work pose at `progress` (0...1): headset off, mask down, a big stretch, then open a Monster.
    static func offWork(time: TimeInterval, progress: Double, face: EnergyFace) -> RunnerPose {
        var pose = RunnerPose(face: face)
        let p = CGFloat(min(max(progress, 0), 1))
        pose.offWork = p
        pose.headsetOff = ramp(p, from: 0, to: 0.15)
        pose.maskDrop = ramp(p, from: 0.15, to: 0.3)
        pose.stretch = bump(p, from: 0.3, to: 0.6)
        pose.yawn = bump(p, from: 0.35, to: 0.55)
        // The can comes up from below, then one long sip.
        let canIn = ramp(p, from: 0.6, to: 0.75)
        let sip = bump(p, from: 0.8, to: 1)
        pose.canOpacity = Double(canIn)
        pose.canOffset = CGSize(width: -6 * sip, height: 30 * (1 - canIn) - 6 * sip)
        pose.canAngle = Double(-28 * sip)
        pose.blink = max(0.15, (1 - 0.7 * pose.yawn) * blink(at: time))
        pose.headDy = 1.5 * pose.yawn
        return pose
    }

    /// Staying-home pose at `progress` (0...1): a last look at the door, headset and mask off, then back on the
    /// sofa with a sigh.
    static func stayHome(time: TimeInterval, progress: Double, face: EnergyFace) -> RunnerPose {
        var pose = RunnerPose(face: face)
        let p = CGFloat(min(max(progress, 0), 1))
        pose.stayHome = p
        pose.eyesDx = -3 * (1 - ramp(p, from: 0.1, to: 0.2))
        pose.headsetOff = ramp(p, from: 0.15, to: 0.35)
        pose.maskDrop = ramp(p, from: 0.3, to: 0.45)
        let sigh = bump(p, from: 0.6, to: 0.85)
        pose.headDy = 2 * ramp(p, from: 0.5, to: 0.6) + 1.5 * sigh
        pose.stretch = -0.5 * sigh
        pose.blink = max(0.15, (1 - 0.5 * sigh) * blink(at: time))
        return pose
    }

    /// Applies `still` to a plain `mode` pose, for portraits.
    mutating func show(_ still: PortraitStill, mode: Mode) {
        switch (still, mode) {
        case (.plain, _):
            break
        case (.glance, .chill):
            // Mid-sip.
            canAngle = -28
            canOffset = CGSize(width: -6, height: -6)
        case (.glance, .money):
            eyesDx = 3
        case (.glance, _):
            eyesDx = -3
        case (.alt, .work):
            // Zoned out in the music.
            headDy = 1.5
            blink = 0.55
        case (.alt, .chill):
            eyesDx = 3
            headDy = 1
        case (.alt, .boxing):
            gloveL = CGSize(width: 0, height: -10)
            gloveR = CGSize(width: 0, height: -12)
        case (.alt, .money):
            eyesDy = -1.5
            eyesDx = -2
        }
    }

    /// Noticing you at `progress` (0...1) after the app opens: eyes elsewhere, then a half-beat late turn
    /// to you with a small lift of the head. With `lookUp`, HAKU starts with its head down and looks up
    /// at you higher and slower.
    mutating func notice(progress: Double, lookUp: Bool = false) {
        let p = CGFloat(min(max(progress, 0), 1))
        guard lookUp else {
            eyesDx += 3 * (1 - Self.ramp(p, from: 0.55, to: 0.75))
            headDy -= 1.5 * Self.bump(p, from: 0.6, to: 0.9)
            return
        }
        let up = Self.ramp(p, from: 0.35, to: 0.6)
        eyesDy += 2 * (1 - up)
        headDy += 1.5 * (1 - up) - 3 * Self.bump(p, from: 0.45, to: 0.95)
    }

    /// Turning its back on you at `progress` (0...1): a squeeze to turn around, the back of the head, then a
    /// squeeze back.
    mutating func turnAway(progress: Double) {
        let p = CGFloat(min(max(progress, 0), 1))
        turnedAway = p > 0.12 && p < 0.88
        turnSqueeze = max(0.05, min(1, abs(p - 0.12) / 0.12, abs(p - 0.88) / 0.12))
    }

    /// Rubbing an eye at `progress` (0...1): the fist comes up, rubs, and goes down; eyes nearly shut.
    mutating func rubEyes(progress: Double) {
        rubEye = CGFloat(min(max(progress, 0), 1))
        blink = min(blink, 0.25)
        headDy += 1
    }

    /// Whistling innocently at `progress` (0...1) after a tap made HAKU hide its snack or sketchbook: the prop
    /// gets hidden, the eyes look away, and a note floats from the mouth once the hiding is done.
    mutating func whistle(progress: Double) {
        let p = CGFloat(min(max(progress, 0), 1))
        // The tap's own snatch-away plays first; this only takes over once it is under way.
        let k = Self.ramp(p, from: 0.15, to: 0.3)
        propHidden = max(propHidden, k)
        eyesDx += (3 - eyesDx) * k
        eyesDy += (-1 - eyesDy) * k
        whistle = p < 0.3 ? -1 : (p - 0.3) / 0.7
    }

    /// The still bedtime pose, used for portraits and reduced motion.
    static func bedtimeStill() -> RunnerPose {
        var pose = bedtime(time: 2, goodnight: 1, liesDown: false)
        pose.yawn = 0
        pose.blink = 1
        pose.headDy = 1.5
        pose.zzz = 0.35
        return pose
    }

    /// 0 before `from`, 1 after `to`, linear in between.
    static func ramp(_ x: CGFloat, from a: CGFloat, to b: CGFloat) -> CGFloat {
        min(max((x - a) / (b - a), 0), 1)
    }

    /// `x` (0...1) eased in and out.
    private static func smooth(_ x: CGFloat) -> CGFloat {
        x * x * (3 - 2 * x)
    }

    /// A half sine from `from` to `to`, 0 elsewhere.
    private static func bump(_ x: CGFloat, from a: CGFloat, to b: CGFloat) -> CGFloat {
        guard x > a, x < b else { return 0 }
        return sin((x - a) / (b - a) * .pi)
    }

    /// A quick blink every 4.5 s.
    private static func blink(at t: TimeInterval) -> CGFloat {
        let phase = t.truncatingRemainder(dividingBy: 4.5)
        guard phase < 0.16 else { return 1 }
        return max(0.1, CGFloat(abs(phase - 0.08) / 0.08))
    }
}

// Vector parts let every piece move on its own. When `runner.riv` exists, Rive takes over and
// this stays as the static fallback.
/// RUNNER drawn from the named vector parts in `RunnerArt`.
struct RunnerFigure: View {
    var mode: Mode
    var pose = RunnerPose()

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / RunnerArt.bounds.width
            ZStack {
                ZStack {
                    ForEach(Self.parts(for: mode, pose: pose), id: \.self) { part in
                        layer(part, scale: scale)
                    }
                    if pose.sleepTalk >= 0, pose.life == .nap, !pose.bedtime {
                        RunnerTextView(text: Self.sleepTalkText)
                            .offset(x: 3 * pose.sleepTalk * scale, y: (pose.headDy - 6 * pose.sleepTalk) * scale)
                            .opacity(Double(sin(pose.sleepTalk * .pi)))
                    }
                    if pose.tired, mode == .boxing, !pose.bedtime {
                        SweatDrop()
                            .offset(x: 0, y: pose.headDy * scale)
                    }
                    if pose.armsUp > 0 {
                        StretchArms(raise: pose.armsUp, sleeve: Self.jacketColor(mode))
                    }
                }
                .rotationEffect(.degrees(pose.lean), anchor: Self.unit(x: 60, y: 140))
                .opacity(pose.presence)
                .offset(x: pose.shift * scale, y: pose.bounce * scale)
                .scaleEffect(
                    x: (1 - 0.03 * pose.stretch) * pose.turnSqueeze,
                    y: (1 + 0.06 * pose.stretch) * max(pose.popOut, 0.001),
                    anchor: .bottom
                )
                if pose.unbox >= 0 {
                    GiftBox(progress: pose.unbox)
                }
            }
        }
        .aspectRatio(RunnerArt.bounds.width / RunnerArt.bounds.height, contentMode: .fit)
    }

    /// Visible parts in back-to-front order.
    nonisolated static func parts(for mode: Mode, pose: RunnerPose) -> [RunnerPart] {
        var visible: Set<RunnerPart>
        if pose.offWorking {
            visible = offWorkParts(pose)
        } else if pose.stayingHome {
            visible = stayHomeParts(pose)
        } else if pose.reviving {
            visible = reviveParts(pose)
        } else {
            visible = modeParts(for: mode, pose: pose)
        }
        wear(pose, mode: mode, on: &visible)
        if pose.rubEye >= 0 { visible.insert(.rubHand) }
        if pose.hum >= 0 || pose.whistle >= 0 { visible.insert(.musicNote) }
        if pose.thump >= 0 || pose.fistPump >= 0 { visible.insert(.backFist) }
        if pose.thumpHit { visible.insert(.thumpLines) }
        if let prop = pose.dailyProp, !pose.bedtime { holdUp(prop, pose: pose, on: &visible) }
        if let place = pose.walkFrom, pose.dailyScene == nil, !pose.bedtime { visible.formUnion(walkParts(place)) }
        if pose.bathDry >= 0 {
            visible.subtract(bathHides)
            visible.formUnion([.bathTowel, .headSteam, .bathBlush, .dropsL, .dropsR, .rubTowelL, .rubTowelR])
        } else if pose.bathCall >= 0 {
            visible.subtract(bathHides)
            visible.formUnion([.bathBubbles, .bathTowel, .shampoo, .rubberDuck])
        }
        if pose.noteSlap >= 0 {
            visible.insert(.bigNote)
            let t = pose.noteSlap * CGFloat(RunnerPose.noteSlapLength)
            if t > 0.25, t < 0.8 { visible.insert(.noteHit) }
        }
        if pose.eyesShut {
            visible.subtract(openEyes)
            visible.insert(.eyesClosed)
        }
        poked(&visible, pose: pose)
        if pose.turnedAway { visible = visible.intersection(backParts).union([.headBack]) }
        return RunnerPart.allCases.filter { visible.contains($0) }
    }

    /// Wardrobe items over the visible parts: striped masks and, at home, the room item.
    nonisolated private static func wear(_ pose: RunnerPose, mode: Mode, on visible: inout Set<RunnerPart>) {
        let outfit = pose.outfit
        if outfit.stripedMask, visible.contains(.maskUp) {
            visible.remove(.panelLines)
            visible.insert(.maskStripes)
        }
        if outfit.stripedMask, visible.contains(.maskDown) { visible.insert(.maskStripesDown) }
        // The room item stays home: hidden while HAKU carries the gym bag or is out boxing, lifting or running.
        if mode == .chill, let room = outfit.room, visible.isDisjoint(with: awayParts) { visible.insert(room) }
        if outfit.peaceSign, pose.burst >= 0, !pose.bedtime { visible.insert(.peaceHand) }
        // Today's traces: the bandage goes everywhere, the monitor and the sunlight are in the room at home.
        if pose.traces.contains(.bandage) { visible.insert(.bandage) }
        let home = mode == .chill && visible.isDisjoint(with: awayParts.union([.door]))
        if home, pose.traces.contains(.pcGlow) { visible.insert(.roomPc) }
        if home, pose.traces.contains(.sunlight) { visible.insert(.sunlight) }
        // Lasting traces: worn gloves wherever the gloves are, the monitor while vibe coding, shoes at home.
        if pose.traces.contains(.wornGloves) {
            if visible.contains(.gloveL) { visible.insert(.gloveTapeLeft) }
            if visible.contains(.gloveR) { visible.insert(.gloveTapeRight) }
        }
        if pose.traces.contains(.deskMonitor), visible.contains(.ledCode) { visible.insert(.deskMonitor) }
        if home, pose.traces.contains(.runningShoes) { visible.insert(.runningShoes) }
    }

    // The bag from the office comes with `bagLift`.
    /// Speed lines and dust while walking, with what HAKU carries away from `place`: earbuds from home, a towel
    /// from the gym, a bandage from boxing.
    nonisolated private static func walkParts(_ place: HubPlace.Kind) -> Set<RunnerPart> {
        switch place {
        case .home: [.speedLines, .walkDust, .earbud]
        case .fitness: [.speedLines, .walkDust, .towel]
        case .gym: [.speedLines, .walkDust, .bandage]
        case .office, .custom: [.speedLines, .walkDust]
        }
    }

    nonisolated private static let bathHides: Set<RunnerPart> = [
        .monsterCan, .headset, .cupL, .cupR, .mic, .phone, .phoneFeed, .phoneHand, .handheld, .onigiri,
    ]

    /// The planned task's prop, and the watch while HAKU taps it.
    nonisolated private static func holdUp(_ prop: DailyProp, pose: RunnerPose, on visible: inout Set<RunnerPart>) {
        if pose.watchTap { visible.formUnion([.watchWrist, .tapHand]) }
        if let scene = pose.dailyScene {
            if pose.propRaise > 0 {
                visible.subtract(scene.hides)
                visible.formUnion(scene.parts)
            }
            visible.remove(.monsterCan)
            return
        }
        switch prop {
        case .headphones: visible.formUnion(headsetParts)
        case .gymBag: visible.insert(.gymBag)
        case .bag: visible.insert(.shopBag)
        case .note:
            if pose.propRaise > 0 { visible.insert(.stickyNote) }
        }
        // The right hand holds the note or taps the watch, so the can goes.
        visible.remove(.monsterCan)
    }

    nonisolated private static let awayParts: Set<RunnerPart> = [.gymBag, .heavyBag, .dumbbell, .speedLines]

    nonisolated private static func modeParts(for mode: Mode, pose: RunnerPose) -> Set<RunnerPart> {
        var visible = baseParts
        if let moment = pose.moment {
            visible = momentParts(moment, pose: pose)
        } else {
            switch mode {
            case .work:
                visible.formUnion(workParts)
                if !pose.ledDots { visible.insert(.ledLine) }
                if pose.phoneGlance { visible.formUnion([.phone, .phoneHand]) }
            case .chill:
                visible.formUnion(chillParts)
                if pose.emptyCan {
                    visible.subtract([.eyesChill, .mouthSmile])
                    visible.formUnion(deadpanEyes)
                }
                if pose.scratch >= 0 { visible.insert(.scratchHand) }
                if pose.tuft > 0 { visible.insert(.hairTuft) }
            case .boxing:
                visible.formUnion(boxingParts)
            case .money:
                visible.formUnion(moneyParts)
            }
        }
        if pose.tired, mode != .chill { visible.insert(.eyebags) }
        if pose.need == .couchScroll, !pose.bedtime {
            visible.subtract(couchHiddenParts)
            visible.formUnion(couchParts)
        }
        if pose.need == .boxingWarmup, !pose.bedtime {
            visible.formUnion(warmupParts)
            visible.remove(.monsterCan)
        }
        if pose.bagLift >= 0, !pose.bedtime { visible.insert(.gymBag) }
        if let activity = pose.activity, !pose.bedtime {
            visible.remove(.monsterCan)
            visible.formUnion(activityParts(activity))
        }
        if let life = pose.life, pose.need == nil, pose.activity == nil, !pose.bedtime {
            let added = lifeParts(life)
            visible.remove(.monsterCan)
            if !added.isDisjoint(with: [.eyesSleepy, .eyesWork]) { visible.remove(.eyesChill) }
            visible.formUnion(added)
        }
        if pose.burst >= 0, !pose.bedtime, let kind = pose.cheerKind, let props = cheerParts[kind] {
            visible.remove(.monsterCan)
            visible.formUnion(props)
        }
        if pose.face == .high || pose.burst >= 0 {
            visible.insert(.sparkle)
            if mode != .chill, pose.need != .couchScroll { visible.insert(.eyeGlint) }
        }
        if pose.bedtime {
            visible.subtract(awakeFaceParts)
            visible.formUnion(sleepyParts)
            visible.subtract([.sparkle, .eyeGlint])
            if pose.headsetOff >= 1 { visible.subtract(headsetParts) }
            if pose.yawn > 0.05 { visible.insert(.mouthYawn) }
            if pose.lie > 0 { visible.insert(.pillow) }
            if pose.zzz >= 0 { visible.insert(.zzz) }
        }
        return visible
    }

    /// The base parts with the look of `moment`, whatever the mode.
    nonisolated private static func momentParts(_ moment: CompanionMoment, pose: RunnerPose) -> Set<RunnerPart> {
        var visible = baseParts
        switch moment {
        case .slacking:
            visible.formUnion(workParts.union([.ledLine, .laptop, .typingHands]))
        case .drowsy:
            visible.formUnion(headsetParts.union([.eyesSleepy, .eyebags, .maskDown, .earringNeon, .monsterCan]))
            if pose.yawn > 0.05 { visible.insert(.mouthYawn) }
        case .overtime:
            visible.formUnion(headsetParts.union([.eyesSleepy, .eyebags, .maskDown, .desk]))
            if pose.soulRise >= 0 { visible.insert(.soul) }
        case .gymInvite:
            visible.formUnion(chillParts.subtracting([.monsterCan]).union([.door, .towel, .handWeight]))
        case .heading:
            visible.formUnion(chillParts.subtracting([.monsterCan]).union([.towel]))
        case .vibeCoding, .flow, .lateCoding:
            visible.remove(.stripeNeon)
            visible.formUnion(codingParts)
            let stacks: [RunnerPart] = [.canStackOne, .canStackTwo, .canStackThree]
            visible.formUnion(stacks.prefix(max(0, min(pose.codingCans, stacks.count))))
            if moment == .flow {
                visible.subtract([.eyesWork, .lidsWork])
                visible.formUnion([.eyesMoney, .eyeGlint, .codeBits, .monsterCan])
            }
            if moment == .lateCoding {
                visible.subtract([.eyesWork, .lidsWork])
                visible.formUnion([.eyesSleepy, .eyebags])
            }
        case .shooting:
            visible.formUnion(moneyParts)
        case .collapsed:
            visible.formUnion([.eyesSleepy, .eyebags, .maskDown, .earringNeon, .sofaArm])
        case .blanket:
            visible.formUnion([.blanket, .eyesSleepy, .maskDown, .earringNeon, .earbud])
        case .morning:
            visible.formUnion([.eyesSleepy, .eyebags, .maskDown, .earringNeon, .toothbrush])
        case .timeToLeave:
            visible.formUnion(workParts.union([.ledLine, .door, .watchWrist, .tapHand]))
        case .stiff:
            visible.formUnion(workParts.union([.ledLine]))
        case .packingUp:
            visible.formUnion(workParts.union([.ledLine, .desk]))
            if pose.headsetOff >= 1 { visible.subtract(headsetParts) }
            visible.insert(pose.lidClose >= 1 ? .laptopClosed : .laptop)
            switch pose.packStep {
            case 0:
                if pose.typing.height > -6 { visible.insert(.typingHands) }
            case 1:
                visible.insert(.cloth)
            case 2:
                break
            default:
                visible.formUnion([.watchWrist, .tapHand])
            }
        }
        return visible
    }

    nonisolated private static let codingParts: Set<RunnerPart> = [
        .hoodieStrings, .eyesWork, .lidsWork, .maskUp, .panelLines, .ledCode, .earringNeon, .laptop,
        .typingHands,
    ]

    /// Work look turning into the chill look as the off-work animation plays, whatever the mode.
    nonisolated private static func offWorkParts(_ pose: RunnerPose) -> Set<RunnerPart> {
        var visible = baseParts.union([.earringNeon])
        let relaxed = pose.offWork >= 0.6
        visible.formUnion(relaxed ? [.eyesChill, .mouthSmile, .monsterCan] : [.eyesWork, .lidsWork, .browsWork])
        if pose.headsetOff < 1 { visible.formUnion(headsetParts) }
        if pose.maskDrop < 1 { visible.formUnion([.maskUp, .panelLines, .ledLine]) }
        if pose.maskDrop > 0 { visible.insert(.maskDown) }
        if pose.yawn > 0.05 { visible.insert(.mouthYawn) }
        return visible
    }

    /// The waiting-at-the-door look turning into sitting on the sofa, whatever the mode.
    nonisolated private static func stayHomeParts(_ pose: RunnerPose) -> Set<RunnerPart> {
        var visible = baseParts.union([.earringNeon])
        let seated = pose.stayHome >= 0.5
        visible.formUnion(seated ? [.eyesSleepy, .sofaArm] : [.eyesWork, .lidsWork, .browsWork, .door, .watchWrist])
        if pose.headsetOff < 1 { visible.formUnion(headsetParts) }
        if pose.maskDrop < 1 { visible.formUnion([.maskUp, .panelLines, .ledLine]) }
        if pose.maskDrop > 0 { visible.insert(.maskDown) }
        return visible
    }

    /// Slumped on the sofa with the phone turning into standing with the mask up, whatever the mode.
    nonisolated private static func reviveParts(_ pose: RunnerPose) -> Set<RunnerPart> {
        var visible = baseParts.union([.earringNeon])
        let t = pose.revive
        visible.insert(t < RunnerPose.reviveWake ? .eyesSleepy : .eyesChill)
        if t < RunnerPose.revivePhoneGone { visible.formUnion([.phone, .phoneFeed, .phoneHand]) }
        if t < RunnerPose.reviveSofaGone { visible.insert(.sofaArm) }
        if pose.maskDrop > 0.5 { visible.insert(.mouthSmile) }
        if pose.maskDrop < 1 { visible.formUnion([.maskUp, .panelLines]) }
        if pose.maskDrop > 0 { visible.insert(.maskDown) }
        if pose.maskDrop == 0 { visible.insert(.ledCode) }
        return visible
    }

    nonisolated static let baseParts: Set<RunnerPart> = [
        .jacket, .stripeNeon, .hoodCollar, .hairBack, .earL, .earR, .faceBase, .hairFringe,
    ]
    nonisolated private static let workParts: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .eyebags, .browsWork, .maskUp, .panelLines, .headset, .cupL, .cupR, .mic,
    ]
    nonisolated private static let chillParts: Set<RunnerPart> = [
        .eyesChill, .mouthSmile, .maskDown, .earringNeon, .earbud, .monsterCan,
    ]
    nonisolated private static let boxingParts: Set<RunnerPart> = [
        .cateyeL, .cateyeR, .browsBox, .mouthFang, .maskDown, .earringNeon, .headband, .gloveL, .gloveR,
    ]
    nonisolated private static let moneyParts: Set<RunnerPart> = [
        .eyesMoney, .maskUp, .panelLines, .ledYen, .earringNeon, .chainGold, .coin,
    ]
    nonisolated private static let awakeFaceParts: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .browsWork, .eyesChill, .cateyeL, .cateyeR, .browsBox, .eyesMoney,
        .mouthSmile, .mouthFang, .maskUp, .panelLines, .ledLine, .ledYen, .ledCode,
    ]
    nonisolated private static let warmupParts: Set<RunnerPart> = [.headband, .gloveL, .gloveR]
    /// What still shows from behind: the room, the jacket, the back of the head and the headset or headband.
    nonisolated private static let backParts: Set<RunnerPart> = [
        .door, .sunlight, .roomPc, .deskMonitor, .pillow, .roomPlant, .roomBag, .runningShoes, .heavyBag,
        .speedLines, .desk, .canStackOne, .canStackTwo, .canStackThree, .sofaArm,
        .jacket, .hoodCollar, .hairBack, .earL, .earR, .headset, .cupL, .cupR, .headband,
    ]
    nonisolated private static let openEyes: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .eyesChill, .cateyeL, .cateyeR, .eyesMoney, .eyeGlint, .eyesSleepy,
    ]
    nonisolated private static let couchParts: Set<RunnerPart> = [.eyesSleepy, .phone, .phoneFeed, .phoneHand]
    nonisolated private static let couchHiddenParts: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .browsWork, .eyesChill, .cateyeL, .cateyeR, .browsBox, .eyesMoney,
        .mouthSmile, .mouthFang, .monsterCan,
    ]
    nonisolated private static let sleepyParts: Set<RunnerPart> = [.eyesSleepy, .eyebags, .maskDown]
    nonisolated private static let headsetParts: Set<RunnerPart> = [.headset, .cupL, .cupR, .mic]
    nonisolated private static let cheerParts: [WorkoutSummary.Kind: Set<RunnerPart>] = [
        .boxing: [.gloveL, .gloveR],
        .running: [.peaceHand],
        .strength: [.dumbbell],
    ]
    nonisolated private static let deadpanEyes: Set<RunnerPart> = [.eyesWork, .lidsWork, .browsWork]

    nonisolated private static func activityParts(_ activity: CompanionActivity) -> Set<RunnerPart> {
        switch activity {
        case .boxingAtGym: warmupParts.union([.heavyBag])
        case .gymSession: [.dumbbell]
        case .running: [.speedLines]
        case .runDay: [.runShoe]
        case .gymDay: []
        }
    }

    nonisolated private static func lifeParts(_ life: IdleLife) -> Set<RunnerPart> {
        switch life {
        case .nap: [.pillow, .eyesSleepy, .zzz]
        case .handheld: deadpanEyes.union([.handheld])
        case .snack: [.onigiri]
        case .drawing: deadpanEyes.union([.sketchbook, .pencil])
        case .practice: [.gloveL, .gloveR]
        case .tidying: [.cloth]
        }
    }

    @ViewBuilder private func layer(_ part: RunnerPart, scale: CGFloat) -> some View {
        let isHead = Self.headParts.contains(part)
        Group {
            if pose.propRaise > 0, let scene = pose.dailyScene,
                let move = SceneMove.of(part, in: scene, at: pose.sceneTime)
            {
                moved(part, move, scale: scale).opacity(Double(pose.propRaise))
            } else if let move = SceneMove.bath(part, call: pose.bathCall, dry: pose.bathDry, shift: pose.shift) {
                moved(part, move, scale: scale)
            } else if let move = SceneMove.revive(part, at: pose.revive) {
                moved(part, move, scale: scale)
            } else if part == .walkDust, pose.walkFrom != nil {
                moved(part, SceneMove.dust(at: pose.walkTime), scale: scale)
            } else {
                partView(part, scale: scale)
            }
        }
        .offset(y: (isHead ? pose.headDy : 0) * scale)
        .offset(y: isHead || Self.chinParts.contains(part) ? 30 * pose.slump * scale : 0)
        .rotationEffect(
            .degrees(isHead ? -14 * Double(pose.lie) + pose.headTilt : 0),
            anchor: Self.unit(x: 60, y: 96)
        )
    }

    private func moved(_ part: RunnerPart, _ move: SceneMove, scale: CGFloat) -> some View {
        RunnerPartView(part: part)
            .scaleEffect(move.scale, anchor: move.anchor)
            .rotationEffect(.degrees(move.angle), anchor: move.anchor)
            .offset(x: move.offset.width * scale, y: move.offset.height * scale)
            .opacity(move.opacity)
    }

    @ViewBuilder private func partView(_ part: RunnerPart, scale: CGFloat) -> some View {
        Group {
            switch part {
            case .eyesWork, .lidsWork, .cateyeL, .cateyeR, .eyesMoney, .eyesSleepy, .eyeGlint:
                RunnerPartView(part: part)
                    .scaleEffect(x: 1, y: pose.blink, anchor: Self.unit(x: 60, y: 65))
                    .offset(x: pose.eyesDx * scale, y: pose.eyesDy * scale)
            case .eyesChill:
                // Closed smiling eyes don't blink, but they still look at the door while warming up.
                RunnerPartView(part: part).offset(x: pose.eyesDx * scale)
            case .maskUp where pose.unmasking, .panelLines where pose.unmasking, .ledLine where pose.unmasking,
                .maskStripes where pose.unmasking:
                // Off work or staying home: the mask slides down to the chin.
                RunnerPartView(part: part)
                    .offset(y: 12 * pose.maskDrop * scale)
                    .opacity(Double(1 - pose.maskDrop))
            case .maskDown where pose.unmasking, .maskStripesDown where pose.unmasking:
                RunnerPartView(part: part).opacity(Double(pose.maskDrop))
            case .ledLine where pose.ledFlare > 0:
                // Flares wider with a glow.
                RunnerPartView(part: part)
                    .scaleEffect(x: 1 + 0.3 * pose.ledFlare, y: 1, anchor: Self.unit(x: 60, y: 82))
                    .shadow(color: RunnerPalette.neonCyan, radius: 4 * pose.ledFlare * scale)
            case .ledLine:
                RunnerPartView(part: part).opacity(pose.ledOpacity)
            case .cupR where pose.cupRUp > 0:
                // Pushed up off the ear, tilting back.
                RunnerPartView(part: part)
                    .rotationEffect(.degrees(-28 * pose.cupRUp), anchor: Self.unit(x: 108, y: 70))
                    .offset(x: -6 * pose.cupRUp * scale, y: (-20 * pose.cupRUp - 24 * pose.headsetOff) * scale)
                    .opacity(Double(1 - pose.headsetOff))
            case .headset, .cupL, .cupR, .mic:
                RunnerPartView(part: part)
                    .offset(y: -24 * pose.headsetOff * scale)
                    .opacity(Double(1 - pose.headsetOff))
            case .mouthYawn:
                RunnerPartView(part: part)
                    .scaleEffect(x: 0.7 + 0.3 * pose.yawn, y: pose.yawn, anchor: Self.unit(x: 60, y: 85))
            case .backFist where pose.fistPump >= 0:
                // Pumped up in front of the shoulder.
                RunnerPartView(part: part)
                    .scaleEffect(1.4, anchor: Self.unit(x: 87, y: 99))
                    .offset(x: 4 * scale, y: (8 - 22 * pose.fistPump) * scale)
            case .backFist, .thumpLines:
                RunnerPartView(part: part).offset(y: (4 * pose.thump - 2) * scale)
            case .scratchHand:
                RunnerPartView(part: part)
                    .offset(x: 1.5 * sin(pose.scratch * 8 * .pi) * scale, y: -scale)
            case .hairTuft:
                RunnerPartView(part: part)
                    .scaleEffect(x: 1, y: max(pose.tuft, 0.001), anchor: Self.unit(x: 51, y: 31))
            case .musicNote where pose.whistle >= 0:
                // Whistled: starts at the mouth instead of by the head.
                RunnerPartView(part: part)
                    .offset(x: (-34 + 4 * pose.whistle) * scale, y: (52 - 10 * pose.whistle) * scale)
                    .opacity(Double(sin(pose.whistle * .pi)))
            case .musicNote:
                // Floats up and sways a little as it fades.
                RunnerPartView(part: part)
                    .offset(x: 3 * sin(pose.hum * 2 * .pi) * scale, y: -10 * pose.hum * scale)
                    .opacity(Double(sin(pose.hum * .pi)))
            case .rubHand:
                // Up from below, a few small rubs, back down.
                let up = min(
                    RunnerPose.ramp(pose.rubEye, from: 0, to: 0.15),
                    1 - RunnerPose.ramp(pose.rubEye, from: 0.85, to: 1)
                )
                RunnerPartView(part: part)
                    .offset(x: 1.5 * sin(pose.rubEye * 6 * .pi) * scale, y: 12 * (1 - up) * scale)
                    .opacity(Double(up))
            case .zzz:
                RunnerPartView(part: part)
                    .offset(x: 4 * pose.zzz * scale, y: -8 * pose.zzz * scale)
                    .opacity(Double(sin(pose.zzz * .pi)))
            case .phoneFeed:
                // The feed jumps up one post on each thumb flick.
                RunnerPartView(part: part)
                    .offset(y: -5 * pose.feed * scale)
                    .opacity(Double(1 - 0.6 * pose.feed))
            case .sparkle where pose.burst >= 0:
                // Celebration: the sparkles fly out from the head and fade.
                RunnerPartView(part: part)
                    .scaleEffect(0.8 + 0.7 * pose.burst, anchor: Self.unit(x: 60, y: 40))
                    .opacity(Double(sin(pose.burst * .pi)))
            case .sparkle:
                RunnerPartView(part: part)
                    .scaleEffect(0.8 + 0.2 * pose.sparkle, anchor: Self.unit(x: 60, y: 27))
                    .opacity(pose.sparkle)
            case .ledYen:
                RunnerPartView(part: part)
                    .offset(x: pose.yenDx * scale)
                    .opacity(pose.tired ? 0.45 : 1)
            case .maskUp where pose.ledDots:
                ZStack {
                    RunnerPartView(part: part)
                    RunnerTextView(text: Self.dots)
                }
            case .jacket:
                RunnerPartView(part: part, fillOverride: Self.jacketColor(mode))
            case .gymBag:
                // Lifted from the floor by the door onto the left shoulder.
                RunnerPartView(part: part)
                    .rotationEffect(.degrees(-10 * Double(pose.bagLift)), anchor: Self.unit(x: 24, y: 122))
                    .offset(x: 6 * pose.bagLift * scale, y: -16 * pose.bagLift * scale)
            case .shopBag:
                // Picked up from the floor by the door.
                RunnerPartView(part: part)
                    .rotationEffect(.degrees(-6 * Double(pose.propRaise)), anchor: Self.unit(x: 22, y: 120))
                    .offset(x: 4 * pose.propRaise * scale, y: -14 * pose.propRaise * scale)
            case .stickyNote:
                // Held up from below by the cheek.
                RunnerPartView(part: part).offset(y: 44 * (1 - pose.propRaise) * scale)
            case .bigNote:
                // Slapped on the screen with a bounce, held, then peeled off down and to the left.
                let t = pose.noteSlap * CGFloat(RunnerPose.noteSlapLength)
                let peel = RunnerPose.ramp(t, from: 2.4, to: 3)
                RunnerPartView(part: part)
                    .scaleEffect(RunnerPose.noteSize(at: t), anchor: Self.unit(x: 60, y: 60))
                    .rotationEffect(.degrees(-28 * Double(peel)), anchor: Self.unit(x: 16, y: 14))
                    .offset(y: 40 * peel * peel * scale)
                    .opacity(Double(1 - peel))
            case .peaceHand:
                // A sneaky peace sign pops up by the cheek and wiggles.
                RunnerPartView(part: part)
                    .scaleEffect(min(1, max(pose.burst, 0) * 4), anchor: Self.unit(x: 96, y: 84))
                    .rotationEffect(.degrees(Double(sin(pose.burst * 6 * .pi)) * 8), anchor: Self.unit(x: 96, y: 84))
            case .handWeight:
                RunnerPartView(part: part).offset(y: -8 * pose.lift * scale)
            case .dumbbell:
                // Two quick reps in a celebration, or the curl at the gym.
                RunnerPartView(part: part).offset(y: -12 * pose.dumbbellRise * scale)
            case .heavyBag:
                RunnerPartView(part: part).rotationEffect(.degrees(pose.bagSwing), anchor: Self.unit(x: 12, y: -6))
            case .speedLines:
                RunnerPartView(part: part)
                    .offset(x: -8 * pose.dash * scale)
                    .opacity(Double(1 - 0.7 * pose.dash))
            case .handheld, .cloth, .runShoe, .toothbrush, .tapHand:
                RunnerPartView(part: part).offset(x: pose.prop.width * scale, y: pose.prop.height * scale)
            case .onigiri:
                RunnerPartView(part: part)
                    .offset(x: pose.prop.width * scale, y: (pose.prop.height + 34 * pose.propHidden) * scale)
                    .opacity(Double(1 - pose.propHidden))
            case .sketchbook:
                RunnerPartView(part: part)
                    .offset(y: 34 * pose.propHidden * scale)
                    .opacity(Double(1 - pose.propHidden))
            case .pencil:
                RunnerPartView(part: part)
                    .offset(x: pose.pencil.width * scale, y: (pose.pencil.height + 34 * pose.propHidden) * scale)
                    .opacity(Double(1 - pose.propHidden))
            case .monsterCan:
                RunnerPartView(part: part)
                    .scaleEffect(pose.canScale, anchor: Self.unit(x: 102, y: 136))
                    .rotationEffect(.degrees(pose.canAngle), anchor: Self.unit(x: 102, y: 136))
                    .offset(x: pose.canOffset.width * scale, y: pose.canOffset.height * scale)
                    .opacity(pose.canOpacity)
            case .headband:
                RunnerPartView(part: part, red: pose.outfit.headband)
            case .gloveL:
                RunnerPartView(part: part, red: pose.outfit.gloves)
                    .offset(x: pose.gloveL.width * scale, y: pose.gloveL.height * scale)
            case .gloveR:
                RunnerPartView(part: part, red: pose.outfit.gloves)
                    .scaleEffect(pose.gloveRScale, anchor: Self.unit(x: 86, y: 118))
                    .offset(x: pose.gloveR.width * scale, y: pose.gloveR.height * scale)
            case .gloveTapeLeft:
                RunnerPartView(part: part).offset(x: pose.gloveL.width * scale, y: pose.gloveL.height * scale)
            case .gloveTapeRight:
                RunnerPartView(part: part)
                    .scaleEffect(pose.gloveRScale, anchor: Self.unit(x: 86, y: 118))
                    .offset(x: pose.gloveR.width * scale, y: pose.gloveR.height * scale)
            case .laptop where pose.lidClose > 0:
                // The lid folds down toward the desk.
                RunnerPartView(part: part)
                    .scaleEffect(x: 1, y: 1 - 0.8 * pose.lidClose, anchor: Self.unit(x: 60, y: 138))
            case .laptop:
                RunnerPartView(part: part).offset(y: -24 * pose.peek * scale)
            case .typingHands:
                RunnerPartView(part: part)
                    .offset(x: pose.typing.width * scale, y: (pose.typing.height - 24 * pose.peek) * scale)
            case .soul:
                RunnerPartView(part: part)
                    .offset(y: -12 * pose.soulRise * scale)
                    .opacity(Double(sin(pose.soulRise * .pi)))
            case .codeBits:
                RunnerPartView(part: part).opacity(pose.codeGlow)
            case .chainGold:
                RunnerPartView(part: part)
                    .overlay {
                        if pose.glint >= 0 {
                            ChainGlint(position: pose.glint)
                                .mask { RunnerPartView(part: part) }
                        }
                    }
            case .coin:
                RunnerPartView(part: part)
                    .rotation3DEffect(
                        .degrees(pose.coinTurn),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: Self.unit(x: 60, y: 120)
                    )
            default:
                RunnerPartView(part: part)
            }
        }
    }

    private static let dots = RunnerText(
        string: "•••",
        x: 60,
        y: 86,
        size: 9,
        color: RunnerPalette.neonCyan
    )

    private static let sleepTalkText = RunnerText(
        string: "…",
        x: 96,
        y: 46,
        size: 16,
        color: RunnerPalette.ink
    )

    /// Parts that move with the head.
    private static let headParts: Set<RunnerPart> = [
        .hairBack, .earL, .earR, .faceBase, .eyesWork, .lidsWork, .eyebags, .browsWork, .eyesChill,
        .cateyeL, .cateyeR, .browsBox, .eyesMoney, .mouthSmile, .mouthFang, .maskUp, .panelLines, .maskStripes,
        .ledLine, .ledYen, .hairFringe, .earringNeon, .earbud, .headband, .headset, .cupL, .cupR, .mic,
        .eyesSleepy, .mouthYawn, .eyeGlint, .sparkle, .ledCode, .bandage, .headBack, .rubHand,
        .scratchHand, .hairTuft, .eyesClosed, .hairBits, .screenGlow, .phoneEar, .talkDots, .cheekHand, .ouchLines,
        .bathTowel, .headSteam, .bathBlush, .dropsL, .dropsR,
    ]

    /// Parts at the chin that drop with the head onto the desk, but don't nod with it.
    private static let chinParts: Set<RunnerPart> = [.maskDown, .maskStripesDown]

    private static func jacketColor(_ mode: Mode) -> Color {
        switch mode {
        case .work, .boxing: RunnerPalette.jacket
        case .chill: RunnerPalette.jacketChill
        case .money: RunnerPalette.jacketMoney
        }
    }

    /// The head with headset and Z z z, in SVG units.
    nonisolated static let headBox = CGRect(x: 4, y: -6, width: 112, height: 106)

    /// An SVG point as a unit point of the figure's frame.
    static func unit(x: CGFloat, y: CGFloat) -> UnitPoint {
        let b = RunnerArt.bounds
        return UnitPoint(x: (x - b.minX) / b.width, y: (y - b.minY) / b.height)
    }
}

/// Draws one part, scaled from SVG units to the view's width.
struct RunnerPartView: View {
    let part: RunnerPart
    var fillOverride: Color?
    /// Replaces boxing red fills, for wardrobe gloves and headbands.
    var red: Color?

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            RunnerDrawing.draw(part, in: context, red: red, fillOverride: fillOverride)
        }
    }
}

/// Draws one `RunnerText` in figure space.
struct RunnerTextView: View {
    let text: RunnerText

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            RunnerDrawing.draw(text, in: context)
        }
    }
}

/// Shared drawing helpers for the figure's canvases.
enum RunnerDrawing {
    /// Maps SVG units onto a canvas that spans the whole figure frame.
    static func enterFigureSpace(_ context: inout GraphicsContext, size: CGSize) {
        let bounds = RunnerArt.bounds
        let scale = size.width / bounds.width
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
    }

    /// Draws `part` in figure space.
    /// - Parameters:
    ///   - red: replaces boxing red fills.
    ///   - fillOverride: replaces every fill.
    static func draw(_ part: RunnerPart, in context: GraphicsContext, red: Color? = nil, fillOverride: Color? = nil) {
        draw(RunnerArt.cachedInks(part), in: context, red: red, fillOverride: fillOverride)
        if let text = RunnerArt.text(part) {
            draw(text, in: context)
        }
    }

    /// Draws `inks` in figure space.
    /// - Parameters:
    ///   - red: replaces boxing red fills.
    ///   - fillOverride: replaces every fill.
    static func draw(_ inks: [RunnerInk], in context: GraphicsContext, red: Color? = nil, fillOverride: Color? = nil) {
        for ink in inks {
            var layer = context
            layer.opacity = ink.opacity
            if let clip = ink.clip { layer.clip(to: clip) }
            if let gradient = ink.gradient {
                layer.fill(ink.path, with: gradient.shading)
            } else if let fill = ink.fill {
                let swapped = fill == RunnerPalette.boxingRed ? red ?? fill : fill
                layer.fill(ink.path, with: .color((fillOverride ?? swapped).opacity(ink.fillOpacity)))
            }
            if let stroke = ink.stroke {
                let style = StrokeStyle(lineWidth: ink.lineWidth, lineCap: ink.cap, lineJoin: ink.join, dash: ink.dash)
                layer.stroke(ink.path, with: .color(stroke), style: style)
            }
        }
    }

    static func draw(_ text: RunnerText, in context: GraphicsContext) {
        let resolved = context.resolve(
            Text(text.string)
                .font(.system(size: text.size, weight: .bold))
                .foregroundStyle(text.color)
        )
        // `y` is the baseline; the bottom of the text box sits about one descent below it.
        context.draw(resolved, at: CGPoint(x: text.x, y: text.y + text.size * 0.22), anchor: .bottom)
    }
}

/// A soft white band that sweeps across the gold chain.
private struct ChainGlint: View {
    let position: CGFloat

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    RunnerPalette.white.opacity(0),
                    RunnerPalette.white.opacity(0.9),
                    RunnerPalette.white.opacity(0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.1)
            .offset(x: geo.size.width * position)
        }
    }
}

/// A drop of sweat by the temple, boxing day on low energy.
private struct SweatDrop: View {
    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            var drop = Path()
            drop.move(to: CGPoint(x: 92, y: 50))
            drop.addQuadCurve(to: CGPoint(x: 92, y: 62), control: CGPoint(x: 99, y: 58))
            drop.addQuadCurve(to: CGPoint(x: 92, y: 50), control: CGPoint(x: 85, y: 58))
            drop.closeSubpath()
            context.fill(drop, with: .color(RunnerPalette.neonCyan))
            context.stroke(drop, with: .color(RunnerPalette.ink), lineWidth: 2)
        }
    }
}

// Drawn in code rather than the SVG because the arms bend all along the swing.
/// Both arms swinging out to the sides and over the head; `raise` runs 0...1.
private struct StretchArms: View {
    var raise: CGFloat
    var sleeve: Color

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            let a = raise * raise * (3 - 2 * raise)
            // The left hand's path: out to the side, then over the head. The right hand mirrors it.
            func bezier(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat) -> CGFloat {
                let u = 1 - a
                return u * u * u * p0 + 3 * u * u * a * p1 + 3 * u * a * a * p2 + a * a * a * p3
            }
            let left = CGPoint(x: bezier(36, -14, -2, 55), y: bezier(104, 84, 0, -6))
            let ink = GraphicsContext.Shading.color(RunnerPalette.ink)
            let skin = GraphicsContext.Shading.color(RunnerPalette.skin)
            var hands: [CGPoint] = []
            for side in [CGFloat(-1), 1] {
                let shoulder = CGPoint(x: 60 + 24 * side, y: 104)
                let hand = CGPoint(x: side < 0 ? left.x : 120 - left.x, y: left.y)
                let elbow = CGPoint(
                    x: (shoulder.x + hand.x) / 2 + (16 + 36 * a) * side,
                    y: (shoulder.y + hand.y) / 2
                )
                var arm = Path()
                arm.move(to: shoulder)
                arm.addQuadCurve(to: hand, control: elbow)
                context.stroke(arm, with: ink, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                context.stroke(arm, with: .color(sleeve), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
                hands.append(hand)
            }
            // Two fists on the way up, clasped together at the top.
            let clasped = Path(ellipseIn: CGRect(x: 51, y: left.y - 8, width: 18, height: 12))
            let fists = hands.map { Path(ellipseIn: CGRect(x: $0.x - 5.5, y: $0.y - 5.5, width: 11, height: 11)) }
            for shape in a > 0.9 ? [clasped] : fists {
                context.fill(shape, with: skin)
                context.stroke(shape, with: ink, lineWidth: 2.5)
            }
        }
    }
}

// Drawn in code rather than the SVG because it only exists for the unboxing.
/// The gift box HAKU pops out of; `progress` runs 0...1.
private struct GiftBox: View {
    var progress: CGFloat

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            // Shakes twice, the flaps fly open, and once HAKU is out the box drops away.
            let shake = progress < 0.25 ? sin(progress / 0.25 * 6 * .pi) * 6 : 0
            let open = RunnerPose.ramp(progress, from: 0.22, to: 0.32)
            let drop = RunnerPose.ramp(progress, from: 0.85, to: 1)
            context.opacity = Double(1 - drop)
            context.translateBy(x: 60.5, y: 142 + 40 * drop)
            context.rotate(by: .degrees(Double(shake)))
            context.translateBy(x: -60.5, y: -142)
            let ink = GraphicsContext.Shading.color(RunnerPalette.ink)
            for side in [CGFloat(-1), 1] {
                var flap = context
                flap.translateBy(x: 60.5 + 36.5 * side, y: 104)
                flap.rotate(by: .degrees(Double(120 * open * side)))
                let rect = CGRect(x: side < 0 ? 0 : -36.5, y: -9, width: 36.5, height: 9)
                let path = Path(roundedRect: rect, cornerRadius: 2)
                flap.fill(path, with: .color(Toy.pink))
                flap.stroke(path, with: ink, lineWidth: 3)
            }
            let box = Path(roundedRect: CGRect(x: 24, y: 104, width: 73, height: 38), cornerRadius: 4)
            context.fill(box, with: .color(Toy.pink))
            let ribbon = Path(CGRect(x: 55, y: 104, width: 11, height: 38))
            context.fill(ribbon, with: .color(RunnerPalette.gold))
            context.stroke(ribbon, with: ink, lineWidth: 2)
            context.stroke(box, with: ink, lineWidth: 3)
        }
    }
}

/// RUNNER standing still in `mode`, for widgets, snapshots and anywhere motion isn't wanted.
public struct CompanionPortrait: View {
    /// How much of RUNNER to show.
    public enum Framing: Sendable {
        /// Head to waist.
        case full
        /// Head only, for small round widgets.
        case head
    }

    let mode: Mode
    let energy: Double?
    let need: CompanionNeed?
    let needSince: Date?
    let activity: CompanionActivity?
    let moment: CompanionMoment?
    let codingCans: Int
    let traces: Set<CompanionTrace>
    let vitals: HakuVitals
    let date: Date
    let bedtime: Bedtime
    let wardrobe: Wardrobe
    let daily: DailyCue?
    let walking: HubPlace.Kind?
    let bath: Bool
    let framing: Framing

    // WidgetKit renders future entries ahead of time, so `.now` would show the wrong couch stage.
    /// - Parameters:
    ///   - needSince: when `need` started; after 30 minutes of couch scrolling HAKU eyes the gym bag.
    ///   - activity: what HAKU does alongside Mike; it replaces the need.
    ///   - moment: the state within the mode, such as vibe coding; it replaces the need.
    ///   - codingCans: Monster cans piled up while vibe coding.
    ///   - traces: what today left in HAKU's world, such as a bandage after boxing.
    ///   - vitals: HAKU's hidden params; they change only how it looks.
    ///   - date: the moment shown, such as a widget timeline entry's date.
    ///   - wardrobe: what HAKU wears from the shop and keepsakes.
    ///   - daily: a planned Daily Widget task starting soon or now; HAKU holds up its prop.
    ///   - walking: the place Mike just left; HAKU walks with what it carries from there.
    ///   - bath: bath time before bed; HAKU carries shampoo and a rubber duck.
    public init(
        mode: Mode,
        energy: Double? = nil,
        need: CompanionNeed? = nil,
        needSince: Date? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        codingCans: Int = 0,
        traces: Set<CompanionTrace> = [],
        vitals: HakuVitals = HakuVitals(),
        date: Date = .now,
        bedtime: Bedtime = .off,
        wardrobe: Wardrobe = Wardrobe(),
        daily: DailyCue? = nil,
        walking: HubPlace.Kind? = nil,
        bath: Bool = false,
        framing: Framing = .full
    ) {
        self.mode = mode
        self.energy = energy
        self.need = need
        self.needSince = needSince
        self.activity = activity
        self.moment = moment
        self.codingCans = codingCans
        self.traces = traces
        self.vitals = vitals
        self.date = date
        self.bedtime = bedtime
        self.wardrobe = wardrobe
        self.daily = daily
        self.walking = walking
        self.bath = bath
        self.framing = framing
    }

    public var body: some View {
        Group {
            switch framing {
            case .full:
                figure
            case .head:
                HeadCrop { figure }
            }
        }
        .saturation(vitals.saturation)
        .brightness(vitals.brightness)
        .accessibilityLabel(
            CompanionLines.accessibilityLabel(
                mode: mode,
                need: need,
                peeking: peeking,
                activity: activity,
                moment: activity == nil ? moment : nil,
                bedtime: bedtime
            )
        )
    }

    private var peeking: Bool {
        guard activity == nil, moment == nil, need == .couchScroll else { return false }
        return CouchStage.at(date, since: needSince, inviting: false) == .peeking
    }

    private var figure: RunnerFigure {
        RunnerFigure(mode: mode, pose: pose.wearing(Outfit(wardrobe)).leaving(traces))
    }

    /// The pose shown at `date`. A plain mode changes still every 15 minutes; at home HAKU does the same
    /// thing on its own as in the app.
    var pose: RunnerPose {
        guard bedtime == .off else { return RunnerPose.bedtimeStill() }
        let plain = need == nil && activity == nil && moment == nil && daily == nil && walking == nil && !bath
        let life = plain && mode == .chill ? IdleLife.at(date, stamina: vitals.stamina) : nil
        var pose = RunnerPose(
            face: EnergyFace(energy: energy),
            need: need,
            life: life,
            activity: activity,
            moment: moment
        )
        pose.codingCans = codingCans
        pose.headDy += vitals.slouch
        if plain, life == nil { pose.show(PortraitStill.at(date), mode: mode) }
        if peeking {
            pose.bagLift = 0
            pose.eyesDx = -3
        }
        if let walking, daily?.scene == nil, activity == nil { pose.walk(from: walking, time: 0.2) }
        if bath { pose.callToBath(time: 0.5) }
        if let daily { pose.cue(daily, time: 5, slap: nil) }
        return pose
    }
}

/// Shows only `RunnerFigure.headBox` of the figure.
struct HeadCrop<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let bounds = RunnerArt.bounds
        let head = RunnerFigure.headBox
        GeometryReader { geo in
            let scale = geo.size.width / head.width
            content
                .frame(width: bounds.width * scale, height: bounds.height * scale)
                .offset(x: (bounds.minX - head.minX) * scale, y: (bounds.minY - head.minY) * scale)
        }
        .aspectRatio(head.width / head.height, contentMode: .fit)
        .clipped()
    }
}

#Preview("Parts") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
        ForEach(Mode.allCases) { mode in
            CompanionPortrait(mode: mode)
                .padding(8)
                .background(mode.color)
        }
        CompanionPortrait(mode: .boxing, energy: 10)
            .padding(8)
            .background(Mode.boxing.color)
        CompanionPortrait(mode: .work, energy: 85)
            .padding(8)
            .background(Mode.work.color)
        CompanionPortrait(mode: .work, bedtime: .on)
            .padding(8)
            .background(Mode.work.color)
        CompanionPortrait(mode: .chill, need: .boxingWarmup)
            .padding(8)
            .background(Mode.chill.color)
        CompanionPortrait(mode: .chill, need: .boxingWarmup, framing: .head)
            .frame(width: 76)
            .background(Mode.chill.color, in: Circle())
        CompanionPortrait(mode: .work, bedtime: .on, framing: .head)
            .frame(width: 76)
            .background(.black, in: Circle())
        ForEach(IdleLife.allCases, id: \.self) { life in
            RunnerFigure(mode: .chill, pose: RunnerPose(life: life))
                .padding(8)
                .background(Mode.chill.color)
        }
    }
    .padding()
}
