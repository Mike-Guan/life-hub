import CompanionKit
import HubCore
import SwiftUI

struct ModeSwitcher: View {
    let current: Mode?
    var persona = Persona.haku
    var compact = false
    let onSelect: (Mode) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: compact ? 4 : 2), spacing: 14) {
            ForEach(Mode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    label(for: mode)
                }
                .buttonStyle(ToyButtonStyle(fill: mode.color, isSelected: mode == current))
                .accessibilityLabel(mode.title(for: persona))
                .accessibilityAddTraits(mode == current ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func label(for mode: Mode) -> some View {
        if compact {
            Image(systemName: mode.symbol)
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 40)
        } else {
            HStack(spacing: 10) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title(for: persona)).font(Toy.body(16, weight: .heavy))
                    Text(mode.code).font(Toy.body(11, weight: .bold)).opacity(0.6)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 62)
        }
    }
}
