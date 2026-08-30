// Hier bewerk je alles wat in de app staat. Elke regel opent een vel dat het
// hele scherm vult.
import SwiftUI

struct Instellingenscherm: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.palet) private var palet
    @Environment(\.maten) private var m
    @Environment(\.tabstand) private var tabstand

    @State private var vel: Velsoort?

    var body: some View {
        Scherm(titel: "Instellingen", onder: gezin.inhoud?.titel ?? "", smal: true) {
            if let inhoud = gezin.inhoud {
                // De regels doen één voor één mee aan de tabwissel: de kaart
                // reist met de eerste regel, de rest schuift binnen het glas —
                // dat knipt ze af, net als bij de agenda op het ritmescherm.
                Lijst {
                    Lijstrij(icoon: "🧒", titel: "Kinderen",
                             uitleg: inhoud.mensen.isEmpty
                                ? "nog niemand"
                                : inhoud.mensen.map { $0.naam }.joined(separator: ", "),
                             eerste: true,
                             gezichten: inhoud.mensen) { vel = .kinderen }
                    Lijstrij(icoon: "☀️", titel: "Ochtendritme",
                             uitleg: "\(aantalStappen(inhoud.dag)) stappen") { vel = .dag }
                        .wisselplek(tabplek(2))
                    Lijstrij(icoon: "🌙", titel: "Avondritme",
                             uitleg: "\(aantalStappen(inhoud.nacht)) stappen") { vel = .nacht }
                        .wisselplek(tabplek(3))
                    Lijstrij(icoon: "📅", titel: "Weekritme",
                             uitleg: "school, sport en wat er verder is") { vel = .overzicht }
                        .wisselplek(tabplek(4))
                    Lijstrij(icoon: "📌", titel: "Eenmalig",
                             uitleg: eenmaligTekst(inhoud)) { vel = .eenmalig }
                        .wisselplek(tabplek(5))
                    Lijstrij(icoon: "⚙️", titel: "Naam", uitleg: inhoud.titel) {
                        vel = .algemeen
                    }
                    .wisselplek(tabplek(6))
                }
                .wisselplek(tabplek(1))
            }

            Text("testversie")
                .letter(L.voetnoot)
                .foregroundStyle(palet.zacht)
                .opacity(0.75)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .wisselplek(tabplek(7))
        }
        .fullScreenCover(item: $vel) { soort in
            if let inhoud = gezin.inhoud {
                Velscherm(
                    soort: soort,
                    inhoud: inhoud,
                    opAf: { vel = nil },
                    opBewaar: { await gezin.bewaar($0) }
                )
            }
        }
    }

    private func tabplek(_ plek: Int) -> Wissel {
        Wissel(plek: plek, stand: tabstand, uitwijk: m.breedte + 60)
    }

    private func eenmaligTekst(_ inhoud: Inhoud) -> String {
        let aantal = eenmaligeDingen(inhoud).count
        if aantal == 0 { return "niets op een datum" }
        if aantal == 1 { return "één ding op een datum" }
        return "\(aantal) dingen op een datum"
    }
}
