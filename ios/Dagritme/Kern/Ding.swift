// Alles in deze app is hetzelfde ding met twee schakelaars: herhaalt het zich of
// geldt het één dag, en is het een taak of iets voor de agenda. Die vier
// combinaties zijn precies de vier plekken waar iets kan staan:
//
//            herhalen             één keer
//   agenda   weekritme            een regel bij Vandaag
//   taak     stap met dagen       stap met een datum
//
// Eén formulier dus, en elk scherm opent het met een andere beginstand.
import Foundation

struct Ding {
    var icoon: String = "📅"
    var tekst: String = ""
    var wekelijks: Bool = true
    var taak: Bool = false
    var dagen: [String] = []
    var datum: String = datumVan(Date())
    var tijd: String = ""
    var tot: String = ""
    var wie: [String] = []
    var ritme: Ritme = .dag
    var groep: String = ""
    var avond: Bool = false
}

// Waar iets staat, in één beschrijving: 'overzicht' en 'event' wijzen een regel
// aan, 'stap' een kaartje in een onderdeel.
enum Plek {
    case overzicht(RuwItem)
    case event(RuwEvent)
    case stap(ritme: Ritme, groep: RuwGroep, stap: RuwStap)
}

// Waar het vandaan kwam, zodat het op dezelfde plek in de lijst terug kan;
// anders springt alles wat je bewerkt naar onderen.
enum Vanaf {
    case stap(groep: RuwGroep, index: Int)
    case event(index: Int)
    case overzicht(index: Int)
}

func eersteGroepnaam(_ bron: Ruw, _ ritme: Ritme) -> String {
    let groepen = bron[ritme].filter { !$0.groep.trimmingCharacters(in: .whitespaces).isEmpty }
    return groepen.last?.groep.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func dingVan(_ bron: Ruw, _ plek: Plek?) -> Ding {
    var leeg = Ding()
    leeg.groep = eersteGroepnaam(bron, .dag)
    guard let plek else { return leeg }

    switch plek {
    case let .stap(ritme, groep, stap):
        var uit = leeg
        uit.icoon = stap.icoon
        uit.tekst = stap.label
        uit.taak = true
        uit.wekelijks = !isDatum(stap.datum)
        uit.dagen = stap.dagen
        uit.datum = isDatum(stap.datum) ? stap.datum : leeg.datum
        uit.wie = stap.wie
        uit.ritme = ritme
        uit.groep = groep.groep.trimmingCharacters(in: .whitespacesAndNewlines)
        return uit

    case let .overzicht(item):
        var uit = leeg
        uit.icoon = item.icoon
        uit.tekst = item.tekst
        uit.taak = false
        uit.wekelijks = true
        uit.dagen = item.dagen
        uit.tijd = item.tijd
        uit.tot = item.tot
        uit.wie = item.wie
        uit.avond = item.avond
        return uit

    case let .event(item):
        var uit = leeg
        uit.icoon = item.icoon
        uit.tekst = item.tekst
        uit.taak = false
        uit.wekelijks = false
        uit.datum = isDatum(item.datum) ? item.datum : leeg.datum
        uit.tijd = item.tijd
        uit.tot = item.tot
        uit.wie = item.wie
        return uit
    }
}

@discardableResult
func haalDingWeg(_ bron: Ruw, _ plek: Plek?) -> Vanaf? {
    guard let plek else { return nil }
    switch plek {
    case let .stap(ritme, _, stap):
        var vanaf: Vanaf?
        // De groepen zijn verwijzingen, dus wat hier weggehaald wordt is
        // meteen weg in het concept zelf.
        for groep in bron[ritme] {
            if let i = groep.stappen.firstIndex(where: { $0 === stap }) {
                vanaf = .stap(groep: groep, index: i)
                groep.stappen.remove(at: i)
            }
        }
        return vanaf

    case let .event(item):
        let i = bron.events.firstIndex { $0.id == item.id }
        bron.events.removeAll { $0.id == item.id }
        return i.map { .event(index: $0) }

    case let .overzicht(item):
        let i = bron.overzicht.firstIndex { $0 === item }
        bron.overzicht.removeAll { $0 === item }
        return i.map { .overzicht(index: $0) }
    }
}

// Terug op zijn oude plek als het in dezelfde lijst blijft, anders achteraan.
private func voegIn<T>(_ lijst: inout [T], _ nieuw: T, _ index: Int?) {
    if let index { lijst.insert(nieuw, at: min(index, lijst.count)) } else { lijst.append(nieuw) }
}

func zetDingNeer(_ bron: Ruw, _ g: Ding, _ id: String, _ vanaf: Vanaf?) {
    let naam = { (t: String) in t.trimmingCharacters(in: .whitespacesAndNewlines) }

    if g.taak {
        var groepen = bron[g.ritme]
        var doel = groepen.first { naam($0.groep) == naam(g.groep) } ?? groepen.last
        if doel == nil {
            let verse = RuwGroep(groep: naam(g.groep).isEmpty ? "Erbij" : naam(g.groep),
                                 tijd: "", stappen: [])
            groepen.append(verse)
            doel = verse
        }
        bron[g.ritme] = groepen
        guard let doel else { return }
        var plaats: Int?
        if case let .stap(groep, index) = vanaf, groep === doel { plaats = index }
        voegIn(&doel.stappen, RuwStap(
            icoon: naam(g.icoon).isEmpty ? "⭐" : naam(g.icoon),
            label: naam(g.tekst),
            dagen: g.wekelijks ? dagenVan(g.dagen) : [],
            datum: g.wekelijks ? "" : naam(g.datum),
            wie: g.wie
        ), plaats)
        return
    }

    if g.wekelijks {
        var plaats: Int?
        if case let .overzicht(index) = vanaf { plaats = index }
        voegIn(&bron.overzicht, RuwItem(
            icoon: naam(g.icoon).isEmpty ? "📅" : naam(g.icoon),
            tekst: naam(g.tekst),
            tijd: naam(g.tijd),
            tot: naam(g.tot),
            dagen: dagenVan(g.dagen),
            wie: g.wie,
            avond: g.avond
        ), plaats)
        return
    }

    var plaats: Int?
    if case let .event(index) = vanaf { plaats = index }
    voegIn(&bron.events, RuwEvent(
        id: id.isEmpty ? nieuwId() : id,
        icoon: naam(g.icoon).isEmpty ? "🎉" : naam(g.icoon),
        tekst: naam(g.tekst),
        tijd: naam(g.tijd),
        tot: naam(g.tot),
        datum: naam(g.datum),
        wie: g.wie
    ), plaats)
}

// Eerst weghalen waar het stond, dan neerzetten waar het nu hoort. Zo is een
// weekregel die een kaartje wordt gewoon één beweging.
func verplaatsDing(_ bron: Ruw, _ plek: Plek?, _ g: Ding) -> String? {
    if g.tekst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "Vul een naam in."
    }
    if !g.wekelijks && !isDatum(g.datum) {
        return "Vul een datum in, of zet hem op herhalen."
    }
    var id = nieuwId()
    if case let .event(item) = plek { id = item.id }
    let vanaf = haalDingWeg(bron, plek)
    zetDingNeer(bron, g, id, vanaf)
    return nil
}
