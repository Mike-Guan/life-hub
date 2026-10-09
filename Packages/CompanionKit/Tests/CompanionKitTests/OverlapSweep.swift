#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (Mike 2026-10-09: find every place where parts overlap badly): not for main.
// Dumps every distinct set of visible parts, with the head transform, for an offline overlap check.
extension FrameSheets {
    private struct Sample: Hashable {
        var source: String
        var parts: [String]
        var headDy: Int
        var tilt: Int
    }

    private static func key(_ mode: Mode, _ pose: RunnerPose, _ source: String) -> Sample {
        let parts = RunnerFigure.parts(for: mode, pose: pose).map(\.rawValue)
        let dy = pose.headDy + 30 * pose.slump
        let tilt = -14 * Double(pose.lie) + pose.headTilt
        return Sample(source: source, parts: parts, headDy: Int((dy * 2).rounded()), tilt: Int(tilt.rounded()))
    }

    @Test func overlapSweep() throws {
        var seen: [Sample: Int] = [:]
        func add(_ s: Sample) { seen[s, default: 0] += 1 }
        let times = stride(from: 0.0, to: 40, by: 0.25).map { $0 }
        let progresses = stride(from: 0.0, through: 1, by: 0.02).map { $0 }
        let faces: [EnergyFace] = [.low, .mid, .high]
        var outfits: [Outfit] = [Outfit()]
        for room in [RunnerPart.roomPlant, .roomBag] {
            var o = Outfit()
            o.room = room
            o.peaceSign = true
            o.stripedMask = true
            outfits.append(o)
        }
        let traceSets: [Set<CompanionTrace>] = [[], Set(CompanionTrace.allCases)]
        func each(_ mode: Mode, _ base: RunnerPose, _ source: String) {
            for outfit in outfits {
                for traces in traceSets {
                    add(Self.key(mode, base.wearing(outfit).leaving(traces), source))
                }
            }
        }
        for mode in Mode.allCases {
            for face in faces {
                for t in times {
                    for react in [0.0, 0.6] {
                        each(mode, RunnerPose(mode: mode, time: t, face: face, react: react), "idle")
                        for life in IdleLife.allCases {
                            each(
                                mode, RunnerPose(mode: mode, time: t, face: face, life: life, react: react),
                                "life.\(life)")
                        }
                        for need in CompanionNeed.allCases {
                            each(
                                mode, RunnerPose(mode: mode, time: t, face: face, need: need, react: react),
                                "need.\(need.rawValue)")
                        }
                        for moment in CompanionMoment.allCases {
                            each(
                                mode, RunnerPose(mode: mode, time: t, face: face, moment: moment, react: react),
                                "moment.\(moment.rawValue)")
                        }
                        for activity in [
                            CompanionActivity.boxingAtGym, .gymSession, .running, .gymDay, .runDay,
                        ] {
                            each(
                                mode,
                                RunnerPose(mode: mode, time: t, face: face, activity: activity, react: react),
                                "activity.\(activity.rawValue)")
                        }
                    }
                    for place in HubPlace.Kind.allCases {
                        var pose = RunnerPose(mode: mode, time: t, face: face, react: 0)
                        pose.walk(from: place, time: CGFloat(t))
                        each(mode, pose, "walk.\(place.rawValue)")
                    }
                    for prop in DailyProp.allCases {
                        var pose = RunnerPose(mode: mode, time: t, face: face, react: 0)
                        pose.dailyProp = prop
                        each(mode, pose, "prop.\(prop.rawValue)")
                    }
                }
                for p in progresses {
                    let t = p * 12
                    for liesDown in [false, true] {
                        each(mode, RunnerPose.bedtime(time: t, goodnight: p, liesDown: liesDown), "bedtime.\(liesDown)")
                    }
                    each(mode, RunnerPose.offWork(time: t, progress: p, face: face), "offWork")
                    each(mode, RunnerPose.stayHome(time: t, progress: p, face: face), "stayHome")
                    each(mode, RunnerPose.limber(time: t, progress: p, face: face), "limber")
                    for scene in [WelcomeScene.glance, .sofa, .desk, .quiet] {
                        for open in [nil, CGFloat(0.5), 1] as [CGFloat?] {
                            each(
                                mode,
                                RunnerPose.welcome(scene, time: CGFloat(t), open: open, face: face, mode: mode),
                                "welcome.\(scene)")
                        }
                    }
                    let kinds: [WorkoutSummary.Kind?] = [nil] + WorkoutSummary.Kind.allCases.map { $0 }
                    for kind in kinds {
                        var pose = RunnerPose(mode: mode, time: t, face: face, react: 0)
                        pose.celebrate(kind, progress: CGFloat(p))
                        each(mode, pose, "celebrate.\(kind?.rawValue ?? "none")")
                    }
                    for scene in DailyScene.allCases {
                        var pose = RunnerPose(mode: mode, time: t, face: face, react: 0)
                        pose.propRaise = 1
                        pose.playScene(scene, time: CGFloat(t))
                        each(mode, pose, "scene.\(scene.rawValue)")
                    }
                    var pose = RunnerPose(mode: mode, time: t, face: face, react: 0)
                    pose.unbox(progress: CGFloat(p))
                    each(mode, pose, "unbox")
                    for (name, act) in [
                        ("notice", { (p: inout RunnerPose, x: Double) in p.notice(progress: x) }),
                        ("turnAway", { (p: inout RunnerPose, x: Double) in p.turnAway(progress: x) }),
                        ("dizzy", { (p: inout RunnerPose, x: Double) in p.dizzy(progress: x) }),
                        ("rubEyes", { (p: inout RunnerPose, x: Double) in p.rubEyes(progress: x) }),
                        ("whistle", { (p: inout RunnerPose, x: Double) in p.whistle(progress: x) }),
                        ("stretchUp", { (p: inout RunnerPose, x: Double) in p.stretchUp(progress: x) }),
                        ("cheerFocus", { (p: inout RunnerPose, x: Double) in p.cheerFocus(progress: x) }),
                        ("packUp", { (p: inout RunnerPose, x: Double) in p.packUp(elapsed: x * 8) }),
                    ] {
                        var pose = RunnerPose(mode: mode, time: t, face: face, react: 0)
                        act(&pose, p)
                        each(mode, pose, name)
                    }
                }
                for still in PortraitStill.allCases {
                    var pose = RunnerPose(face: face)
                    pose.show(still, mode: mode)
                    each(mode, pose, "still.\(still)")
                }
            }
        }
        var lines = seen.keys.map { s in
            "{\"who\":\"haku\",\"source\":\"\(s.source)\",\"headDy\":\(Double(s.headDy) / 2),\"tilt\":\(s.tilt),"
                + "\"parts\":[\(s.parts.map { "\"\($0)\"" }.joined(separator: ","))]}"
        }

        // KURO: every look, energy, bedtime, items, tap and idle move, with each part's shift.
        var kuro: Set<String> = []
        func addKuro(_ look: KuroLook, _ pose: KuroPose, _ source: String) {
            let parts = KuroFigure.parts(for: look, pose: pose)
            let shifts = parts.map { part -> String in
                let s = KuroFigure.shift(part, pose: pose)
                return "\"\(part.rawValue)\":[\(Int(s.width.rounded())),\(Int(s.height.rounded()))]"
            }
            kuro.insert("{\"who\":\"kuro\",\"source\":\"\(source)\",\"shift\":{\(shifts.joined(separator: ","))}}")
        }
        for look in KuroLook.allCases {
            for energy in [20.0, 50, 85] {
                for bedtime in [Bedtime.off, .on] {
                    for items in [Set<KuroItem>(), Set(KuroItem.allCases)] {
                        for overtime in [false, true] {
                            var base = KuroPose(look: look, energy: energy, bedtime: bedtime)
                            base.items = items
                            base.overtime = overtime
                            base.sign = overtime ? "20:30" : nil
                            addKuro(look, base, "rest")
                            for p in progresses {
                                for tap in [KuroTap.tablet, .sip, .bounce, .glasses, .rub, .turnAway, .chinTap] {
                                    addKuro(look, base.reacting(tap, progress: p, heart: true), "tap.\(tap)")
                                }
                                for idle in KuroIdle.allCases {
                                    addKuro(look, base.idling((idle, p)), "idle.\(idle)")
                                }
                            }
                        }
                    }
                }
            }
        }
        lines += kuro
        guard let folder = ProcessInfo.processInfo.environment["FRAME_SHEETS"] else { return }
        try lines.sorted().joined(separator: "\n").write(
            toFile: folder + "/overlap-sweep.jsonl", atomically: true, encoding: .utf8)
    }
}
#endif
