// Van en naar de vorm waarin het in het huis staat. Een bewerkscherm werkt op
// een losse kopie — het concept — en pas bij Gereed gaat die er opgeschoond in.
//
// Dat concept bestaat hier uit klassen en niet uit structs, met opzet: het
// formulier moet een regel kunnen aanwijzen ("deze stap, in deze groep") en hem
// daarna ergens anders neerzetten. Met waarden zou dat een lijst met
// volgnummers worden die bij elke wijziging verschuiven; met verwijzingen blijft
// het gewoon dat ene ding.
import Foundation

final class RuwPersoon: Identifiable {
    var id: String
    var naam: String
    var emoji: String
    var kleur: String
    var kenmerken: [String: String]

    init(id: String, naam: String, emoji: String, kleur: String, kenmerken: [String: String]) {
        self.id = id
        self.naam = naam
        self.emoji = emoji
        self.kleur = kleur
        self.kenmerken = kenmerken
    }
}

final class RuwStap: Identifiable {
    var icoon: String
    var label: String
    var dagen: [String]
    var datum: String
    var wie: [String]

    init(icoon: String, label: String, dagen: [String], datum: String, wie: [String]) {
        self.icoon = icoon
        self.label = label
        self.dagen = dagen
        self.datum = datum
        self.wie = wie
    }
}

final class RuwGroep: Identifiable {
    var groep: String
    var tijd: String
    var stappen: [RuwStap]

    init(groep: String, tijd: String, stappen: [RuwStap]) {
        self.groep = groep
        self.tijd = tijd
        self.stappen = stappen
    }
}

final class RuwItem: Identifiable {
    var icoon: String
    var tekst: String
    var tijd: String
    var tot: String
    var dagen: [String]
    var wie: [String]
    var avond: Bool

    init(icoon: String, tekst: String, tijd: String, tot: String,
         dagen: [String], wie: [String], avond: Bool) {
        self.icoon = icoon
        self.tekst = tekst
        self.tijd = tijd
        self.tot = tot
        self.dagen = dagen
        self.wie = wie
        self.avond = avond
    }
}

final class RuwEvent: Identifiable {
    var id: String
    var icoon: String
    var tekst: String
    var tijd: String
    var tot: String
    var datum: String
    var wie: [String]

    init(id: String, icoon: String, tekst: String, tijd: String, tot: String,
         datum: String, wie: [String]) {
        self.id = id
        self.icoon = icoon
        self.tekst = tekst
        self.tijd = tijd
        self.tot = tot
        self.datum = datum
        self.wie = wie
    }
}

final class Ruw {
    var titel: String
    var mensen: [RuwPersoon]
    var dag: [RuwGroep]
    var nacht: [RuwGroep]
    var overzicht: [RuwItem]
    var events: [RuwEvent]

    init(titel: String, mensen: [RuwPersoon], dag: [RuwGroep],
         nacht: [RuwGroep], overzicht: [RuwItem], events: [RuwEvent]) {
        self.titel = titel
        self.mensen = mensen
        self.dag = dag
        self.nacht = nacht
        self.overzicht = overzicht
        self.events = events
    }

    subscript(ritme: Ritme) -> [RuwGroep] {
        get { ritme == .dag ? dag : nacht }
        set { if ritme == .dag { dag = newValue } else { nacht = newValue } }
    }

}

// ------------------------------------------------------------------- datums ---

func isDatum(_ waarde: String) -> Bool {
    waarde.wholeMatch(patroon: "\\d{4}-\\d{2}-\\d{2}")
}

func alsDatum(_ waarde: String) -> Date? {
    guard isDatum(waarde) else { return nil }
    let delen = waarde.split(separator: "-").compactMap { Int($0) }
    guard delen.count == 3 else { return nil }
    var stuk = DateComponents()
    stuk.year = delen[0]
    stuk.month = delen[1]
    stuk.day = delen[2]
    return kalender.date(from: stuk)
}

func kortDatum(_ waarde: String) -> String {
    guard let d = alsDatum(waarde) else { return "" }
    let delen = kalender.dateComponents([.month, .day], from: d)
    let dag = WEEKDAGEN[(dagnummer(d) + 6) % 7]
    return "\(dag) \(delen.day ?? 0) \(MAANDEN[(delen.month ?? 1) - 1].prefix(3))"
}

// 'ma, di, wo, do, vr' is een rijtje dat je moet lezen; 'weekdagen' is een woord
// dat je herkent. Alleen bij precies die vijf, en bij precies za en zo — een
// bijna-week blijft gewoon zijn dagen opnoemen, want daar zit de uitzondering in
// en die wil je juist zien.
func dagenTekst(_ dagen: [String]) -> String {
    if dagen.isEmpty || dagen.count >= WEEKDAGEN.count { return "" }
    let gekozen = Set(dagen)
    if gekozen == DOORDEWEEKS { return "weekdagen" }
    if gekozen == WEEKEND { return "weekend" }
    return WEEKDAGEN.filter { gekozen.contains($0) }.joined(separator: ", ")
}

func dagenVan(_ waarde: [String]) -> [String] {
    waarde
        .map { String($0.trimmingCharacters(in: .whitespaces).lowercased().prefix(2)) }
        .filter { DAGEN.contains($0) }
}

// De begintijd beslist; staat alleen de eindtijd er, dan telt die.
func naAvond(tijd: String, tot: String, avond: Bool, vanaf: Int) -> Bool {
    isAvond(tijd: tijd, tot: tot, avond: avond, vanaf: vanaf)
}

func uurOf(_ waarde: String, _ terugval: Int) -> Int {
    guard let n = Double(waarde.trimmingCharacters(in: .whitespaces)) else { return terugval }
    let uur = Int(floor(n))
    return (0...23).contains(uur) ? uur : terugval
}

// ------------------------------------------------- een losse kopie om in te bewerken ---

func alsRuw(_ inhoud: Inhoud) -> Ruw {
    Ruw(
        titel: inhoud.titel,
        mensen: inhoud.mensen.map {
            RuwPersoon(id: $0.id, naam: $0.naam, emoji: $0.emoji, kleur: $0.kleur,
                       kenmerken: $0.kenmerken)
        },
        dag: inhoud.dag.map(ruwGroep),
        nacht: inhoud.nacht.map(ruwGroep),
        overzicht: inhoud.overzicht.map {
            RuwItem(icoon: $0.icoon, tekst: $0.tekst, tijd: $0.tijd, tot: $0.tot,
                    dagen: $0.dagen, wie: $0.wie, avond: $0.avond)
        },
        events: inhoud.events.map {
            RuwEvent(id: $0.id, icoon: $0.icoon, tekst: $0.tekst, tijd: $0.tijd,
                     tot: $0.tot, datum: $0.datum, wie: $0.wie)
        }
    )
}

private func ruwGroep(_ groep: Groep) -> RuwGroep {
    RuwGroep(groep: groep.groep, tijd: groep.tijd, stappen: groep.stappen.map {
        RuwStap(icoon: $0.icoon, label: $0.label, dagen: $0.dagen, datum: $0.datum, wie: $0.wie)
    })
}

// ---------------------------------------------------------------- opschonen ---

private func schoneGroepen(_ lijst: [RuwGroep]) -> [[String: Any]] {
    lijst.map { g -> [String: Any] in
        let stappen: [[String: Any]] = g.stappen
            .filter { !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { s in
                var uit: [String: Any] = [
                    "icoon": s.icoon.isEmpty ? "⭐" : s.icoon,
                    "label": s.label.trimmingCharacters(in: .whitespacesAndNewlines),
                ]
                if isDatum(s.datum) { uit["datum"] = s.datum }
                let dagen = dagenVan(s.dagen)
                if !dagen.isEmpty && uit["datum"] == nil { uit["dagen"] = dagen }
                if !s.wie.isEmpty { uit["wie"] = s.wie }
                return uit
            }
        return [
            "groep": g.groep.trimmingCharacters(in: .whitespacesAndNewlines),
            "tijd": g.tijd.trimmingCharacters(in: .whitespacesAndNewlines),
            "stappen": stappen,
        ]
    }.filter { g in
        let stappen = g["stappen"] as? [[String: Any]] ?? []
        let naam = g["groep"] as? String ?? ""
        return !stappen.isEmpty || !naam.isEmpty
    }
}

private func schoonOverzicht(_ bron: [RuwItem], _ vanaf: Int) -> [[String: Any]] {
    bron
        .filter { !$0.tekst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map { item in
            var uit: [String: Any] = [
                "icoon": item.icoon.isEmpty ? "📅" : item.icoon,
                "tekst": item.tekst.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            let tijd = item.tijd.trimmingCharacters(in: .whitespacesAndNewlines)
            let tot = item.tot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tijd.isEmpty { uit["tijd"] = tijd }
            if !tot.isEmpty { uit["tot"] = tot }
            let dagen = dagenVan(item.dagen)
            if !dagen.isEmpty && dagen.count < WEEKDAGEN.count { uit["dagen"] = dagen }
            if !item.wie.isEmpty { uit["wie"] = item.wie }
            if naAvond(tijd: tijd, tot: tot, avond: item.avond, vanaf: vanaf) { uit["avond"] = true }
            return uit
        }
}

// Wat geweest is ruimt zichzelf op: een bijzonderheid van gisteren gaat er bij
// het eerstvolgende bewaren uit.
private func schoonEvents(_ bron: [RuwEvent]) -> [[String: Any]] {
    let grens = datumVan(Date())
    return bron
        .filter { !$0.tekst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isDatum($0.datum) }
        .filter { $0.datum >= grens }
        .map { e in
            var uit: [String: Any] = [
                "id": e.id.isEmpty ? nieuwId() : e.id,
                "icoon": e.icoon.isEmpty ? "🎉" : e.icoon,
                "tekst": e.tekst.trimmingCharacters(in: .whitespacesAndNewlines),
                "datum": e.datum,
            ]
            let tijd = e.tijd.trimmingCharacters(in: .whitespacesAndNewlines)
            let tot = e.tot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tijd.isEmpty { uit["tijd"] = tijd }
            if !tot.isEmpty { uit["tot"] = tot }
            if !e.wie.isEmpty { uit["wie"] = e.wie }
            return uit
        }
}

func opgeschoond(_ c: Ruw) -> [String: Any] {
    let vanaf = AVONDVANAF
    let titel = c.titel.trimmingCharacters(in: .whitespacesAndNewlines)
    return [
        "titel": titel.isEmpty ? "Ons dagritme" : titel,
        "avondVanaf": vanaf,
        "mensen": c.mensen.enumerated().map { (i, p) -> [String: Any] in
            [
                "id": p.id.isEmpty ? nieuwId() : p.id,
                "naam": p.naam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Naamloos" : p.naam.trimmingCharacters(in: .whitespacesAndNewlines),
                "emoji": p.emoji.isEmpty ? "🙂" : p.emoji,
                "kleur": p.kleur.isEmpty ? KLEUREN[i % KLEUREN.count] : p.kleur,
                "kenmerken": p.kenmerken,
            ]
        },
        "dag": schoneGroepen(c.dag),
        "nacht": schoneGroepen(c.nacht),
        "overzicht": schoonOverzicht(c.overzicht, vanaf),
        "events": schoonEvents(c.events),
    ]
}

// Wat er na het opschonen overblijft, om te kunnen controleren of er nog een
// kind en een stap in zitten voordat het de deur uit gaat.
func telStappen(_ groepen: [[String: Any]]) -> Int {
    groepen.reduce(0) { $0 + (($1["stappen"] as? [[String: Any]])?.count ?? 0) }
}

extension Array {
    /// Verzet het ding op `van` naar plek `naar`. Na het weghalen schuift alles
    /// erachter een plek op, en juist daardoor klopt `insert(at: naar)` allebei
    /// de kanten op.
    mutating func verzet(_ van: Int, _ naar: Int) {
        guard indices.contains(van), indices.contains(naar), van != naar else { return }
        let ding = remove(at: van)
        insert(ding, at: naar)
    }
}
