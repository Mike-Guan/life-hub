import CompanionKit
import HubCore
import SwiftUI

struct ModeSwitcher: View {
    let current: Mode?
    var persona = Persona.haku
    /// The user's cards, for names and which modes show; `nil` uses the character's default cards.
    var cards: ModeCards?
    var compact = false
    let onSelect: (Mode) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: compact ? 4 : 2), spacing: 14) {
            ForEach(names.modes) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    label(for: mode)
                }
                .buttonStyle(ToyButtonStyle(fill: mode.color(for: persona), isSelected: mode == current))
                .accessibilityLabel(names.title(for: mode, persona: persona))
                .accessibilityAddTraits(mode == current ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func label(for mode: Mode) -> some View {
        if compact {
            Image(systemName: symbol(for: mode))
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 40)
        } else {
            HStack(spacing: 10) {
                Image(systemName: symbol(for: mode))
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(names.title(for: mode, persona: persona)).font(Toy.body(16, weight: .heavy))
                    Text(names.code(for: mode, persona: persona)).font(Toy.body(11, weight: .bold)).opacity(0.6)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 62)
        }
    }

    private var names: ModeCards { cards ?? .legacy(for: persona) }

    private func symbol(for mode: Mode) -> String {
        names.pickedIdentity(for: mode, persona: persona)?.symbol ?? mode.symbol(for: persona)
    }
}
