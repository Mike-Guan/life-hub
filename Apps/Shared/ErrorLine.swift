import CompanionKit
import SwiftUI

// Red text on paper is about 3:1 (UI review UI-11), so the text stays ink and only the icon is red.
/// An error message: a red warning icon and the text in ink.
struct ErrorLine: View {
    let text: String
    var size: CGFloat = 12

    var body: some View {
        Label {
            Text(text).foregroundStyle(Toy.ink)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Toy.alert)
        }
        .font(Toy.body(size, weight: .bold))
    }
}
