import ActivityKit
import Foundation
import HubCore
import UIKit

// A Live Activity can only start while the app is on screen (there is no push server), so the
// countdown appears when Mike opens the app or taps the invite on Sunday morning.
/// Starts and ends the Sunday boxing countdown.
@MainActor
enum BoxingCountdown {
    /// Starts the countdown for `reading` when it is boxing warm-up before class, and ends it otherwise.
    /// - Returns: an error message for the UI, or `nil`.
    static func update(for reading: NeedReading?, now: Date = .now) async -> String? {
        let running = Activity<BoxingActivityAttributes>.activities
        // KURO's tennis day has no class time to count down to.
        let haku = Persona.stored(in: AppGroup.defaults) == .haku
        guard haku, let start = NeedEngine.boxingCountdown(to: reading, now: now) else {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return nil
        }
        let canStart = UIApplication.shared.applicationState == .active
        guard running.isEmpty, canStart, ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let state = BoxingActivityAttributes.ContentState(start: start)
        let content = ActivityContent(state: state, staleDate: start)
        do {
            _ = try Activity.request(attributes: BoxingActivityAttributes(), content: content)
            return nil
        } catch {
            return "拳击倒计时没能显示：\(error.localizedDescription)"
        }
    }
}
