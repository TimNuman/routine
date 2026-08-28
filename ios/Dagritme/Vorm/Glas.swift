// Het melkglas uit de webversie: blur erachter, een oplichtend randje, een glans
// langs de boven- en onderkant, en een zachte schaduw eronder. Dat randje en die
// glans zijn wat het glas maakt; zonder die twee is het een grijs vlak.
//
// De kleur komt uit de laag hieronder en niet uit het materiaal. `.ultraThinMaterial`
// brengt namelijk zijn eigen kleur mee — gebruik je dat voor de kleur, dan zijn
// de kaartjes vlakke grijze dozen. Het materiaal doet alleen de blur; de kleur
// komt uit het palet, precies zoals de css het doet.
import SwiftUI

struct Glas<Inhoudje: View>: View {
    var radius: CGFloat = 22
    var zwevend: Bool = false
    @ViewBuilder var inhoud: () -> Inhoudje

    @Environment(\.palet) private var palet

    private var vorm: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }

    var body: some View {
        inhoud()
            .background {
                ZStack {
                    vorm.fill(.ultraThinMaterial)
                    vorm.fill(zwevend ? palet.glasZwevend : palet.glas)
                }
            }
            .clipShape(vorm)
            .overlay {
                // Het randje en de twee glansen in één streep: bovenin licht,
                // onderin een flauwe terugkaats, ertussen de gewone rand.
                vorm.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: palet.glansBoven, location: 0),
                            .init(color: palet.glasRand, location: 0.35),
                            .init(color: palet.glasRand, location: 0.72),
                            .init(color: palet.glansOnder, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: palet.schaduw, radius: 19, x: 0, y: 16)
    }
}
