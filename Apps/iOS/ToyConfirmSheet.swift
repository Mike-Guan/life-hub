import CompanionKit
import SwiftUI

// Preview v3 (Issue #237): a Toy sheet at the bottom over a dim layer, 算了 on the left and the red answer on
// the right. Used in place of the system confirmation dialog, which can't take the Toy style.
/// Asks before something is deleted. Tapping the dim layer cancels.
struct ToyConfirmSheet: View {
    let question: String
    let warning: String
    /// The red button's title.
    let confirm: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Toy.ink.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: 12) {
                Text(question)
                    .font(Toy.body(17, weight: .heavy))
                Text(warning)
                    .font(Toy.body(13))
                    .foregroundStyle(Toy.muted)
                HStack(spacing: 12) {
                    button("算了", fill: Toy.card, text: Toy.ink, action: onCancel)
                    button(confirm, fill: Toy.alert, text: Toy.card, action: onConfirm)
                }
            }
            .foregroundStyle(Toy.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .toyCard(radius: 22, shadow: 5)
            .padding(12)
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
