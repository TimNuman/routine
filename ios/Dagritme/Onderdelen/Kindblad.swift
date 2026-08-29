// Eén kind bewerken: gezicht, naam, kleur en wat we verder van hem weten.
import SwiftUI

struct Kenmerkpaar: Identifiable {
    let id = UUID()
    var sleutel: String = ""
    var waarde: String = ""
}

struct Kindgegevens {
    var id: String
    var naam: String
    var emoji: String
    var kleur: String
    var paren: [Kenmerkpaar]

    init(id: String, naam: String, emoji: String, kleur: String, kenmerken: [String: String]) {
        self.id = id
        self.naam = naam
        self.emoji = emoji
        self.kleur = kleur
        self.paren = kenmerken.sorted { $0.key < $1.key }
            .map { Kenmerkpaar(sleutel: $0.key, waarde: $0.value) }
    }

    var kenmerken: [String: String] {
        var uit: [String: String] = [:]
        for paar in paren {
            let sleutel = paar.sleutel.trimmingCharacters(in: .whitespacesAndNewlines)
            let waarde = paar.waarde.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sleutel.isEmpty && !waarde.isEmpty { uit[sleutel] = waarde }
        }
        return uit
    }
}

struct Kindblad: View {
    let titel: String
    let opAf: () -> Void
    let opBewaar: (Kindgegevens) -> Void

    @State private var g: Kindgegevens
    @State private var kiezer = false

    init(titel: String, kind: Kindgegevens, opAf: @escaping () -> Void,
         opBewaar: @escaping (Kindgegevens) -> Void) {
        self.titel = titel
        self.opAf = opAf
        self.opBewaar = opBewaar
        _g = State(initialValue: kind)
    }

    var body: some View {
        ZStack {
            Blad(titel: titel, knop: "Bewaar", opAf: opAf, opKnop: { opBewaar(g) }) {
                Formkop("Gezicht en naam", eerste: true)
                HStack(spacing: 10) {
                    Emojiknop(waarde: g.emoji, maat: 52) { kiezer = true }
                    Veld(waarde: $g.naam, plaatshouder: "Naam")
                }

                Formkop("Kleur")
                Chips {
                    ForEach(KLEUREN, id: \.self) { kleur in
                        Button { g.kleur = kleur } label: {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color(hex: kleur))
                                .frame(minHeight: 34)
                                .frame(maxWidth: .infinity)
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(INKT, lineWidth: g.kleur == kleur ? 2.5 : 0))
                        }
                        .buttonStyle(.druk)
                        .frame(width: 64, height: 34)
                        .accessibilityLabel("Kleur")
                    }
                }
                Notitie("Naam wijzigen mag: de vinkjes blijven bij de juiste persoon.")

                // Wat een bericht van school of de club nodig heeft om bij het
                // juiste kind uit te komen. Meestal vult dit zich vanzelf: de
                // assistent vraagt ernaar zodra hij het tegenkomt.
                Formkop("Wat we verder weten")
                Bewerkkaart {
                    ForEach(Array(g.paren.enumerated()), id: \.element.id) { (i, _) in
                        if i > 0 { Streepje() }
                        HStack(spacing: 10) {
                            Minknop(titel: "Kenmerk verwijderen") {
                                g.paren.remove(at: i)
                            }
                            Veld(waarde: $g.paren[i].sleutel, plaatshouder: "waarvan")
                            Veld(waarde: $g.paren[i].waarde, plaatshouder: "welke")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 58)
                    }
                    Toevoegrij("Kenmerk toevoegen") { g.paren.append(Kenmerkpaar()) }
                }
                Notitie("""
                    Bijvoorbeeld schoolgroep 1-2B, of team JO9-3. Daarmee weet de app bij wie \
                    een bericht van school of de club hoort.
                    """)
            }

            if kiezer {
                Emojikiezer(titel: "Kies een gezicht", huidig: g.emoji,
                            opAf: { kiezer = false },
                            opKlaar: { teken in g.emoji = teken; kiezer = false })
            }
        }
    }
}
