import CompanionKit
import SwiftUI

/// The can count in a pill, with the can icon.
struct CanChip: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            CanIcon()
                .frame(width: 18, height: 22)
            Text("\(count)")
                .font(Toy.body(17, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(Toy.ink)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Capsule().fill(Toy.card))
        .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
        .background(Capsule().fill(Toy.ink).offset(x: 3, y: 3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) 个能量罐")
    }
}
