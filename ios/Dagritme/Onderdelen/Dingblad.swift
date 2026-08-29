// Het blad dat één ding bewerkt — waar je het ook opent vandaan. De twee
// schakelaars bepalen wat er verder te kiezen valt.
import SwiftUI

struct Dingblad: View {
    let titel: String
    let plek: Plek?
    let bron: () -> Ruw
    let mensen: [Persoon]
    var bezig: Bool = false
    let opAf: () -> Void
    let opBewaar: (Ding) -> Void
    var opWeg: (() -> Void)? = nil

    @State private var g: Ding
    @State private var melding = ""
    @State private var kiezer = false

    init(titel: String, ding: Ding, plek: Plek?, bron: @escaping () -> Ruw,
         mensen: [Persoon], bezig: Bool = false, opAf: @escaping () -> Void,
         opBewaar: @escaping (Ding) -> Void, opWeg: (() -> Void)? = nil) {
        self.titel = titel
        self.plek = plek
        self.bron = bron
        self.mensen = mensen
        self.bezig = bezig
        self.opAf = opAf
        self.opBewaar = opBewaar
        self.opWeg = opWeg
        _g = State(initialValue: ding)
    }


    var body: some View {
        ZStack {
            Blad(titel: titel, melding: melding, knop: "Bewaar", bezig: bezig,
                 opAf: opAf, opKnop: bewaar) {
                naamdeel
                wanneerdeel
                soortdeel
                wiedeel
                wegknop
            }

            if kiezer {
                Emojikiezer(titel: "Kies een icoon", huidig: g.icoon,
                            opAf: { kiezer = false },
                            opKlaar: { teken in g.icoon = teken; kiezer = false })
            }
        }
    }

    @ViewBuilder
    private var naamdeel: some View {
        Formkop("Icoon en naam", eerste: true)
        HStack(spacing: 10) {
            Emojiknop(waarde: g.icoon, maat: 52) { kiezer = true }
            Veld(waarde: $g.tekst, plaatshouder: "Wat is er")
        }
    }

    @ViewBuilder
    private var wanneerdeel: some View {
        Formkop("Hoe vaak")
        Chips {
            Chip(label: "🔁 herhalen", aan: g.wekelijks) { g.wekelijks = true }
            Chip(label: "📌 één keer", aan: !g.wekelijks) { g.wekelijks = false }
        }

        if g.wekelijks {
            Formkop("Op welke dagen")
            Chips(gelijk: true) {
                ForEach(WEEKDAGEN, id: \.self) { dag in
                    Chip(label: dag, aan: g.dagen.contains(dag)) {
                        if let i = g.dagen.firstIndex(of: dag) { g.dagen.remove(at: i) }
                        else { g.dagen.append(dag) }
                    }
                }
            }
        } else {
            Formkop("Op welke dag")
            DatePicker("Datum", selection: datum, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "nl_NL"))
                .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var soortdeel: some View {
        Formkop("Wat voor iets")
        Chips {
            Chip(label: "✅ taak", aan: g.taak) {
                g.taak = true
                if g.groep.trimmingCharacters(in: .whitespaces).isEmpty {
                    g.groep = eersteGroepnaam(bron(), g.ritme)
                }
            }
            Chip(label: "🗓️ agenda", aan: !g.taak) { g.taak = false }
        }

        if g.taak {
            Formkop("In welk ritme")
            Chips {
                Chip(label: "☀️ ochtend", aan: g.ritme == .dag) {
                    g.ritme = .dag
                    g.groep = eersteGroepnaam(bron(), .dag)
                }
                Chip(label: "🌙 avond", aan: g.ritme == .nacht) {
                    g.ritme = .nacht
                    g.groep = eersteGroepnaam(bron(), .nacht)
                }
            }

            Formkop("Bij welk onderdeel")
            Chips {
                ForEach(groepnamen, id: \.self) { naam in
                    Chip(label: naam, aan: g.groep == naam) { g.groep = naam }
                }
            }
        } else {
            Formkop("Hoe laat")
            HStack(spacing: 10) {
                Veld(waarde: $g.tijd, plaatshouder: "van", soort: .tijd)
                Text("–").letter(L.rijdagen).foregroundStyle(ZACHTINKT)
                Veld(waarde: $g.tot, plaatshouder: "tot", soort: .tijd)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var wiedeel: some View {
        Formkop("Voor wie")
        Chips {
            Chip(label: "iedereen", aan: g.wie.isEmpty) { g.wie = [] }
            ForEach(mensen) { persoon in
                Chip(label: "\(persoon.emoji) \(persoon.naam.isEmpty ? "kind" : persoon.naam)",
                     aan: g.wie.contains(persoon.id),
                     kleur: Color(hex: persoon.kleur)) {
                    if let i = g.wie.firstIndex(of: persoon.id) { g.wie.remove(at: i) }
                    else { g.wie.append(persoon.id) }
                }
            }
        }
    }

    @ViewBuilder
    private var wegknop: some View {
        if let opWeg {
            Button(action: opWeg) {
                Text("Verwijderen")
                    .letter(Letter(font: L.balooZwaar(14.5)))
                    .foregroundStyle(ROOD)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ROOD.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(ROOD.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.druk)
            .padding(.top, 18)
        }
    }

    private var groepnamen: [String] {
        bron()[g.ritme]
            .map { $0.groep.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var datum: Binding<Date> {
        Binding(
            get: { alsDatum(g.datum) ?? Date() },
            set: { g.datum = datumVan($0) }
        )
    }

    private func bewaar() {
        if let fout = verplaatsDing(bron(), plek, g) {
            melding = fout
            return
        }
        opBewaar(g)
    }

    // De tijd bepaalt of iets bij Overdag of bij Vanavond komt te staan; dat is
    // beter uit te leggen dan het te laten zien nadat je hebt bewaard.
    private var tijduitleg: String {
        let vanaf = AVONDVANAF
        guard let uur = uurUitTijd(g.tijd) else {
            return g.avond
                ? "Zonder tijd blijft dit bij Vanavond staan, zoals het was. Vul een tijd in vanaf \(vanaf):00 om dat zo te houden."
                : "Zonder tijd komt dit bij Overdag te staan. Vanaf \(vanaf):00 gaat het naar Vanavond."
        }
        return uur >= vanaf
            ? "Komt bij Vanavond te staan — dat begint om \(vanaf):00."
            : "Komt bij Overdag te staan; vanaf \(vanaf):00 zou het Vanavond zijn."
    }
}
