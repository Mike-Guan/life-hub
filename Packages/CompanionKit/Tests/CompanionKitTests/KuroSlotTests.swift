import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroSlotTests {
    static let activities: [CompanionActivity] = [.boxingAtGym, .gymSession, .running, .gymDay, .runDay]

    /// Every need, activity and moment, one at a time.
    static var inputs: [(CompanionNeed?, CompanionActivity?, CompanionMoment?)] {
        CompanionNeed.allCases.map { ($0, nil, nil) } + activities.map { (nil, $0, nil) }
            + CompanionMoment.allCases.map { (nil, nil, $0) }
    }

    // KURO-01 / KURO-04 (UI 审核 2026-10-08): a need, activity or moment must change her body, not just the bubble.
    @Test(arguments: KuroLook.allCases)
    func everySlotMovesHerBody(_ look: KuroLook) throws {
        let base = KuroPose(look: look, energy: 50)
        let rest = KuroFigure.parts(for: look, pose: base)
        for (need, activity, moment) in Self.inputs {
            if look == .work, moment == .overtime {
                let overtime = KuroView.pose(look, energy: 50, bedtime: .off, moment: moment, overtimeUntil: nil)
                #expect(KuroFigure.parts(for: look, pose: overtime) != rest)
                continue
            }
            let slot = try #require(KuroSlot(need: need, activity: activity, moment: moment, look: look))
            let dressed = slot.dressing(base)
            let (tap, progress) = try #require(slot.move(in: look, at: slot.period * 3 + 0.5))
            let moving = KuroFigure.parts(for: look, pose: dressed.reacting(tap, progress: progress))
            let label = [need?.rawValue, activity?.rawValue, moment?.rawValue].compactMap { $0 }.joined()
            #expect(moving != rest, "\(look) \(label)")
            #expect(slot.move(in: look, at: slot.period * 3 + 2) == nil)
        }
    }

    @Test func slotsFollowWhatIsHappening() {
        #expect(KuroSlot(need: nil, activity: nil, moment: nil, look: .chill) == nil)
        #expect(KuroSlot(need: .sitting, activity: nil, moment: nil, look: .work) == .invite)
        #expect(KuroSlot(need: nil, activity: .running, moment: nil, look: .chill) == .active)
        #expect(KuroSlot(need: nil, activity: .gymDay, moment: nil, look: .chill) == .invite)
        #expect(KuroSlot(need: .sitting, activity: nil, moment: .flow, look: .desk) == .focus)
        #expect(KuroSlot(need: nil, activity: nil, moment: .overtime, look: .work) == nil)
        #expect(KuroSlot(need: nil, activity: nil, moment: .overtime, look: .chill) == .tired)
        #expect(KuroSlot(need: nil, activity: nil, moment: .packingUp, look: .work) == .packingUp)
        #expect(KuroSlot.tired.move(in: .tennis) == .rub && KuroSlot.focus.move(in: .desk) == .glasses)
        #expect(KuroSlot.invite.hops && KuroSlot.active.hops && !KuroSlot.focus.hops && !KuroSlot.tired.hops)
    }

    @Test func lowEnergyKeepsHerLowEyesWhenInvited() {
        let low = KuroPose(look: .chill, energy: 10)
        #expect(KuroSlot.invite.dressing(low).eyes == .low)
        #expect(KuroSlot.invite.dressing(KuroPose(look: .chill, energy: 50)).eyes == .bright)
        #expect(KuroSlot.tired.dressing(low).eyes == .drowsy)
    }

    // KURO-02 (UI 审核 2026-10-08): tapping her while her chin is on her hand did nothing.
    @Test func aTapAtTheDeskTapsHerCheek() {
        let overtime = KuroView.pose(.work, energy: 50, bedtime: .off, moment: .overtime, overtimeUntil: nil)
        let tapped = overtime.reacting(.chinTap, progress: 0.3)
        #expect(tapped.eyes == .open && overtime.eyes == .drowsy)
        #expect(KuroFigure.shift(.overtimeHand, pose: tapped).height < 0)
        let parts = Set(KuroFigure.parts(for: .work, pose: tapped))
        #expect(parts.isSuperset(of: [.overtimeDesk, .overtimeHand, .eyesOpen]))
        #expect(parts.isDisjoint(with: [.workTablet, .tapTablet]))
        #expect(KuroView.hop((.chinTap, 0.1)) == 0)
        #expect(overtime.reacting(.chinTap, progress: 0.9).eyes == .drowsy)
    }
}
