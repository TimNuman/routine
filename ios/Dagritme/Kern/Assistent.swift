// School, voetbal, judo en de bso sturen berichten; die wil je niet overtikken.
// Plak er een in en er komt een lijstje uit dat je met een tik overneemt. Weet
// de uitlezer iets niet — welk kind in 1-2B zit bijvoorbeeld — dan vraagt hij
// ernaar, en het antwoord blijft als kenmerk bij het kind staan.
//
// Het echte uitlezen doet Claude, op /api/lees in de Worker: daar staat de
// sleutel van de api, en die hoort niet in iets wat iedereen kan openmaken.
import Foundation

struct Lading {
    var tekst: String
    var vandaag: String
    var ronde: Int
    var kinderen: [Persoon]

    var lijf: [String: Any] {
        [
            "tekst": tekst,
            "vandaag": vandaag,
            "ronde": ronde,
            "kinderen": kinderen.map {
                ["id": $0.id, "naam": $0.naam, "kenmerken": $0.kenmerken] as [String: Any]
            },
        ]
    }
}

struct Vraag {
    var sleutel: String
    var vraag: String
    var opties: [String]
    var meerkeuze: Bool
}

struct Voorstel: Identifiable {
    let id = UUID()
    var ding: Ding
    var bron: String
}

// Zegt de uitlezer zelf wat er mis is, dan is dat de melding — er hoeft geen
// 'het lukte niet' omheen.
struct Uitleesfout: LocalizedError {
    var bericht: String
    var vanServer: Bool
    var errorDescription: String? { bericht }
}

func vraagAssistent(_ lading: Lading) async throws -> Json {
    guard let adres = Configuratie.assistent else {
        throw Uitleesfout(bericht: "Er is nog geen adres voor de uitlezer.", vanServer: false)
    }
    var verzoek = URLRequest(url: adres)
    verzoek.httpMethod = "POST"
    verzoek.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if !Configuratie.sleutel.isEmpty {
        verzoek.setValue(Configuratie.sleutel, forHTTPHeaderField: "X-Routine-Sleutel")
    }
    verzoek.httpBody = try JSONSerialization.data(withJSONObject: lading.lijf)
    // Uitlezen duurt langer dan een gewoon verzoek: Claude denkt even na.
    verzoek.timeoutInterval = 90

    let (gegevens, antwoord) = try await URLSession.shared.data(for: verzoek)
    let uit = Json.lees(gegevens)
    if let http = antwoord as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        let reden = uit["fout"].tekst
        throw Uitleesfout(bericht: reden.isEmpty ? "HTTP \(http.statusCode)" : reden,
                          vanServer: !reden.isEmpty)
    }
    return uit.isNiets ? .boek(["type": .tekst("niets")]) : uit
}

// Wat er terugkomt is van buiten. Het wordt hier meteen hetzelfde ding als de
// rest van de app kent: wekelijks of niet, taak of niet.
private let SOORTEN = ["bijzonderheid", "stap", "weekritme"]

func schoonVoorstel(_ ruw: Json, _ mensen: [Persoon]) -> Voorstel? {
    let gevraagd = ruw["soort"].tekst
    let soort = SOORTEN.contains(gevraagd) ? gevraagd : "bijzonderheid"
    let bekend = Set(mensen.map { $0.id })
    let datum = isDatum(ruw["datum"].tekst) ? ruw["datum"].tekst : ""

    var ding = Ding()
    ding.icoon = ruw["icoon"].tekst(soort == "stap" ? "⭐" : "🎉")
    ding.tekst = ruw["tekst"].tekst.isEmpty ? ruw["label"].tekst : ruw["tekst"].tekst
    ding.wekelijks = soort == "weekritme"
    ding.taak = soort == "stap"
    ding.tijd = ruw["tijd"].tekst
    ding.tot = ruw["tot"].tekst
    ding.datum = datum
    ding.dagen = dagenVan(ruw["dagen"])
    ding.wie = ruw["wie"].lijst.map { $0.tekst }.filter { bekend.contains($0) }
    ding.ritme = ruw["ritme"].tekst == "nacht" ? .nacht : .dag
    ding.groep = ruw["groep"].tekst

    if ding.tekst.isEmpty { return nil }
    // Wat elke week terugkomt heeft dagen in plaats van een datum; leeg betekent
    // daar elke dag, dus dat mag.
    guard ding.wekelijks || !ding.datum.isEmpty else { return nil }
    return Voorstel(ding: ding, bron: String(ruw["bron"].tekst.prefix(200)))
}

// Hetzelfde bericht twee keer plakken hoort niets dubbels op te leveren.
private func dingSleutel(_ tekst: String, _ datum: String, _ dagen: [String], _ wie: [String]) -> String {
    [tekst.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
     datum.trimmingCharacters(in: .whitespacesAndNewlines),
     dagenVan(dagen).joined(separator: "+"),
     wie.joined(separator: "+")].joined(separator: "|")
}

func alBekend(_ bron: Ruw, _ g: Ding) -> Bool {
    let sleutel = dingSleutel(g.tekst, g.datum, g.dagen, g.wie)
    if g.taak {
        return bron[g.ritme].contains { groep in
            groep.stappen.contains {
                dingSleutel($0.label, $0.datum, $0.dagen, $0.wie) == sleutel
            }
        }
    }
    if g.wekelijks {
        return bron.overzicht.contains {
            dingSleutel($0.tekst, "", $0.dagen, $0.wie) == sleutel
        }
    }
    return bron.events.contains {
        dingSleutel($0.tekst, $0.datum, [], $0.wie) == sleutel
    }
}
