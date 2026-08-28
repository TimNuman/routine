// De emojikiezer: een voorbeeld, de groepen als chips en een raster om uit te
// kiezen. Hij opent op de groep waar het huidige teken in staat.
import SwiftUI

struct Emojikiezer: View {
    let titel: String
    let huidig: String
    let opAf: () -> Void
    let opKlaar: (String) -> Void

    @Environment(\.palet) private var palet
    @State private var waarde: String
    @State private var groep: String

    init(titel: String, huidig: String, opAf: @escaping () -> Void,
         opKlaar: @escaping (String) -> Void) {
        self.titel = titel
        self.huidig = huidig
        self.opAf = opAf
        self.opKlaar = opKlaar
        let teken = huidig.isEmpty ? "⭐" : huidig
        _waarde = State(initialValue: teken)
        _groep = State(initialValue: EMOJIGROEPEN.first { $0.tekens.contains(teken) }?.naam
            ?? EMOJIGROEPEN[0].naam)
    }

    private var tekens: [String] {
        EMOJIGROEPEN.first { $0.naam == groep }?.tekens ?? []
    }

    var body: some View {
        Blad(titel: titel, knop: "Gereed", opAf: opAf, opKnop: { opKlaar(waarde) }) {
            RoundedRectangle(cornerRadius: 39, style: .continuous)
                .fill(palet.tegel)
                .overlay(RoundedRectangle(cornerRadius: 39, style: .continuous)
                    .strokeBorder(palet.tegelRand, lineWidth: 1))
                .overlay(Text(waarde).font(.system(size: 40)))
                .frame(width: 78, height: 78)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EMOJIGROEPEN, id: \.naam) { g in
                        Chip(label: g.naam, aan: g.naam == groep) { groep = g.naam }
                            .fixedSize()
                    }
                }
                .padding(.bottom, 12)
            }

            // Zes op een rij, net als op web.
            let kolommen = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
            LazyVGrid(columns: kolommen, spacing: 8) {
                ForEach(Array(tekens.enumerated()), id: \.offset) { (_, teken) in
                    Button { waarde = teken } label: {
                        Circle()
                            .fill(palet.tegel)
                            .overlay(Circle().strokeBorder(
                                teken == waarde ? ORANJE : palet.tegelRand,
                                lineWidth: teken == waarde ? 2.5 : 1))
                            .overlay(Text(teken).font(.system(size: 25)))
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(teken)
                }
            }
        }
    }
}
