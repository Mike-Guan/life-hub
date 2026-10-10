import SwiftUI

// Issue #236: releasing a long press on the character opens the app's "不对" card. Without a handler
// the press keeps its old behavior (HAKU's close-up, KURO's tap reaction), so widgets and previews
// don't change.
/// What a long press on the companion does when it ends.
public struct CompanionHold: Sendable {
    let action: @MainActor () -> Void

    /// Runs `action`, or `fallback` when no handler is set.
    @MainActor
    static func release(_ hold: CompanionHold?, otherwise fallback: () -> Void) {
        if let hold {
            hold.action()
        } else {
            fallback()
        }
    }
}

extension EnvironmentValues {
    /// The handler for a released long press on the companion, or nil for the default reaction.
    @Entry var companionHold: CompanionHold?
}

extension View {
    /// Runs `action` when a long press on a companion view inside this view ends.
    public func onCompanionHold(_ action: @escaping @MainActor () -> Void) -> some View {
        environment(\.companionHold, CompanionHold(action: action))
    }
}
