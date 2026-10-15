import CompanionKit
import SwiftUI

// Preview v3 (Issue #237): a Toy sheet at the bottom over a dim layer, 算了 on the left and the red answer on
// the right. Used in place of the system confirmation dialog, which can't take the Toy style.
/// Asks before something is deleted or a step is skipped. Tapping the dim layer cancels.
struct ToyConfirmSheet: View {
    let question: String
    let warning: String
    /// The left button's title.
    var cancel = "算了"
    /// The right button's title.
    let confirm: String
    // The setup's 用默认 deletes nothing, so it takes the primary pink instead of the red.
    /// The right button's fill and text color.
    var confirmFill = Toy.alert
    var confirmText = Toy.card
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Toy.ink.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(question)
                    .font(Toy.body(17, weight: .heavy))
                Text(warning)
                    .font(Toy.body(13))
                    .foregroundStyle(Toy.muted)
                HStack(spacing: 12) {
                    button(cancel, fill: Toy.card, text: Toy.ink, action: onCancel)
                    button(confirm, fill: confirmFill, text: confirmText, action: onConfirm)
                }
            }
            .foregroundStyle(Toy.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .toyCard(radius: 22, shadow: 5)
            .padding(12)
            // 交付差距 v1 工程 #16: VoiceOver stays inside the sheet, and the two-finger scrub cancels.
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onCancel)
        }
    }

    private func button(_ title: String, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Toy.body(15, weight: .heavy))
                .foregroundStyle(text)
                .frame(maxWidth: .infinity, minHeight: 48)
                .toyCard(fill: fill, radius: 12, shadow: 3)
        }
        .buttonStyle(.plain)
    }
}
