// De schakelaar tussen ochtend en avond. De pil schuift naar de gekozen kant in
// plaats van te knipperen.
import SwiftUI

struct Segment: View {
    var ritme: Ritme
    var opKies: (Ritme) -> Void
    var marge: CGFloat = 16

    @Environment(\.palet) private var palet

    var body: some View {
        Glas(radius: 19) {
            GeometryReader { ruimte in
                let breedte = ruimte.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palet.donker ? Color.white.opacity(0.92) : .white)
                        .frame(width: breedte / 2, height: 42)
                        .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 3)
                        .offset(x: ritme == .nacht ? breedte / 2 : 0)
                        .animation(Beweging.veer, value: ritme)

                    HStack(spacing: 0) {
                        knop("ochtend", .dag)
                        knop("avond", .nacht)
                    }
                }
            }
            .frame(height: 42)
            .padding(4)
        }
        .padding(.top, marge)
    }

    @ViewBuilder
    private func knop(_ label: String, _ waarde: Ritme) -> some View {
        let aan = ritme == waarde
        Button { opKies(waarde) } label: {
            Text(label)
                .letter(L.knop)
                // De pil is licht, ook 's avonds: wat erop staat blijft donker.
                .foregroundStyle(aan ? INKT : palet.zacht)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
    }
}
