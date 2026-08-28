// De week als strip bovenaan Deze week: een pijl terug, zeven dagen, een pijl
// verder. Vandaag heeft een ringetje, de gekozen dag een oranje bol.
import SwiftUI

struct Weekstrip: View {
    let nu: Date
    let verschuiving: Int
    let gekozen: Date
    let opKies: (Date) -> Void
    let opSchuif: (Int) -> Void

    var body: some View {
        let dagen = weekVan(nu, verschuiving)
        let vandaag = datumVan(nu)
        let staat = datumVan(gekozen)

        Glas(radius: 24) {
            HStack(spacing: 0) {
                pijl(-1, "Vorige week")
                ForEach(dagen, id: \.self) { d in
                    let sleutel = datumVan(d)
                    let aan = sleutel == staat
                    Button { opKies(d) } label: {
                        VStack(spacing: 8) {
                            Text(DAGLETTERS[DAGEN[dagnummer(d)]] ?? "")
                                .letter(L.wletter)
                                .foregroundStyle(ZACHTINKT)
                            ZStack {
                                Circle().fill(aan ? ORANJE : .clear)
                                if !aan && sleutel == vandaag {
                                    Circle().strokeBorder(ORANJE.opacity(0.5), lineWidth: 2)
                                }
                                Text("\(kalender.component(.day, from: d))")
                                    .letter(L.wdag)
                                    .foregroundStyle(aan ? .white : INKT)
                            }
                            .frame(width: 38, height: 38)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(datumTekst(d))
                    .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
                }
                pijl(1, "Volgende week")
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func pijl(_ richting: Int, _ titel: String) -> some View {
        Button { opSchuif(richting) } label: {
            Pijltje()
                .scaleEffect(x: richting < 0 ? -1 : 1, y: 1)
                .opacity(0.65)
                .frame(width: 26)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titel)
    }
}
