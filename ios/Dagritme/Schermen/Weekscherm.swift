// De week van maandag tot en met zondag: bovenin kies je een dag, daaronder
// staat wat er die dag speelt. Hier voeg je ook iets bijzonders toe, en hier
// plak je een mail of appje.
import SwiftUI

struct Weekscherm: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.palet) private var palet

    @State private var verschuiving = 0
    @State private var gekozenDag: String?
    // Welke kant het op ging bij de laatste sprong: 1 vooruit, -1 terug.
    @State private var richting: CGFloat = 1
    @State private var blad: Bladstand?
    @State private var bezig = false
    @State private var assistent = false
    // Vanaf deze pagina bewerk je buiten het bewerkscherm om, dus gaat de hele
    // inhoud in één keer terug het huis in.
    @State private var werk: Ruw?

    // Hoe ver je van deze week af zit, als woord. 'Over 3 weken' zegt meer dan
    // een datum die je zelf moet natellen.
    private var weektitel: String {
        switch verschuiving {
        case 0: return "Deze week"
        case 1: return "Volgende week"
        case -1: return "Vorige week"
        case let n where n > 1: return "Over \(n) weken"
        default: return "\(-verschuiving) weken terug"
        }
    }

    // Sta je al op vandaag, dan heeft de knop niets te doen en hoort hij er niet.
    private var opVandaag: Bool {
        verschuiving == 0 && datumVan(gekozen) == datumVan(gezin.nu)
    }

    private func naarVandaag() {
        richting = gekozen > gezin.nu ? -1 : 1
        Trilling.keuze()
        withAnimation(Beweging.schuif) {
            verschuiving = 0
            gekozenDag = nil
        }
    }

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
        // Op tijd, met wat geen tijd heeft bovenaan. Niets valt hier weg: je
        // bladert door een dag en wil hem heel zien, ook het stuk dat geweest is.
        return [
            Blok(kop: "Overdag",
                 items: opTijd(items.filter { !isAvond($0, AVONDVANAF) }, voorbij: nil)),
            Blok(kop: vandaag ? "Vanavond" : "'s Avonds",
                 items: opTijd(items.filter { isAvond($0, AVONDVANAF) }, voorbij: nil)),
        ].filter { !$0.items.isEmpty }
    }

    var body: some View {
        ZStack {
            Scherm(titel: weektitel, onder: datumTekst(gekozen),
                   naast: opVandaag ? nil : AnyView(Vandaagknop(opTik: naarVandaag)),
                   smal: true) {
                Weekstrip(
                    nu: gezin.nu,
                    verschuiving: verschuiving,
                    gekozen: gekozen,
                    richting: richting,
                    opKies: kiesDag,
                    opSchuif: schuif
                )

                if let inhoud = gezin.inhoud {
                    // Alles wat bij de gekozen dag hoort is één ding. Een andere
                    // dag betekent een nieuwe `.id`, en dus schuift het oude weg
                    // en komt het nieuwe binnen — regel voor regel, van boven
                    // naar beneden. De ZStack laat oud en nieuw elkaar even
                    // overlappen; in een VStack zouden ze onder elkaar komen.
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            dagInhoud(inhoud)
                        }
                        .id(datumVan(gekozen))
                        .schuiftMee(richting)
                    }

                    // Deze twee horen bij het scherm en niet bij de dag, dus die
                    // blijven staan waar ze staan.
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
        .onChange(of: blad != nil || assistent) { _, open in
            gezin.bladOpen = open
        }
        .onDisappear { gezin.bladOpen = false }
    }

    // Wat er op de gekozen dag speelt. De regels tellen door over de blokken
    // heen, zodat het golfje van boven naar beneden loopt.
    @ViewBuilder
    private func dagInhoud(_ inhoud: Inhoud) -> some View {
        if blokken.isEmpty {
            Blokkop("Niks bijzonders")
                .komtBinnen(0, vanaf: richting)
            Glas(radius: 26) {
                Text("Deze dag staat er niets in de agenda.")
                    .letter(L.leeg)
                    .foregroundStyle(palet.zacht)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
            }
            .komtBinnen(1, vanaf: richting)
        }

        ForEach(Array(blokken.enumerated()), id: \.element.id) { (i, blok) in
            Agenda(blok: blok, mensen: inhoud.mensen,
                   vanaf: voorloop(i), richting: richting,
                   opOpen: { openDing($0) })
        }
    }

    // Hoeveel regels er vóór blok `i` staan: elk blok is een kopje plus zijn rijen.
    private func voorloop(_ i: Int) -> Int {
        blokken.prefix(i).reduce(0) { $0 + 1 + $1.items.count }
    }

    // Een andere dag in dezelfde week: het blok eronder schuift dezelfde kant op
    // als waar je heen gaat in de tijd.
    private func kiesDag(_ d: Date) {
        guard datumVan(d) != datumVan(gekozen) else { return }
        richting = d > gekozen ? 1 : -1
        Trilling.keuze()
        withAnimation(Beweging.schuif) { gekozenDag = datumVan(d) }
    }

    // Een week verder of terug, op dezelfde weekdag als waar je stond.
    private func schuif(_ weken: Int) {
        let nieuw = kalender.date(byAdding: .day, value: weken * 7, to: gekozen) ?? gekozen
        richting = weken >= 0 ? 1 : -1
        Trilling.keuze()
        withAnimation(Beweging.schuif) {
            verschuiving += weken
            gekozenDag = datumVan(nieuw)
        }
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

// Terug naar nu, naast de datum. Komt alleen op als je ergens anders staat —
// een knop die niets doet is er een te veel.
private struct Vandaagknop: View {
    let opTik: () -> Void

    @Environment(\.palet) private var palet

    var body: some View {
        Button(action: opTik) {
            Text("vandaag")
                .letter(L.opnieuw)
                .foregroundStyle(ORANJE)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(Capsule().fill(ORANJE.opacity(0.14)))
                .overlay(Capsule().strokeBorder(ORANJE.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.druk(0.94))
        .transition(.scale.combined(with: .opacity))
    }
}
