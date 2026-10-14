import HubCore
import SwiftUI

// Used by scripts/screenshots.sh to draw the first-run setup for UI 审核. Debug builds only.
// The draft is written to the App Group before the view reads it, so each launch opens on one screen.
/// The first-run setup opened on `step`, with no answers given.
struct ScreenshotOnboarding: View {
    @State private var places = PlaceSettings()
    @State private var monitor = PlaceMonitor()

    init(step: OnboardingDraft.Step) {
        var draft = OnboardingDraft()
        draft.step = step
        draft.store(in: AppGroup.defaults)
    }

    var body: some View {
        OnboardingView(places: $places, monitor: monitor, onDone: { _ in })
    }
}
