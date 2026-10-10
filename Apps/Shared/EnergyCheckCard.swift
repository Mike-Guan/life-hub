import CompanionKit
import HubCore
import SwiftUI

// Issue #236: opened by a long press on the character. One question, two answers, one short reply.
/// The "不对" card under the character: what she thinks today's energy is, and the two answers.
struct EnergyCheckCard: View {
    let guess: EnergyReading
    let persona: Persona
    /// The reply after an answer, or nil while asking.
    let reply: String?
    let onAnswer: (EnergyAnswer) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(reply ?? EnergyCheck.question(for: guess.level, persona: persona))
                    .font(Toy.body(15, weight: .heavy))
                    .foregroundStyle(Toy.ink)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Toy.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关掉")
                .padding(.top, -12)
                .padding(.trailing, -12)
            }
            if reply == nil {
                HStack(spacing: 10) {
                    ForEach(EnergyAnswer.allCases, id: \.self) { answer in
                        Button { onAnswer(answer) } label: {
                            Text(answer.title)
                                .font(Toy.body(15, weight: .heavy))
                                .foregroundStyle(Toy.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .toyCard(radius: 12, shadow: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .toyCard(radius: 14, shadow: 3)
    }
}
