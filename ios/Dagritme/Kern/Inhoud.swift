// Dezelfde vorm als de web- en react native-versie: alles wat uit het huis komt
// wordt hier eerst gladgestreken, zodat de schermen niets meer hoeven te
// controleren.
import Foundation

let DAGEN = ["zo", "ma", "di", "wo", "do", "vr", "za"]
let KLEUREN = ["#2FA37C", "#7C6BD6", "#D9724F", "#3B82C4", "#C2417E", "#E0A33E"]
let DAGNAMEN = ["zondag", "maandag", "dinsdag", "woensdag", "donderdag", "vrijdag", "zaterdag"]
let WEEKDAGEN = ["ma", "di", "wo", "do", "vr", "za", "zo"]
let DAGLETTERS = ["ma": "M", "di": "D", "wo": "W", "do": "D", "vr": "V", "za": "Z", "zo": "Z"]
let MAANDEN = ["januari", "februari", "maart", "april", "mei", "juni", "juli",
               "augustus", "september", "oktober", "november", "december"]

// De kalender staat op de tijdzone van de telefoon: een dag begint hier waar de
// kinderen wakker worden, niet in Greenwich.
let kalender = Calendar.current

// Zondag is 0, net als in javascript, zodat DAGEN klopt.
func dagnummer(_ d: Date) -> Int {
    kalender.component(.weekday, from: d) - 1
}

func datumVan(_ d: Date) -> String {
    let delen = kalender.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", delen.year ?? 0, delen.month ?? 0, delen.day ?? 0)
}

func datumTekst(_ d: Date) -> String {
    let delen = kalender.dateComponents([.month, .day], from: d)
    return "\(DAGNAMEN[dagnummer(d)]) \(delen.day ?? 0) \(MAANDEN[(delen.month ?? 1) - 1])"
}

// De week waar een dag in valt, met maandag vooraan.
func weekVan(_ d: Date, _ weken: Int = 0) -> [Date] {
    let verschuiving = -((dagnummer(d) + 6) % 7) + weken * 7
    let begin = kalender.startOfDay(for: kalender.date(byAdding: .day, value: verschuiving, to: d) ?? d)
    return (0..<7).map { kalender.date(byAdding: .day, value: $0, to: begin) ?? begin }
}

// ------------------------------------------------------------- gladstrijken ---

// Alleen paren waar allebei de kanten iets zeggen tellen mee.
func kenmerkenVan(_ waarde: Json) -> [String: String] {
    var uit: [String: String] = [:]
    for sleutel in waarde.sleutels {
        let naam = sleutel.trimmingCharacters(in: .whitespacesAndNewlines)
        let inhoud = waarde[sleutel].tekst
        if !naam.isEmpty && !inhoud.isEmpty { uit[naam] = inhoud }
    }
    return uit
}

func dagenVan(_ waarde: Json) -> [String] {
    waarde.lijst
        .map { String($0.tekst.lowercased().prefix(2)) }
        .filter { DAGEN.contains($0) }
}

// 'wie' leeg betekent iedereen; oudere gegevens gebruikten één 'persoon'.
func wieVan(_ item: Json) -> [String] {
    var uit = item["wie"].lijst.map { $0.tekst }.filter { !$0.isEmpty }
    let enkel = item["persoon"].tekst
    if uit.isEmpty && !enkel.isEmpty { uit.append(enkel) }
    return uit
}

private func isDatumtekst(_ waarde: String) -> Bool {
    waarde.wholeMatch(patroon: "\\d{4}-\\d{2}-\\d{2}")
}

private func maakGroepen(_ waarde: Json) -> [Groep] {
    let lijst = waarde.lijst
    if lijst.isEmpty { return [] }
    // Zonder groepen eromheen is het één lijst met stappen; die krijgt er hier
    // alsnog een naamloze groep omheen.
    let gegroepeerd = lijst.contains { !$0["stappen"].isNiets || !$0["groep"].isNiets }
    let rauw: [Json] = gegroepeerd
        ? lijst
        : [.boek(["groep": .tekst(""), "tijd": .tekst(""), "stappen": .lijst(lijst)])]
    return rauw.map { item in
        Groep(
            groep: item["groep"].tekst,
            tijd: item["tijd"].tekst,
            stappen: item["stappen"].lijst.map { s in
                Stap(
                    icoon: s["icoon"].tekst("⭐"),
                    label: s["label"].tekst,
                    dagen: dagenVan(s["dagen"]),
                    datum: isDatumtekst(s["datum"].tekst) ? s["datum"].tekst : "",
                    wie: wieVan(s)
                )
            }
        )
    }
}

// Een tijd bestaat uit een begin en een eind, allebei optioneel. Stond er
// vroeger één veld met '8:00 - 8:15' in, dan gaat dat hier alsnog uit elkaar.
private func tijden(_ ruw: Json) -> (tijd: String, tot: String) {
    var tijd = ruw["tijd"].tekst
    var tot = ruw["tot"].tekst
    if tot.isEmpty,
       let delen = tijd.eersteVangst(patroon: "^(.*?)\\s*(?:–|—|-|tot|t/m)\\s*(.+)$"),
       delen.count == 3,
       uurUitTijd(delen[1]) != nil, uurUitTijd(delen[2]) != nil {
        tijd = delen[1].trimmingCharacters(in: .whitespaces)
        tot = delen[2].trimmingCharacters(in: .whitespaces)
    }
    return (tijd, tot)
}

// De tijd zoals je hem opschrijft — '19:30', '8.00 - 8.15', '15u' — als aantal
// minuten na middernacht. Staat er geen aantal minuten bij, dan is het het hele
// uur.
func minuutUitTijd(_ waarde: String) -> Int? {
    let t = waarde.trimmingCharacters(in: .whitespacesAndNewlines)
    let vangst = t.eersteVangst(patroon: "(\\d{1,2})\\s*[:.uh]\\s*(\\d{2})?")
        ?? t.eersteVangst(patroon: "^\\s*(\\d{1,2})\\s*$")
    guard let delen = vangst, let uur = Int(delen[1]), (0...23).contains(uur) else { return nil }
    let min = delen.count > 2 ? (Int(delen[2]) ?? 0) : 0
    return uur * 60 + ((0...59).contains(min) ? min : 0)
}

// Het uur eruit, voor wie alleen wil weten of iets voor of na de avond valt.
func uurUitTijd(_ waarde: String) -> Int? {
    minuutUitTijd(waarde).map { $0 / 60 }
}

// Hoe laat het is, in dezelfde eenheid.
func minuutVanDeDag(_ d: Date) -> Int {
    let delen = kalender.dateComponents([.hour, .minute], from: d)
    return (delen.hour ?? 0) * 60 + (delen.minute ?? 0)
}

extension Agendaitem {
    /// Wanneer dit begint. Niets betekent: het geldt de hele dag.
    var begintOm: Int? { minuutUitTijd(tijd) ?? minuutUitTijd(tot) }

    /// Wanneer dit voorbij is. Staat er een eindtijd, dan telt die: een wedstrijd
    /// van 15:45 tot 16:45 is om vier uur nog bezig.
    var eindigtOm: Int? { minuutUitTijd(tot) ?? minuutUitTijd(tijd) }
}

// De begintijd beslist of iets bij Overdag of bij Vanavond hoort; staat alleen
// de eindtijd er, dan telt die. Zonder tijd telt nog wat er ooit is aangevinkt.
func isAvond(tijd: String, tot: String, avond: Bool, vanaf: Int) -> Bool {
    guard let uur = uurUitTijd(tijd) ?? uurUitTijd(tot) else { return avond }
    return uur >= vanaf
}

func isAvond(_ item: Agendaitem, _ vanaf: Int) -> Bool {
    isAvond(tijd: item.tijd, tot: item.tot, avond: item.avond, vanaf: vanaf)
}

func tijdTekst(tijd: String, tot: String) -> String {
    if !tijd.isEmpty && !tot.isEmpty { return "\(tijd) – \(tot)" }
    if !tot.isEmpty { return "tot " + tot }
    return tijd
}

func tijdTekst(_ item: Agendaitem) -> String { tijdTekst(tijd: item.tijd, tot: item.tot) }

private func weekitem(_ ruw: Json) -> Weekitem {
    let klok = tijden(ruw)
    return Weekitem(
        icoon: ruw["icoon"].tekst("📅"),
        tekst: ruw["tekst"].tekst,
        tijd: klok.tijd,
        tot: klok.tot,
        dagen: dagenVan(ruw["dagen"]),
        wie: wieVan(ruw),
        avond: ruw["avond"].vlag
    )
}

// Het overzicht stond vroeger per dag ingevuld, waardoor school vijf keer in de
// database stond; zo'n oude tak wordt hier samengevoegd.
private func overzichtLijst(_ waarde: Json) -> [Weekitem] {
    let plat = { waarde.lijst.map(weekitem).filter { !$0.tekst.isEmpty } }
    guard waarde.isBoek, !waarde.isLijst else { return plat() }
    let sleutels = waarde.sleutels
    let perDag = !sleutels.isEmpty && sleutels.allSatisfy {
        DAGEN.contains(String($0.trimmingCharacters(in: .whitespaces).lowercased().prefix(2)))
    }
    if !perDag { return plat() }

    var uit: [Weekitem] = []
    var gezien: [String: Int] = [:]
    for dag in WEEKDAGEN {
        for ruw in waarde[dag].lijst {
            var item = weekitem(ruw)
            if item.tekst.isEmpty { continue }
            let sleutel = [item.icoon, item.tekst, item.tijd, item.tot,
                           item.wie.joined(separator: "+"), String(item.avond)].joined(separator: "|")
            if let eerder = gezien[sleutel] {
                uit[eerder].dagen.append(dag)
                continue
            }
            item.dagen = [dag]
            gezien[sleutel] = uit.count
            uit.append(item)
        }
    }
    for i in uit.indices where uit[i].dagen.count == 7 { uit[i].dagen = [] }
    return uit
}

private func eenmalig(_ ruw: Json) -> Eenmalig {
    let klok = tijden(ruw)
    return Eenmalig(
        id: ruw["id"].tekst.isEmpty ? nieuwId("e") : ruw["id"].tekst,
        icoon: ruw["icoon"].tekst("🎉"),
        tekst: ruw["tekst"].tekst,
        tijd: klok.tijd,
        tot: klok.tot,
        datum: isDatumtekst(ruw["datum"].tekst) ? ruw["datum"].tekst : "",
        wie: wieVan(ruw)
    )
}

func normaliseer(_ ruw: Json) -> Inhoud {
    let mensen = ruw["mensen"].lijst.enumerated().map { (i, p) in
        Persoon(
            id: p["id"].tekst("p\(i)"),
            naam: p["naam"].tekst("Naamloos"),
            emoji: p["emoji"].tekst("🙂"),
            kleur: p["kleur"].tekst(KLEUREN[i % KLEUREN.count]),
            kenmerken: kenmerkenVan(p["kenmerken"])
        )
    }
    var uit = Inhoud(
        titel: ruw["titel"].tekst("Ons dagritme"),
        avondVanaf: ruw["avondVanaf"].getal.map { Int(floor($0)) } ?? 15,
        mensen: mensen,
        dag: maakGroepen(ruw["dag"]),
        nacht: maakGroepen(ruw["nacht"]),
        overzicht: overzichtLijst(ruw["overzicht"]),
        events: ruw["events"].lijst.map(eenmalig)
            .filter { !$0.tekst.isEmpty && !$0.datum.isEmpty }
            .sorted { ($0.datum, $0.tijd) < ($1.datum, $1.tijd) }
    )
    // Een vinkje van een kind dat er niet meer is hoort nergens meer bij.
    let bestaat = Set(mensen.map { $0.id })
    let schoon = { (wie: [String]) in wie.filter { bestaat.contains($0) } }
    for ritme in [Ritme.dag, .nacht] {
        var groepen = uit[ritme]
        for g in groepen.indices {
            for s in groepen[g].stappen.indices {
                groepen[g].stappen[s].wie = schoon(groepen[g].stappen[s].wie)
            }
        }
        uit[ritme] = groepen
    }
    for i in uit.overzicht.indices { uit.overzicht[i].wie = schoon(uit.overzicht[i].wie) }
    for i in uit.events.indices { uit.events[i].wie = schoon(uit.events[i].wie) }
    return uit
}

// ------------------------------------------------------------ wat er die dag is ---

// Eerst het bijzondere, daaronder het vaste weekritme.
func itemsVan(_ inhoud: Inhoud, _ d: Date) -> [Agendaitem] {
    let dag = DAGEN[dagnummer(d)]
    let datum = datumVan(d)
    let bijzonder = inhoud.events.filter { $0.datum == datum }.map { Agendaitem(eenmalig: $0) }
    let week = inhoud.overzicht
        .filter { $0.dagen.isEmpty || $0.dagen.contains(dag) }
        .map { Agendaitem(week: $0) }
    return bijzonder + week
}

// 's Ochtends wat er vandaag is; 's avonds wat er vanavond nog komt en wat
// morgen wacht.
//
// Wat vandaag speelt staat op tijd en valt weg zodra het geweest is: naast een
// ritme dat je afwerkt wil je zien wat er nog komt, niet wat er is geweest.
// Morgen blijft compleet — daar is nog niets voorbij.
func ritmeBlokken(_ inhoud: Inhoud, _ ritme: Ritme, _ nu: Date) -> [Blok] {
    let klok = minuutVanDeDag(nu)
    let overdag = { (d: Date) in itemsVan(inhoud, d).filter { !isAvond($0, inhoud.avondVanaf) } }

    if ritme != .nacht {
        return [Blok(kop: "Vandaag", items: opTijd(overdag(nu), voorbij: klok))]
    }
    let morgen = kalender.date(byAdding: .day, value: 1, to: nu) ?? nu
    return [
        Blok(kop: "Vanavond",
             items: opTijd(itemsVan(inhoud, nu).filter { isAvond($0, inhoud.avondVanaf) },
                           voorbij: klok)),
        Blok(kop: "Morgen", items: opTijd(overdag(morgen), voorbij: nil), later: true),
    ]
}

/// Op tijd, met wat geen tijd heeft bovenaan — dat geldt de hele dag, dus daar
/// begin je mee. Staat `voorbij` op de klok van nu, dan valt weg wat toen al
/// afgelopen was; iets zonder tijd blijft altijd staan, want daar is niets van
/// te zeggen.
///
/// Het volgnummer telt mee bij gelijke tijden, zodat twee dingen om 13:00 niet
/// elke keer van plek wisselen — `sorted` in Swift belooft dat zelf niet.
func opTijd(_ items: [Agendaitem], voorbij klok: Int?) -> [Agendaitem] {
    items
        .filter { item in
            guard let klok, let eind = item.eindigtOm else { return true }
            return eind > klok
        }
        .enumerated()
        .sorted { links, rechts in
            switch (links.element.begintOm, rechts.element.begintOm) {
            case let (l?, r?): return l == r ? links.offset < rechts.offset : l < r
            case (nil, .some): return true
            case (.some, nil): return false
            case (nil, nil): return links.offset < rechts.offset
            }
        }
        .map(\.element)
}

// De sleutel waaronder een vinkje in het huis staat: aan de tekst van de stap,
// niet aan het volgnummer, zodat er een stap tussen kan.
func stapSleutel(_ stap: Stap) -> String {
    let plat = stap.label.lowercased()
        .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "nl_NL"))
    var uit = ""
    var streepje = false
    for teken in plat.unicodeScalars {
        if CharacterSet.alphanumerics.contains(teken), teken.isASCII {
            if streepje && !uit.isEmpty { uit.append("-") }
            streepje = false
            uit.unicodeScalars.append(teken)
        } else {
            streepje = true
        }
    }
    return uit.isEmpty ? "stap" : uit
}

func opDeze(_ stap: Stap, _ d: Date) -> Bool {
    if !stap.datum.isEmpty { return stap.datum == datumVan(d) }
    if stap.dagen.isEmpty { return true }
    return stap.dagen.contains(DAGEN[dagnummer(d)])
}

func aantalStappen(_ groepen: [Groep]) -> Int {
    groepen.reduce(0) { $0 + $1.stappen.count }
}

// Op datum, want zo kijk je ernaar — niet per lijst waar het toevallig in
// bewaard wordt.
func eenmaligeDingen(_ inhoud: Inhoud) -> [EenmaligDing] {
    var uit: [EenmaligDing] = inhoud.events
        .filter { !$0.datum.isEmpty }
        .map { .event(datum: $0.datum, item: $0) }
    for ritme in [Ritme.dag, .nacht] {
        for groep in inhoud[ritme] {
            for stap in groep.stappen where !stap.datum.isEmpty {
                uit.append(.stap(datum: stap.datum, ritme: ritme, groep: groep, stap: stap))
            }
        }
    }
    return uit.sorted { a, b in
        if a.datum != b.datum { return a.datum < b.datum }
        let tijdVan = { (d: EenmaligDing) -> String in
            if case let .event(_, item) = d { return item.tijd }
            return ""
        }
        return tijdVan(a) < tijdVan(b)
    }
}

func wieDoetMee(_ stap: Stap, _ mensen: [Persoon]) -> [Persoon] {
    stap.wie.isEmpty ? mensen : mensen.filter { stap.wie.contains($0.id) }
}

// ------------------------------------------------------------------ gereedschap ---

func nieuwId(_ voorvoegsel: String = "p") -> String {
    voorvoegsel + String(UUID().uuidString.lowercased().prefix(6))
}

extension String {
    // Eén plek waar met NSRegularExpression wordt omgegaan, zodat de rest van
    // de code eruitziet als de javascript-versie.
    func eersteVangst(patroon: String) -> [String]? {
        guard let regel = try? NSRegularExpression(pattern: patroon, options: [.caseInsensitive]),
              let treffer = regel.firstMatch(in: self, range: NSRange(startIndex..., in: self))
        else { return nil }
        return (0..<treffer.numberOfRanges).map { i in
            guard let bereik = Range(treffer.range(at: i), in: self) else { return "" }
            return String(self[bereik])
        }
    }

    func wholeMatch(patroon: String) -> Bool {
        guard let regel = try? NSRegularExpression(pattern: "^(?:" + patroon + ")$"),
              let treffer = regel.firstMatch(in: self, range: NSRange(startIndex..., in: self))
        else { return false }
        return treffer.range.length == (self as NSString).length
    }
}
