import Foundation
import HubCore

// KURO-04 (UI 审核 2026-10-08): these events played nothing for her. HAKU has her own animation for each;
// KURO answers with her look's tap move until hers are drawn (新角色清单).
/// A one-off event KURO answers with her look's tap move, once per id.
struct KuroOneOff: Equatable, Sendable {
    enum Kind: CaseIterable, Sendable {
        case stayHome, stretched, revived, taskDone, welcomeBack
    }

    let kind: Kind
    let id: String

    /// Seconds after a welcome back event before the app is told she is done.
    static let welcomeLength: TimeInterval = 2.4

    /// The one-off `event` brings, or nil for none or an event with its own handling.
    init?(_ event: CompanionEvent?) {
        switch event {
        case .stayHome(let id): self.init(kind: .stayHome, id: id)
        case .stretched(let id): self.init(kind: .stretched, id: id)
        case .revived(let id): self.init(kind: .revived, id: id)
        case .taskDone(let id, _): self.init(kind: .taskDone, id: id)
        case .welcomeBack(let id, _): self.init(kind: .welcomeBack, id: id)
        default: return nil
        }
    }

    init(kind: Kind, id: String) {
        self.kind = kind
        self.id = id
    }

    /// Whether the heart bubble shows: for things Mike did, a planned task done or getting up again.
    var heart: Bool { kind == .taskDone || kind == .revived }
}
