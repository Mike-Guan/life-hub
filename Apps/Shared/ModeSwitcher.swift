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

    // UI 审核 on #280: without an identity card there are 3 modes, so the last button takes the whole row.
    var body: some View {
        if compact {
            HStack(spacing: 14) {
                ForEach(names.modes) { button(for: $0) }
            }
        } else {
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        ForEach(row) { mode in
                            button(for: mode).gridCellColumns(row.count == 1 ? 2 : 1)
                        }
                    }
                }
            }
        }
    }

    /// The modes two to a row.
    private var rows: [[Mode]] {
        let modes = names.modes
        return stride(from: 0, to: modes.count, by: 2).map { Array(modes[$0..<min($0 + 2, modes.count)]) }
    }

    private func button(for mode: Mode) -> some View {
        Button {
            onSelect(mode)
        } label: {
            label(for: mode)
        }
        .buttonStyle(ToyButtonStyle(fill: mode.color(for: persona), isSelected: mode == current))
        .accessibilityLabel(names.title(for: mode, persona: persona))
        .accessibilityAddTraits(mode == current ? .isSelected : [])
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
