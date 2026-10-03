import CompanionKit
import HubCore
import SwiftUI

/// How far the savings are from the target, with a progress bar.
struct MoneyCard: View {
    /// Yen still missing, 0 once reached.
    let gap: Int
    /// The target in yen.
    let target: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("金库")
                    .font(Toy.body(16, weight: .heavy))
                Spacer()
                Text(gap == 0 ? "目标达成" : "还差 ¥\(gap.formatted())")
                    .font(Toy.display(22))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Toy.card)
                    Capsule()
                        .fill(Mode.money.color)
                        .frame(width: proxy.size.width * progress)
                }
                .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
            }
            .frame(height: 14)
            Text("目标 ¥\(target.formatted())。发薪日在设置里更新银行余额。")
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
        }
        .foregroundStyle(Toy.ink)
        .padding(16)
        .toyCard()
        .accessibilityElement(children: .combine)
    }

    private var progress: Double {
        guard target > 0 else { return 1 }
        return min(max(Double(target - gap) / Double(target), 0), 1)
    }
}
