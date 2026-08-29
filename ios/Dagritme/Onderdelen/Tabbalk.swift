// Het zwevende menu, net als op web: op een telefoon over de inhoud heen
// onderaan, op een breed scherm rechts in de kopregel. De kleur klapt om in
// plaats van mee te verschieten — dat doet de webversie ook.
//
// Het oranje vlak eronder klapt niet om maar schuift: het is één vlak dat van
// knop naar knop verhuist (`matchedGeometryEffect`), zodat je ziet waar je
// vandaan komt. Welke kant het scherm op schuift bepaalt `Gezin.gaNaar` uit de
// volgorde van `Tab.allCases`; die knoppen staan hier in dezelfde volgorde.
import SwiftUI

struct Tabbalk: View {
    var breed: Bool

    @Environment(Gezin.self) private var gezin
    @Environment(\.palet) private var palet
    @Namespace private var ruimte

    private struct Knop {
        let tab: Tab
        let naam: String
        let teken: Menuteken.Soort
    }

    private let knoppen: [Knop] = [
        Knop(tab: .ritme, naam: "Ritme", teken: .ritme),
        Knop(tab: .week, naam: "Deze week", teken: .week),
        Knop(tab: .instellingen, naam: "Instellingen", teken: .tandwiel),
    ]

    var body: some View {
        Glas(radius: breed ? 26 : 34, zwevend: true) {
            HStack(spacing: 4) {
                ForEach(knoppen, id: \.tab) { knop in
                    let aan = gezin.tab == knop.tab
                    Button { gezin.gaNaar(knop.tab) } label: {
                        tabinhoud(knop, aan: aan)
                    }
                    .buttonStyle(.druk(0.94))
                    .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(breed ? 4 : 5)
        }
    }

    @ViewBuilder
    private func tabinhoud(_ knop: Knop, aan: Bool) -> some View {
        let kleur = aan ? ORANJE : palet.rustigTab
        let vorm = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Group {
            if breed {
                HStack(spacing: 7) {
                    Menuicoon(soort: knop.teken, kleur: kleur, maat: 19)
                    Text(knop.naam).letter(L.tabbreed)
                }
            } else {
                VStack(spacing: 2) {
                    Menuicoon(soort: knop.teken, kleur: kleur, maat: 23)
                    Text(knop.naam).letter(L.tab)
                }
            }
        }
        .foregroundStyle(kleur)
        // Het icoontje van de knop waar je heen gaat komt even op, zodat de tik
        // zelf al antwoord geeft — nog voor het scherm eronder is omgegaan.
        .scaleEffect(aan ? 1.06 : 1)
        .animation(Beweging.wip, value: aan)
        .frame(maxWidth: .infinity)
        .padding(.vertical, breed ? 8 : 7)
        .background {
            if aan {
                vorm.fill(ORANJE.opacity(0.16))
                    .overlay(vorm.strokeBorder(ORANJE.opacity(0.28), lineWidth: 1))
                    .matchedGeometryEffect(id: "pil", in: ruimte)
            }
        }
        .contentShape(vorm)
    }
}
