// Het blad waar je een bericht in plakt. Vier standen: plakken, even lezen, een
// vraag terug, en de voorstellen om over te nemen.
import SwiftUI

private let MAX_VRAGEN = 2   // daarna raadt hij liever dan nog eens te vragen

struct Assistentblad: View {
    let inhoud: Inhoud
    let opAf: () -> Void
    let opBewaar: (Ruw) async -> String?

    private enum Stand { case plakken, bezig, vraag, voorstellen, niets }

    @Environment(\.palet) private var palet

    @State private var stand: Stand = .plakken
    @State private var melding = ""
    @State private var bericht = ""
    @State private var ronde = 0
    @State private var gevraagd = 0
    @State private var vraag: Vraag?
    @State private var antwoord: [String: [String]] = [:]
    @State private var items: [Voorstel] = []
    @State private var keuze: [Bool] = []
    @State private var bewerk: Int?
    @State private var werk: Ruw?

    private var gekozenAantal: Int { keuze.filter { $0 }.count }

    private var titel: String {
        switch stand {
        case .bezig: return "Even lezen"
        case .niets: return "Niets gevonden"
        case .vraag: return "Even iets vragen"
        case .voorstellen: return "Dit haalde ik eruit"
        case .plakken: return "Typ of plak iets"
        }
    }

    private var knop: String {
        switch stand {
        case .bezig: return "Even lezen…"
        case .niets: return "Opnieuw proberen"
        case .vraag: return "Ga verder"
        case .voorstellen: return gekozenAantal == 1
            ? "Zet er 1 in de app" : "Zet er \(gekozenAantal) in de app"
        case .plakken: return "Lees uit"
        }
    }

    var body: some View {
        ZStack {
            Blad(titel: titel, melding: melding, knop: knop,
                 bezig: stand == .bezig || (stand == .voorstellen && gekozenAantal == 0),
                 opAf: opAf, opKnop: verder) {
                switch stand {
                case .plakken:
                    Formkop("De tekst", eerste: true)
                    Plakvak(waarde: $bericht)
                    Notitie("""
                        Wat elke week terugkomt gaat naar het weekritme, wat één dag geldt naar \
                        Eenmalig. Er wordt ook meegedacht: bij een verjaardag hoort een cadeautje \
                        op tijd. Alleen wat je hier typt gaat mee, plus de voornamen van de kinderen.
                        """)

                case .bezig:
                    Bezig("Even kijken wat erin staat…")

                case .niets:
                    Bezig("""
                        Hier kon ik niets uithalen dat in de app hoort. Probeer het wat concreter, \
                        of plak er meer bij.
                        """)

                case .vraag:
                    if let vraag {
                        Formkop("Vraag", eerste: true)
                        Notitie(vraag.vraag)
                        ForEach(inhoud.mensen) { persoon in
                            Vraagkind(
                                persoon: persoon,
                                vraag: vraag,
                                gekozen: antwoord[persoon.id] ?? [],
                                opKies: { optie in kies(persoon, optie, vraag) },
                                opGeen: { antwoord[persoon.id] = [] }
                            )
                        }
                        Notitie("Wat je kiest blijft bij het kind staan, dus dit hoeft maar één keer.")
                    }

                case .voorstellen:
                    Formkop("Voorstellen", eerste: true)
                    Glas(radius: 22) {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { (i, item) in
                                if i > 0 { Streepje() }
                                Vondst(
                                    item: item,
                                    aan: i < keuze.count && keuze[i],
                                    mensen: inhoud.mensen,
                                    opVink: { if i < keuze.count { keuze[i].toggle() } },
                                    opOpen: { werk = alsRuw(inhoud); bewerk = i }
                                )
                            }
                        }
                    }
                    .padding(.top, 4)
                    Notitie("""
                        Tik het vinkje weg wat je niet wilt, en de regel zelf om hem aan te passen. \
                        Wat aangevinkt blijft staan gaat in één keer de app in.
                        """)
                }
            }

            // Een voorstel is nog niets; je kunt het hier nog helemaal omgooien —
            // ook van eenmalig naar herhalend, of van agenda naar taak.
            if let i = bewerk, i < items.count, let ruw = werk {
                Dingblad(
                    titel: items[i].ding.tekst.isEmpty ? "Voorstel" : items[i].ding.tekst,
                    ding: metGroep(items[i].ding, ruw),
                    plek: nil,
                    bron: { ruw },
                    mensen: inhoud.mensen,
                    opAf: { bewerk = nil },
                    opBewaar: { nieuw in
                        let bron = items[i].bron
                        items[i] = Voorstel(ding: nieuw, bron: bron)
                        if i < keuze.count { keuze[i] = true }
                        bewerk = nil
                    }
                )
            }
        }
    }

    private func metGroep(_ ding: Ding, _ ruw: Ruw) -> Ding {
        var uit = ding
        if uit.groep.trimmingCharacters(in: .whitespaces).isEmpty {
            uit.groep = eersteGroepnaam(ruw, uit.ritme)
        }
        return uit
    }

    private func kies(_ persoon: Persoon, _ optie: String, _ vraag: Vraag) {
        var nu = antwoord[persoon.id] ?? []
        if let i = nu.firstIndex(of: optie) {
            nu.remove(at: i)
        } else if vraag.meerkeuze {
            nu.append(optie)
        } else {
            nu = [optie]
        }
        antwoord[persoon.id] = nu
    }

    private func verder() {
        switch stand {
        case .niets:
            stand = .plakken
        case .plakken:
            if bericht.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                melding = "Plak eerst een bericht."
                return
            }
            Task { await lees() }
        case .vraag:
            Task {
                if await bewaarAntwoorden() { await lees() }
            }
        case .voorstellen:
            Task { await zetErin() }
        case .bezig:
            break
        }
    }

    private func lees() async {
        melding = ""
        stand = .bezig
        let uit: Json
        do {
            uit = try await vraagAssistent(Lading(
                tekst: bericht,
                vandaag: datumVan(Date()),
                ronde: ronde + 1,
                kinderen: inhoud.mensen
            ))
        } catch let fout as Uitleesfout {
            stand = .plakken
            melding = fout.vanServer ? fout.bericht : "Het uitlezen lukte niet (\(fout.bericht))."
            return
        } catch {
            stand = .plakken
            melding = "Het uitlezen lukte niet (\(error.localizedDescription))."
            return
        }

        ronde += 1
        let soort = uit["type"].tekst
        let opties = uit["opties"].lijst.map { $0.tekst }.filter { !$0.isEmpty }
        if soort == "vraag" && !opties.isEmpty && gevraagd < MAX_VRAGEN {
            gevraagd += 1
            antwoord = [:]
            vraag = Vraag(
                sleutel: uit["sleutel"].tekst("kenmerk"),
                vraag: uit["vraag"].tekst("Waar hoort dit bij?"),
                opties: opties,
                meerkeuze: uit["meerkeuze"].vlag
            )
            stand = .vraag
            return
        }

        let gevonden = uit["items"].lijst.compactMap { schoonVoorstel($0, inhoud.mensen) }
        items = gevonden
        keuze = gevonden.map { _ in true }
        stand = gevonden.isEmpty ? .niets : .voorstellen
    }

    // Het antwoord op een vraag is een kenmerk van het kind en gaat meteen mee
    // het huis in — dan hoeft het de volgende keer niet nog eens gevraagd.
    private func bewaarAntwoorden() async -> Bool {
        guard let vraag else { return true }
        let ruw = alsRuw(inhoud)
        var iets = false
        for persoon in ruw.mensen {
            let gekozen = (antwoord[persoon.id] ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if gekozen.isEmpty {
                persoon.kenmerken.removeValue(forKey: vraag.sleutel)
            } else {
                persoon.kenmerken[vraag.sleutel] = gekozen.joined(separator: ", ")
                iets = true
            }
        }
        if !iets { return true }
        if let fout = await opBewaar(ruw) {
            melding = fout
            return false
        }
        return true
    }

    private func zetErin() async {
        let gekozen = items.enumerated().filter { $0.offset < keuze.count && keuze[$0.offset] }
            .map { $0.element }
        if gekozen.isEmpty {
            melding = "Kies er minstens één."
            return
        }
        let ruw = alsRuw(inhoud)
        for voorstel in gekozen where !alBekend(ruw, voorstel.ding) {
            zetDingNeer(ruw, voorstel.ding, "", nil)
        }
        if let fout = await opBewaar(ruw) { melding = fout } else { opAf() }
    }
}

private struct Plakvak: View {
    @Binding var waarde: String
    @Environment(\.palet) private var palet

    var body: some View {
        ZStack(alignment: .topLeading) {
            if waarde.isEmpty {
                Text("Plak een mail of appje, of typ het gewoon:\n\niedere dinsdag om 18:00 tennis Emma")
                    .letter(Letter(font: L.nunito(14)))
                    .foregroundStyle(ZACHTINKT.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $waarde)
                .letter(Letter(font: L.nunito(14)))
                .foregroundStyle(palet.inkt)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minHeight: 148)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palet.veld))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(palet.veldRand, lineWidth: 1))
    }
}

private struct Bezig: View {
    let tekst: String
    @Environment(\.palet) private var palet

    init(_ tekst: String) { self.tekst = tekst }

    var body: some View {
        Text(tekst)
            .letter(L.bezig)
            .foregroundStyle(palet.zacht)
            .multilineTextAlignment(.center)
            .padding(.vertical, 34)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
    }
}

private struct Vraagkind: View {
    let persoon: Persoon
    let vraag: Vraag
    let gekozen: [String]
    let opKies: (String) -> Void
    let opGeen: () -> Void

    @Environment(\.palet) private var palet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(persoon.emoji).font(.system(size: 19))
                Text(persoon.naam).letter(L.vraagnaam).foregroundStyle(palet.inkt)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 7)

            Chips {
                ForEach(vraag.opties, id: \.self) { optie in
                    Chip(label: optie, aan: gekozen.contains(optie),
                         kleur: Color(hex: persoon.kleur)) { opKies(optie) }
                }
                // 'Geen van deze' is een antwoord, geen keuze om naar toe te trekken.
                Chip(label: "geen van deze", aan: gekozen.isEmpty, stil: true) { opGeen() }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
}

private struct Vondst: View {
    let item: Voorstel
    let aan: Bool
    let mensen: [Persoon]
    let opVink: () -> Void
    let opOpen: () -> Void

    @Environment(\.palet) private var palet

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button(action: opVink) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(aan ? ORANJE : palet.tegel)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(aan ? ORANJE : palet.tegelRand, lineWidth: 1.5))
                    .overlay { if aan { Text("✓").font(.system(size: 13)).foregroundStyle(.white) } }
                    .frame(width: 23, height: 23)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .padding(.leading, 13)
                    .padding(.trailing, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(aan ? "Niet overnemen" : "Wel overnemen")

            Button(action: opOpen) {
                HStack(alignment: .top, spacing: 11) {
                    Text(item.ding.icoon).font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.ding.tekst)
                            .letter(L.vondstnaam)
                            .foregroundStyle(palet.inkt)
                            .fixedSize(horizontal: false, vertical: true)
                        if !meta.isEmpty {
                            Text(meta)
                                .letter(L.vondstmeta)
                                .foregroundStyle(palet.zacht)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !item.bron.isEmpty {
                            Text("„\(item.bron)”")
                                .letter(Letter(font: L.nunito(12)))
                                .italic()
                                .foregroundStyle(palet.zacht)
                                .opacity(0.85)
                                .lineSpacing(2)
                                .padding(.top, 3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Pijltje().opacity(0.5).padding(.top, 4)
                }
                .padding(.vertical, 12)
                .padding(.trailing, 13)
                .padding(.leading, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var meta: String {
        let g = item.ding
        let wanneer = g.wekelijks ? (dagenTekst(g.dagen).isEmpty ? "elke dag" : dagenTekst(g.dagen))
                                  : langeDatum(g.datum)
        let namen = g.wie.compactMap { id in mensen.first { $0.id == id }?.naam }
        let soort = g.taak
            ? "✅ " + (g.ritme == .nacht ? "🌙 " : "☀️ ")
                + (g.groep.trimmingCharacters(in: .whitespaces).isEmpty ? "ritme" : g.groep)
            : (g.wekelijks ? "elke week" : "")
        return [wanneer, tijdTekst(tijd: g.tijd, tot: g.tot),
                namen.isEmpty ? "iedereen" : namen.joined(separator: " en "), soort]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func langeDatum(_ waarde: String) -> String {
        guard let d = alsDatum(waarde) else { return "" }
        return datumTekst(d)
    }
}
