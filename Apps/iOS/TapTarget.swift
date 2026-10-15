import SwiftUI

extension View {
    /// Pads a small button label out to the 44 pt minimum tap area, the whole area tappable.
    func tapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}
