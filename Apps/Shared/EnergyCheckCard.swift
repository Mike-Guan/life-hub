import CompanionKit
import HubCore
import SwiftUI

// Issue #236, UI preview v5 (纠正预览, UI 审核 passed 2026-10-08): the card slides up in 0.2 s and then
// stays still so the words are easy to read. Tapping outside or dragging it down closes it without a record.
/// The "不对" card: what the character thinks today's energy is, and the two answers.
struct EnergyCheckCard: View {
    let guess: EnergyReading
    let persona: Persona
    /// An error from recording the answer, shown in place of the question.
    let error: String?
    /// The least height, so the card can reach past the bottom of the screen.
    var fill: CGFloat = 0
    let onAnswer: (EnergyAnswer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(error ?? EnergyCheck.question(for: guess.level, persona: persona))
                .font(Toy.body(16, weight: .heavy))
                .foregroundStyle(Toy.ink)
            HStack(spacing: 12) {
                ForEach(EnergyAnswer.allCases, id: \.self) { answer in
                    Button {
                        onAnswer(answer)
                    } label: {
                        Text(answer.title)
                            .font(Toy.body(16, weight: .heavy))
                            .foregroundStyle(Toy.ink)
                            .frame(maxWidth: 160, minHeight: 48)
                            .toyCard(radius: 12, shadow: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: 560, minHeight: fill, alignment: .top)
        .toyCard(radius: 18, shadow: 4)
    }
}
