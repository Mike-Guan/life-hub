import Foundation
import HubCore

@testable import CompanionKit

// 03 Product/companion/位置规划图 v0.md §4 step 3, first cut: each state axis on its own, times every
// wardrobe combination and the traces on or off. Not the full product of all axes.
/// Poses that cover what HAKU and KURO can show, each with a label for failure messages.
enum PlacementPoses {
    /// One HAKU state: its label, mode and pose.
    struct Haku {
        var label: String
        var mode: Mode
        var pose: RunnerPose
    }

    /// One KURO state: its label, look and pose.
    struct Kuro {
        var label: String
        var look: KuroLook
        var pose: KuroPose
    }

    static let faces: [EnergyFace] = [.low, .mid, .high]

    /// Every wardrobe look HAKU can wear, with a label.
    static var outfits: [(String, Outfit)] {
        var outfits: [(String, Outfit)] = []
        for room: RunnerPart? in [nil, .roomPlant, .roomBag, .roomCactus, .roomSpeaker] {
            for mask: MaskPrint? in [nil, .stripes, .dots, .bolt] {
                for peace in [false, true] {
                    var outfit = Outfit()
                    outfit.room = room
                    outfit.mask = mask
                    outfit.peaceSign = peace
                    let label = [room?.rawValue, mask.map { "\($0)" }, peace ? "peace" : nil]
                        .compactMap(\.self).joined(separator: "+")
                    outfits.append((label.isEmpty ? "plain" : label, outfit))
                }
            }
        }
        // The clothes with extra parts (hood, charm, cap, cassette, strings), then the plain tops.
        let sets: [(String, [Mode: String])] = [
            (
                "sets",
                [.work: "haku.set.work.raincoat", .chill: "haku.set.chill.varsity", .money: "haku.top.side.arcade"]
            ),
            ("tops", [.work: "haku.top.work.blazer", .chill: "haku.top.chill.flame", .money: "haku.top.side.sukajan"]),
        ]
        for (label, clothes) in sets {
            outfits.append((label, Outfit(Wardrobe(clothes: clothes))))
        }
        return outfits
    }

    /// Today's and lasting traces: none, or all of them.
    static let traceSets: [(String, Set<CompanionTrace>)] = [("", []), ("traces", Set(CompanionTrace.allCases))]

    /// The states of one HAKU axis at a time, before the wardrobe and traces.
    static func hakuStates(face: EnergyFace) -> [(String, RunnerPose)] {
        var states: [(String, RunnerPose)] = [("still", RunnerPose(face: face))]
        for need in CompanionNeed.allCases {
            states.append(("need.\(need.rawValue)", RunnerPose(face: face, need: need)))
        }
        for life in IdleLife.allCases { states.append(("life.\(life)", RunnerPose(face: face, life: life))) }
        let activities: [CompanionActivity] = [.gymDay, .gymSession, .running, .boxingAtGym, .runDay]
        for activity in activities {
            states.append(("activity.\(activity.rawValue)", RunnerPose(face: face, activity: activity)))
        }
        for moment in CompanionMoment.allCases {
            states.append(("moment.\(moment.rawValue)", RunnerPose(face: face, moment: moment)))
        }
        for kind in WorkoutSummary.Kind.allCases {
            var pose = RunnerPose(face: face)
            pose.burst = 0.5
            pose.cheerKind = kind
            states.append(("cheer.\(kind.rawValue)", pose))
        }
        for prop in DailyProp.allCases {
            var pose = RunnerPose(face: face)
            pose.dailyProp = prop
            pose.propRaise = 1
            states.append(("daily.\(prop.rawValue)", pose))
            pose.watchTap = true
            states.append(("daily.\(prop.rawValue).watchTap", pose))
        }
        for scene in DailyScene.allCases {
            var pose = RunnerPose(face: face)
            pose.dailyProp = .note
            pose.dailyScene = scene
            pose.propRaise = 1
            states.append(("scene.\(scene.rawValue)", pose))
        }
        for place in HubPlace.Kind.presets {
            var pose = RunnerPose(face: face)
            pose.walkFrom = place
            states.append(("walk.\(place.rawValue)", pose))
        }
        for leg in [CommutePhase.Leg.toWork, .home] {
            var pose = RunnerPose(face: face)
            pose.commuteLeg = leg
            pose.yawn = 0.5
            states.append(("commute.\(leg.rawValue)", pose))
        }
        for poke in WatchPoke.allCases {
            var pose = RunnerPose(face: face)
            pose.pokeKind = poke
            pose.pokeProgress = 0.5
            states.append(("poke.\(poke)", pose))
        }
        for liesDown in [false, true] {
            states.append(
                ("bedtime.\(liesDown ? "lying" : "sitting")", .bedtime(time: 0, goodnight: 1, liesDown: liesDown)))
        }
        states.append(("bedtime.still", .bedtimeStill()))
        for progress in [0.0, 0.3, 0.6, 1.0] {
            states.append(("offWork.\(progress)", .offWork(time: 0, progress: progress, face: face)))
            states.append(("stayHome.\(progress)", .stayHome(time: 0, progress: progress, face: face)))
        }
        for revive: CGFloat in [0, RunnerPose.reviveWake, RunnerPose.revivePhoneGone, RunnerPose.reviveSofaGone] {
            var pose = RunnerPose(face: face)
            pose.revive = revive
            states.append(("revive.\(revive)", pose))
        }
        let single: [(String, (inout RunnerPose) -> Void)] = [
            ("bathCall", { $0.bathCall = 0 }),
            ("bathDry", { $0.bathDry = 0 }),
            ("rubEye", { $0.rubEye = 0.5 }),
            ("hum", { $0.hum = 0.5 }),
            (
                "scratch",
                {
                    $0.scratch = 0.5
                    $0.tuft = 1
                }
            ),
            (
                "thump",
                {
                    $0.thump = 1
                    $0.thumpHit = true
                }
            ),
            ("fistPump", { $0.fistPump = 1 }),
            ("eyesShut", { $0.eyesShut = true }),
            ("dizzy", { $0.dizziness = 0.5 }),
            ("emptyCan", { $0.emptyCan = true }),
            ("phoneGlance", { $0.phoneGlance = true }),
            ("noteSlap", { $0.noteSlap = 0.5 }),
            ("turnedAway", { $0.turnedAway = true }),
            ("bagLift", { $0.bagLift = 1 }),
        ]
        for moment in [CompanionMoment.vibeCoding, .flow, .lateCoding] {
            for cans in 1...3 {
                var pose = RunnerPose(face: face, moment: moment)
                pose.codingCans = cans
                states.append(("moment.\(moment.rawValue).cans\(cans)", pose))
            }
        }
        for scene in [WelcomeScene.glance, .sofa, .desk, .quiet] {
            for awake in [false, true] {
                for flip: CGFloat in [0, 1] {
                    var pose = RunnerPose(face: face)
                    pose.welcome = RunnerPose.Welcome(
                        scene: scene, atDesk: scene == .desk, time: 0, awake: awake, phoneFlip: flip)
                    states.append(("welcome.\(scene).\(awake ? "awake" : "asleep").\(flip)", pose))
                }
            }
        }
        for (label, change) in single {
            var pose = RunnerPose(face: face)
            change(&pose)
            states.append((label, pose))
        }
        return states
    }

    /// Every HAKU state in every mode, wardrobe look and trace set.
    static var haku: [Haku] {
        var all: [Haku] = []
        for mode in Mode.allCases {
            for face in faces {
                for (state, pose) in hakuStates(face: face) {
                    for (outfitLabel, outfit) in outfits {
                        for (traceLabel, traces) in traceSets {
                            let label = [mode.rawValue, "\(face)", state, outfitLabel, traceLabel]
                                .filter { !$0.isEmpty }.joined(separator: " ")
                            all.append(Haku(label: label, mode: mode, pose: pose.wearing(outfit).leaving(traces)))
                        }
                    }
                }
            }
        }
        // The identity card slot in each card look.
        for card in IdentityKind.allCases where RunnerCardLook(card: card) != nil {
            for face in faces {
                for (state, pose) in hakuStates(face: face) {
                    for (outfitLabel, outfit) in outfits {
                        for (traceLabel, traces) in traceSets {
                            let label = ["card.\(card.rawValue)", "\(face)", state, outfitLabel, traceLabel]
                                .filter { !$0.isEmpty }.joined(separator: " ")
                            let dressed = pose.dressed(for: card, in: .boxing).wearing(outfit).leaving(traces)
                            all.append(Haku(label: label, mode: .boxing, pose: dressed))
                        }
                    }
                }
            }
            // The look's own idle and its base outfit's moves, every 0.1 s.
            guard let look = RunnerCardLook(card: card) else { continue }
            let idles: [RunnerBaseIdle?] = [nil] + RunnerBaseIdle.pool(look)
            for idle in idles {
                guard let length = idle.map({ Double($0.length) }) ?? look.beatLength else { continue }
                for step in 0..<Int(length * 10) {
                    var pose = RunnerPose(face: .mid).dressed(for: card, in: .boxing)
                    pose.cardBeat = CGFloat(step) / 10
                    pose.baseIdle = idle
                    let name = idle.map { "\($0)" } ?? "beat"
                    all.append(Haku(label: "card.\(card.rawValue) \(name) \(pose.cardBeat)", mode: .boxing, pose: pose))
                }
            }
        }
        return all
    }

    // Taps and idle moves as the app picks them: each look's own tap and idle pool, the sleepy rub, turning
    // away, and the chin tap only at the overtime desk.
    /// Every KURO look with its taps, idle moves, overtime and bedtime, wearing nothing or all her items.
    static var kuro: [Kuro] {
        var all: [Kuro] = []
        let itemSets: [(String, Set<KuroItem>)] = [("plain", []), ("items", Set(KuroItem.allCases))]
        for look in KuroLook.allCases {
            for energy: Double? in [10, 50, 90] {
                for bedtime in [Bedtime.off, .on] {
                    let base = KuroPose(look: look, energy: energy, bedtime: bedtime)
                    var states: [(String, KuroPose)] = [("still", base)]
                    for tap in [KuroTap(look: look, sleepy: false), .rub, .turnAway] {
                        for progress in [0.25, 0.5, 0.75] {
                            var pose = base
                            pose.tap = tap
                            pose.tapProgress = progress
                            states.append(("tap.\(tap).\(progress)", pose))
                        }
                    }
                    // Cards without a look of their own add their base moves to the tennis look.
                    let pools = [KuroIdle.pool(look)] + IdentityKind.allCases.map { KuroIdle.pool(look, card: $0) }
                    for idle in KuroIdle.allCases where pools.contains(where: { $0.contains(idle) }) {
                        for progress in [0.25, 0.5, 0.75] {
                            var pose = base
                            pose.idle = idle
                            pose.idleProgress = progress
                            states.append(("idle.\(idle).\(progress)", pose))
                        }
                    }
                    var overtime = base
                    overtime.overtime = true
                    overtime.sign = "19:30"
                    states.append(("overtime", overtime))
                    overtime.tap = .chinTap
                    overtime.tapProgress = 0.5
                    states.append(("overtime.chinTap", overtime))
                    var heart = base
                    heart.heart = true
                    states.append(("heart", heart))
                    var nap = base
                    nap.napping = true
                    states.append(("nap", nap))
                    for (state, pose) in states {
                        for (itemLabel, items) in itemSets {
                            var worn = pose
                            worn.items = items
                            let label = "\(look.rawValue) \(Int(energy ?? 0)) \(bedtime.rawValue) \(state) \(itemLabel)"
                            all.append(Kuro(label: label, look: look, pose: worn))
                        }
                    }
                }
            }
        }
        return all
    }
}
