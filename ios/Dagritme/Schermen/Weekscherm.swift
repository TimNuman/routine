// De week van maandag tot en met zondag: bovenin kies je een dag, daaronder
// staat wat er die dag speelt. Hier voeg je ook iets bijzonders toe, en hier
// plak je een mail of appje.
import SwiftUI

struct Weekscherm: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.palet) private var palet

    @State private var verschuiving = 0
    @State private var gekozenDag: String?
    @State private var blad: Bladstand?
    @State private var bezig = false
    @State private var assistent = false
    // Vanaf deze pagina bewerk je buiten het bewerkscherm om, dus gaat de hele
    // inhoud in één keer terug het huis in.
    @State private var werk: Ruw?

    // De gekozen dag, of anders vandaag zolang die in beeld is; in een andere
    // week de maandag.
    private var gekozen: Date {
        let week = weekVan(gezin.nu, verschuiving)
        if let gekozenDag, let staat = week.first(where: { datumVan($0) == gekozenDag }) {
            return staat
        }
        return week.first { datumVan($0) == datumVan(gezin.nu) } ?? week[0]
    }

    // Alleen de gekozen dag; morgen is hier één tik verder in de strip.
    private var blokken: [Blok] {
        guard let inhoud = gezin.inhoud else { return [] }
        let items = itemsVan(inhoud, gekozen)
        let vandaag = datumVan(gekozen) == datumVan(gezin.nu)
        return [
            Blok(kop: "Overdag", items: items.filter { !isAvond($0, inhoud.avondVanaf) }),
            Blok(kop: vandaag ? "Vanavond" : "'s Avonds",
                 items: items.filter { isAvond($0, inhoud.avondVanaf) }),
        ].filter { !$0.items.isEmpty }
    }

    var body: some View {
        ZStack {
            Scherm(titel: "Deze week", onder: datumTekst(gekozen), smal: true) {
                Weekstrip(
                    nu: gezin.nu,
                    verschuiving: verschuiving,
                    gekozen: gekozen,
                    opKies: { gekozenDag = datumVan($0) },
                    opSchuif: schuif
                )

                if let inhoud = gezin.inhoud {
                    if blokken.isEmpty {
                        Blokkop("Niks bijzonders")
                        Glas(radius: 26) {
                            Text("Deze dag staat er niets in de agenda.")
                                .letter(L.leeg)
                                .foregroundStyle(palet.zacht)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                                .padding(.horizontal, 20)
                        }
                    }

                    ForEach(blokken) { blok in
                        Agenda(blok: blok, mensen: inhoud.mensen, opOpen: { openDing($0) })
                    }

                    Kaartknop("Iets bijzonders toevoegen", plus: true) { openDing(nil) }
                    Kaartknop("Typ of plak iets", teken: "✨") { assistent = true }
                }
            }

            if assistent, let inhoud = gezin.inhoud {
                Assistentblad(
                    inhoud: inhoud,
                    opAf: { assistent = false },
                    opBewaar: { await gezin.bewaar($0) }
                )
            }

            if let stand = blad, let inhoud = gezin.inhoud {
                Dingblad(
                    titel: stand.titel,
                    ding: stand.ding,
                    plek: stand.plek,
                    bron: { werk! },
                    mensen: inhoud.mensen,
                    bezig: bezig,
                    opAf: { blad = nil },
                    opBewaar: { _ in bewaarBlad() },
                    opWeg: stand.plek == nil ? nil : haalWeg
                )
            }
        }
    }

    // Een week verder of terug, op dezelfde weekdag als waar je stond.
    private func schuif(_ weken: Int) {
        let nieuw = kalender.date(byAdding: .day, value: weken * 7, to: gekozen) ?? gekozen
        verschuiving += weken
        gekozenDag = datumVan(nieuw)
    }

    private func openDing(_ item: Agendaitem?) {
        guard let inhoud = gezin.inhoud else { return }
        let ruw = alsRuw(inhoud)
        werk = ruw
        var plek: Plek?
        if let id = item?.id, let bij = ruw.events.first(where: { $0.id == id }) {
            plek = .event(bij)
        }
        var ding = dingVan(ruw, plek)
        if plek == nil {
            ding.icoon = "🎉"
            ding.wekelijks = false
            ding.taak = false
            ding.datum = datumVan(gekozen)
        }
        let naam = item?.tekst ?? ""
        blad = Bladstand(titel: naam.isEmpty ? "Iets eenmaligs" : naam, plek: plek, ding: ding)
    }

    private func bewaarBlad() {
        guard let ruw = werk else { return }
        bezig = true
        Task {
            let fout = await gezin.bewaar(ruw)
            bezig = false
            if fout == nil { blad = nil }
        }
    }

    private func haalWeg() {
        guard let ruw = werk, let plek = blad?.plek, case let .event(item) = plek else { return }
        ruw.events.removeAll { $0.id == item.id }
        bezig = true
        Task {
            let fout = await gezin.bewaar(ruw)
            bezig = false
            if fout == nil { blad = nil }
        }
    }
}
