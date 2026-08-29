// De week als strip bovenaan Deze week: een pijl terug, zeven dagen, een pijl
// verder. Vandaag heeft een ringetje, de gekozen dag een oranje bol.
//
// Een week verder schuift de hele rij dagen opzij — oud naar links, nieuw van
// rechts — terwijl de twee pijlen blijven staan. Dat is wat de beweging
// leesbaar maakt: de knop waar je op drukt beweegt niet mee, alleen datgene wat
// verandert.
//
// De oranje bol is geen aan/uit per dag maar één bol die van dag naar dag
// schuift (`matchedGeometryEffect`). Zijn naam heeft de week erin, want tijdens
// het schuiven staan er even twee stroken naast elkaar en die moeten niet naar
// dezelfde bol wijzen.
import SwiftUI

struct Weekstrip: View {
    let nu: Date
    let verschuiving: Int
    let gekozen: Date
    var richting: CGFloat = 1
    let opKies: (Date) -> Void
    let opSchuif: (Int) -> Void

    @Namespace private var ruimte

    var body: some View {
        let dagen = weekVan(nu, verschuiving)
        let vandaag = datumVan(nu)
        let staat = datumVan(gekozen)

        Glas(radius: 24) {
            HStack(spacing: 0) {
                pijl(-1, "Vorige week")

                ZStack {
                    HStack(spacing: 0) {
                        ForEach(dagen, id: \.self) { d in
                            dag(d, gekozen: datumVan(d) == staat,
                                vandaag: datumVan(d) == vandaag)
                        }
                    }
                    .id(verschuiving)
                    .schuiftMee(richting)
                }
                .frame(maxWidth: .infinity)
                // De stroken die weglopen mogen niet over de pijlen heen
                // schuiven; hierbinnen houdt het op.
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                pijl(1, "Volgende week")
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func dag(_ d: Date, gekozen aan: Bool, vandaag: Bool) -> some View {
        Button { opKies(d) } label: {
            VStack(spacing: 8) {
                Text(DAGLETTERS[DAGEN[dagnummer(d)]] ?? "")
                    .letter(L.wletter)
                    .foregroundStyle(ZACHTINKT)
                ZStack {
                    if aan {
                        Circle()
                            .fill(ORANJE)
                            .matchedGeometryEffect(id: "bol-\(verschuiving)", in: ruimte)
                    }
                    if !aan && vandaag {
                        Circle().strokeBorder(ORANJE.opacity(0.5), lineWidth: 2)
                    }
                    Text("\(kalender.component(.day, from: d))")
                        .letter(L.wdag)
                        .foregroundStyle(aan ? .white : INKT)
                        // De kleur van het cijfer moet omgaan op het moment dat
                        // de bol er is, niet ervoor of erna.
                        .animation(Beweging.snel, value: aan)
                }
                .frame(width: 38, height: 38)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.druk(0.92))
        .accessibilityLabel(datumTekst(d))
        .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
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
        .buttonStyle(.drukje)
        .accessibilityLabel(titel)
    }
}
