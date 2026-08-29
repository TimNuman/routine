// De zes bewerkschermen onder Instellingen. Ze werken allemaal op één losse
// kopie van de inhoud — het concept — en pas bij Gereed gaat die het huis in.
import SwiftUI

enum Velsoort: String, Identifiable {
    case kinderen, dag, nacht, overzicht, eenmalig, algemeen
    var id: String { rawValue }

    var titel: String {
        switch self {
        case .kinderen: return "Kinderen"
        case .dag: return "Ochtendritme"
        case .nacht: return "Avondritme"
        case .overzicht: return "Weekritme"
        case .eenmalig: return "Eenmalig"
        case .algemeen: return "Naam"
        }
    }
}

// Een band naar één veld in het concept. Het concept bestaat uit klassen, dus
// een verwijzing is genoeg: wat je typt staat er meteen in, zonder dat het
// scherm zichzelf opnieuw tekent en de cursor wegspringt.
func band<T: AnyObject>(_ ding: T, _ pad: ReferenceWritableKeyPath<T, String>) -> Binding<String> {
    Binding(get: { ding[keyPath: pad] }, set: { ding[keyPath: pad] = $0 })
}

struct Bladstand {
    var titel: String
    var plek: Plek?
    var ding: Ding
}

struct Kindstand {
    var titel: String
    var kind: Kindgegevens
}

struct Velscherm: View {
    let soort: Velsoort
    let opAf: () -> Void
    let opBewaar: (Ruw) async -> String?

    @State private var concept: Ruw
    @State private var herteken = 0
    @State private var melding = ""
    @State private var bezig = false
    @State private var ritme: Ritme
    @State private var blad: Bladstand?
    @State private var kindblad: Kindstand?
    // Slepen om te sorteren kan in SwiftUI alleen in de bewerkstand van een List;
    // zonder die stand doet .onMove niets. Vandaar een eigen knop, en niet altijd
    // aan: dan zouden de sleepgrepen er permanent bij staan.
    @State private var ordenen = false

    init(soort: Velsoort, inhoud: Inhoud, opAf: @escaping () -> Void,
         opBewaar: @escaping (Ruw) async -> String?) {
        self.soort = soort
        self.opAf = opAf
        self.opBewaar = opBewaar
        _concept = State(initialValue: alsRuw(inhoud))
        _ritme = State(initialValue: soort == .nacht ? .nacht : .dag)
    }

    // De kinderen in dit scherm zijn die van het concept, niet die van de inhoud.
    private var mensen: [Persoon] {
        concept.mensen.map {
            Persoon(id: $0.id, naam: $0.naam, emoji: $0.emoji.isEmpty ? "🙂" : $0.emoji,
                    kleur: $0.kleur.isEmpty ? KLEUREN[0] : $0.kleur, kenmerken: $0.kenmerken)
        }
    }

    private func wieVoorRij(_ wie: [String]) -> [Persoon] {
        let gekozen = wie.compactMap { id in mensen.first { $0.id == id } }
        return gekozen.count > 0 && gekozen.count < mensen.count ? gekozen : []
    }

    private func opnieuw() { herteken += 1 }

    private func openDing(_ titel: String, _ plek: Plek?, _ pas: (inout Ding) -> Void) {
        var ding = dingVan(concept, plek)
        pas(&ding)
        blad = Bladstand(titel: titel, plek: plek, ding: ding)
    }

    var body: some View {
        // Elke wijziging in het concept tikt deze teller aan; zo tekent het
        // scherm zichzelf opnieuw, net als de react native-versie doet.
        let _ = herteken

        ZStack {
            Vel(titel: soort.titel, melding: melding, bezig: bezig,
                eigenRol: soort != .algemeen,
                opAf: opAf, opGereed: gereed) {
                switch soort {
                case .kinderen:
                    kinderen
                case .dag, .nacht:
                    ritmevel
                case .overzicht:
                    weekvel
                case .eenmalig:
                    eenmaligvel
                case .algemeen:
                    algemeenvel
                }
            }

            if let stand = blad {
                Dingblad(
                    titel: stand.titel,
                    ding: stand.ding,
                    plek: stand.plek,
                    bron: { concept },
                    mensen: mensen,
                    opAf: { blad = nil },
                    opBewaar: { _ in blad = nil; opnieuw() }
                )
                .environment(\.palet, Palet(donker: false))
            }

            if let stand = kindblad {
                Kindblad(
                    titel: stand.titel,
                    kind: stand.kind,
                    opAf: { kindblad = nil },
                    opBewaar: bewaarKind
                )
                .environment(\.palet, Palet(donker: false))
            }
        }
    }

    private func bewaarKind(_ nieuw: Kindgegevens) {
        if let bestaand = concept.mensen.first(where: { $0.id == nieuw.id }) {
            bestaand.naam = nieuw.naam
            bestaand.emoji = nieuw.emoji.isEmpty ? "🙂" : nieuw.emoji
            bestaand.kleur = nieuw.kleur
            bestaand.kenmerken = nieuw.kenmerken
        } else if !nieuw.naam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            concept.mensen.append(RuwPersoon(
                id: nieuw.id,
                naam: nieuw.naam,
                emoji: nieuw.emoji.isEmpty ? "🙂" : nieuw.emoji,
                kleur: nieuw.kleur.isEmpty ? KLEUREN[concept.mensen.count % KLEUREN.count] : nieuw.kleur,
                kenmerken: nieuw.kenmerken
            ))
        }
        kindblad = nil
        opnieuw()
    }

    private func gereed() {
        let nieuw = opgeschoond(concept)
        if (nieuw["mensen"] as? [[String: Any]] ?? []).isEmpty {
            melding = "Er moet minstens één kind zijn."
            return
        }
        let dagStappen = telStappen(nieuw["dag"] as? [[String: Any]] ?? [])
        let nachtStappen = telStappen(nieuw["nacht"] as? [[String: Any]] ?? [])
        if dagStappen == 0 && nachtStappen == 0 {
            melding = "Er moet minstens één stap overblijven."
            return
        }
        bezig = true
        Task {
            let fout = await opBewaar(concept)
            bezig = false
            if let fout { melding = fout } else { opAf() }
        }
    }

    // ------------------------------------------------------------- kinderen ---

    @ViewBuilder
    private var kinderen: some View {
        Ordenknop(aan: $ordenen)
        List {
            Section {
                ForEach(concept.mensen) { persoon in
                    Kindrij(persoon: persoon, opOpenen: { openKind(persoon) })
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { haalKindWeg(persoon) } label: {
                                Label("Weg", systemImage: "trash")
                            }
                        }
                }
                .onMove { van, naar in
                    concept.mensen.move(fromOffsets: van, toOffset: naar)
                    opnieuw()
                }

                Toevoegrij("Kind toevoegen") {
                    kindblad = Kindstand(
                        titel: "Nieuw kind",
                        kind: Kindgegevens(id: nieuwId(), naam: "", emoji: "🙂",
                                           kleur: KLEUREN[concept.mensen.count % KLEUREN.count],
                                           kenmerken: [:])
                    )
                }
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(rijvlak)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(ordenen ? .active : .inactive))
    }

    // Het melkglas onder een lijstregel: de blur en daaroverheen de kleur uit het
    // palet, net als in Glas. De afgeronde hoek doet insetGrouped zelf.
    private var rijvlak: some View {
        Rectangle().fill(.ultraThinMaterial)
            .overlay(Rectangle().fill(Palet(donker: false).glas))
    }

    private func openKind(_ persoon: RuwPersoon) {
        kindblad = Kindstand(
            titel: persoon.naam.isEmpty ? "Kind" : persoon.naam,
            kind: Kindgegevens(id: persoon.id, naam: persoon.naam,
                               emoji: persoon.emoji.isEmpty ? "🙂" : persoon.emoji,
                               kleur: persoon.kleur,
                               kenmerken: persoon.kenmerken)
        )
    }

    private func haalKindWeg(_ persoon: RuwPersoon) {
        if concept.mensen.count <= 1 {
            melding = "Er moet minstens één kind overblijven."
            return
        }
        losmaken(persoon.id)
        concept.mensen.removeAll { $0 === persoon }
        melding = ""
        opnieuw()
    }

    // Anders wijst een stap naar iemand die er niet meer is.
    private func losmaken(_ id: String) {
        for welk in [Ritme.dag, .nacht] {
            for groep in concept[welk] {
                for stap in groep.stappen { stap.wie.removeAll { $0 == id } }
            }
        }
        for item in concept.overzicht { item.wie.removeAll { $0 == id } }
        for event in concept.events { event.wie.removeAll { $0 == id } }
    }

    // ----------------------------------------------------------- het ritme ---

    @ViewBuilder
    private var ritmevel: some View {
        Ordenknop(aan: $ordenen)
        List {
            Section {
                Segment(ritme: ritme, opKies: { ritme = $0 }, marge: 0)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }
            .listRowBackground(Color.clear)

            ForEach(concept[ritme]) { groep in
                // Een stap met een datum hoort maar op één plek thuis: bij Eenmalig.
                let vast = groep.stappen.filter { $0.datum.isEmpty }
                let eenmalig = groep.stappen.count - vast.count

                Section {
                    HStack(spacing: 8) {
                        Veld(waarde: band(groep, \.groep), plaatshouder: "Groep")
                        Veld(waarde: band(groep, \.tijd), plaatshouder: "tijd", soort: .tijd)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { haalGroepWeg(groep) } label: {
                            Label("Weg", systemImage: "trash")
                        }
                    }
                    .moveDisabled(true)

                    ForEach(vast) { stap in
                        Bewerkrij(
                            icoon: stap.icoon.isEmpty ? "⭐" : stap.icoon,
                            label: stap.label,
                            leeg: "Naamloze stap",
                            dagen: dagenTekst(stap.dagen),
                            wie: wieVoorRij(stap.wie),
                            opOpenen: {
                                openDing(stap.label.isEmpty ? "Stap" : stap.label,
                                         .stap(ritme: ritme, groep: groep, stap: stap)) { _ in }
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                groep.stappen.removeAll { $0 === stap }
                                opnieuw()
                            } label: { Label("Weg", systemImage: "trash") }
                        }
                    }
                    .onMove { van, naar in
                        verzetStap(groep, vast, van, naar)
                    }

                    if eenmalig > 0 {
                        Kaartnoot(eenmalig == 1
                            ? "Hier staat ook één ding voor één dag; dat bewerk je bij Eenmalig."
                            : "Hier staan ook \(eenmalig) dingen voor één dag; die bewerk je bij Eenmalig.")
                            .moveDisabled(true)
                    }

                    Toevoegrij("Stap toevoegen") {
                        openDing("Nieuwe stap", nil) { ding in
                            ding.icoon = "⭐"
                            ding.taak = true
                            ding.ritme = ritme
                            ding.groep = groep.groep.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .moveDisabled(true)
                }
                .listRowBackground(rijvlak)
            }

            Section {
                Kaartknop("Groep toevoegen", plus: true) {
                    concept[ritme].append(RuwGroep(groep: "Nieuwe groep", tijd: "", stappen: []))
                    opnieuw()
                }
                .padding(.top, 0)
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(ordenen ? .active : .inactive))
    }

    // Een groep met stappen erin weghalen zou die stappen stilletjes meenemen.
    private func haalGroepWeg(_ groep: RuwGroep) {
        guard groep.stappen.isEmpty else {
            melding = "Haal eerst de stappen uit '\(groep.groep)'."
            return
        }
        concept[ritme].removeAll { $0 === groep }
        melding = ""
        opnieuw()
    }

    // `vast` is een uitsnede van groep.stappen — wat een datum heeft hoort bij
    // Eenmalig — dus de plek in beeld moet eerst terug naar de echte lijst.
    private func verzetStap(_ groep: RuwGroep, _ vast: [RuwStap], _ van: IndexSet, _ naar: Int) {
        guard let bron = van.first, vast.indices.contains(bron) else { return }
        let stap = vast[bron]
        guard let a = groep.stappen.firstIndex(where: { $0 === stap }) else { return }
        let doel: Int
        if naar >= vast.count {
            doel = groep.stappen.count
        } else if let b = groep.stappen.firstIndex(where: { $0 === vast[naar] }) {
            doel = b
        } else {
            return
        }
        let ding = groep.stappen.remove(at: a)
        groep.stappen.insert(ding, at: min(max(0, a < doel ? doel - 1 : doel), groep.stappen.count))
        opnieuw()
    }

    // ----------------------------------------------------------- weekritme ---

    @ViewBuilder
    private var weekvel: some View {
        Ordenknop(aan: $ordenen)
        List {
            Section {
                ForEach(concept.overzicht) { item in
                    Bewerkrij(
                        icoon: item.icoon.isEmpty ? "📅" : item.icoon,
                        label: item.tekst,
                        leeg: "Naamloos",
                        tijd: (naAvond(tijd: item.tijd, tot: item.tot,
                                       avond: item.avond, vanaf: AVONDVANAF) ? "🌙 " : "")
                            + tijdTekst(tijd: item.tijd, tot: item.tot),
                        dagen: dagenTekst(item.dagen),
                        wie: wieVoorRij(item.wie),
                        tweeregels: true,
                        opOpenen: {
                            openDing(item.tekst.isEmpty ? "Item" : item.tekst, .overzicht(item)) { _ in }
                        }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            concept.overzicht.removeAll { $0 === item }
                            opnieuw()
                        } label: { Label("Weg", systemImage: "trash") }
                    }
                }
                .onMove { van, naar in
                    concept.overzicht.move(fromOffsets: van, toOffset: naar)
                    opnieuw()
                }

                Toevoegrij("Item toevoegen") {
                    openDing("Nieuw item", nil) { ding in
                        ding.icoon = "📅"
                        ding.wekelijks = true
                        ding.taak = false
                    }
                }
                .listRowInsets(EdgeInsets())
                .moveDisabled(true)
            }
            .listRowBackground(rijvlak)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(ordenen ? .active : .inactive))
    }

    // ------------------------------------------------------------ eenmalig ---
    // Geen ordenknop: deze lijst staat op datum, en die volgorde is niet aan jou.

    @ViewBuilder
    private var eenmaligvel: some View {
        let dingen = eenmaligeUitConcept()
        List {
            if dingen.isEmpty {
                Section {
                    Text("Er staat niets op een datum.")
                        .letter(L.leeg)
                        .foregroundStyle(ZACHTINKT)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .listRowBackground(rijvlak)
            } else {
                Section {
                    ForEach(Array(dingen.enumerated()), id: \.offset) { (_, ding) in
                        Bewerkrij(
                            icoon: ding.icoon,
                            label: ding.naam,
                            leeg: "Naamloos",
                            tijd: kortDatum(ding.datum),
                            extra: ding.extra,
                            wie: wieVoorRij(ding.wie),
                            tweeregels: true,
                            opOpenen: {
                                openDing(ding.naam.isEmpty ? "Iets eenmaligs" : ding.naam,
                                         ding.plek) { _ in }
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                haalDingWeg(concept, ding.plek)
                                opnieuw()
                            } label: { Label("Weg", systemImage: "trash") }
                        }
                    }
                }
                .listRowBackground(rijvlak)
            }

            Section {
                Kaartknop("Iets eenmaligs toevoegen", plus: true) {
                    openDing("Iets eenmaligs", nil) { ding in
                        ding.icoon = "🎉"
                        ding.wekelijks = false
                        ding.taak = false
                    }
                }
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private struct Eenmaligrij {
        var icoon: String
        var naam: String
        var datum: String
        var extra: String
        var wie: [String]
        var plek: Plek
        var tijd: String
    }

    private func eenmaligeUitConcept() -> [Eenmaligrij] {
        var uit: [Eenmaligrij] = concept.events.filter { !$0.datum.isEmpty }.map { item in
            Eenmaligrij(
                icoon: item.icoon.isEmpty ? "📌" : item.icoon,
                naam: item.tekst,
                datum: item.datum,
                extra: tijdTekst(tijd: item.tijd, tot: item.tot),
                wie: item.wie,
                plek: .event(item),
                tijd: item.tijd
            )
        }
        for welk in [Ritme.dag, .nacht] {
            for groep in concept[welk] {
                for stap in groep.stappen where !stap.datum.isEmpty {
                    let naam = groep.groep.trimmingCharacters(in: .whitespaces)
                    uit.append(Eenmaligrij(
                        icoon: stap.icoon.isEmpty ? "📌" : stap.icoon,
                        naam: stap.label,
                        datum: stap.datum,
                        extra: "✅ " + (welk == .dag ? "☀️ " : "🌙 ") + (naam.isEmpty ? "ritme" : naam),
                        wie: stap.wie,
                        plek: .stap(ritme: welk, groep: groep, stap: stap),
                        tijd: ""
                    ))
                }
            }
        }
        return uit.sorted { ($0.datum, $0.tijd) < ($1.datum, $1.tijd) }
    }

    // ------------------------------------------------------------ algemeen ---

    @ViewBuilder
    private var algemeenvel: some View {
        Bewerkkaart {
            HStack(spacing: 10) {
                Text("🏡").font(.system(size: 24)).frame(width: 46)
                Veld(waarde: band(concept, \.titel), plaatshouder: "Naam van de app")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minHeight: 58)
        }
    }
}

private struct Kaartnoot: View {
    let tekst: String
    @Environment(\.palet) private var palet

    init(_ tekst: String) { self.tekst = tekst }

    var body: some View {
        VStack(spacing: 0) {
            Streepje()
            Text(tekst)
                .letter(Letter(font: L.nunitoZwaar(12.5)))
                .foregroundStyle(palet.zacht)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Eén kind in de lijst. Los van Bewerkrij omdat een lijstregel zijn eigen
// scheiding en zijn eigen veeg meebrengt; dit is alleen nog wat erin staat.
private struct Kindrij: View {
    let persoon: RuwPersoon
    let opOpenen: () -> Void

    @Environment(\.palet) private var palet

    var body: some View {
        Button(action: opOpenen) {
            HStack(spacing: 10) {
                Emojiknop(waarde: persoon.emoji.isEmpty ? "🙂" : persoon.emoji, opTik: opOpenen)
                Text(persoon.naam.isEmpty ? "Naamloos" : persoon.naam)
                    .letter(L.rijlabel)
                    .foregroundStyle(persoon.naam.isEmpty ? palet.zacht : palet.inkt)
                    .lineLimit(1)
                if !persoon.kleur.isEmpty {
                    Circle().fill(Color(hex: persoon.kleur)).frame(width: 16, height: 16)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.druk)
    }
}

// Aan of uit voor de sleepstand. Klein en rechts, zodat het geen knop is die je
// per ongeluk raakt maar wel te vinden is als je hem zoekt.
private struct Ordenknop: View {
    @Binding var aan: Bool

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                Trilling.keuze()
                withAnimation(Beweging.veer) { aan.toggle() }
            } label: {
                Text(aan ? "klaar" : "volgorde")
                    .letter(L.opnieuw)
                    .foregroundStyle(ORANJE)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(Capsule().fill(ORANJE.opacity(aan ? 0.22 : 0.12)))
                    .overlay(Capsule().strokeBorder(ORANJE.opacity(0.30), lineWidth: 1))
            }
            .buttonStyle(.druk(0.94))
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
    }
}
