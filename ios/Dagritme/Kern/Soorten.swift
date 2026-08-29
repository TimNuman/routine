// Dezelfde soorten als in de react native-versie, met dezelfde namen: wat er in
// het huis staat en wat de schermen ervan te zien krijgen.
import Foundation

enum Ritme: String, Codable, Hashable {
    case dag
    case nacht
}

// kenmerken: wat een bericht van school of de club nodig heeft om bij het
// juiste kind uit te komen, bijvoorbeeld ["schoolgroep": "1-2B"].
struct Persoon: Identifiable, Hashable {
    var id: String
    var naam: String
    var emoji: String
    var kleur: String
    var kenmerken: [String: String]
}

struct Stap: Hashable {
    var icoon: String
    var label: String
    var dagen: [String]
    var datum: String
    var wie: [String]
}

struct Groep: Hashable {
    var groep: String
    var tijd: String
    var stappen: [Stap]
}

// Wat er die dag verder is: het vaste weekritme en de eenmalige dingen.
struct Weekitem: Hashable {
    var icoon: String
    var tekst: String
    var tijd: String
    var tot: String
    var dagen: [String]
    var wie: [String]
    var avond: Bool
}

struct Eenmalig: Identifiable, Hashable {
    var id: String
    var icoon: String
    var tekst: String
    var tijd: String
    var tot: String
    var datum: String
    var wie: [String]
}

// Eén regel in de agenda: uit het weekritme of uit de eenmalige dingen. Een
// eenmalige heeft een id en een datum, en krijgt het oranje randje.
struct Agendaitem: Hashable {
    var icoon: String
    var tekst: String
    var tijd: String
    var tot: String
    var dagen: [String]
    var wie: [String]
    var avond: Bool
    var id: String?
    var datum: String?
    var bijzonder: Bool

    init(week: Weekitem) {
        icoon = week.icoon
        tekst = week.tekst
        tijd = week.tijd
        tot = week.tot
        dagen = week.dagen
        wie = week.wie
        avond = week.avond
        id = nil
        datum = nil
        bijzonder = false
    }

    init(eenmalig: Eenmalig) {
        icoon = eenmalig.icoon
        tekst = eenmalig.tekst
        tijd = eenmalig.tijd
        tot = eenmalig.tot
        dagen = []
        wie = eenmalig.wie
        avond = false
        id = eenmalig.id
        datum = eenmalig.datum
        bijzonder = true
    }
}

struct Inhoud: Hashable {
    var titel: String
    var mensen: [Persoon]
    var dag: [Groep]
    var nacht: [Groep]
    var overzicht: [Weekitem]
    var events: [Eenmalig]

    subscript(ritme: Ritme) -> [Groep] {
        get { ritme == .dag ? dag : nacht }
        set { if ritme == .dag { dag = newValue } else { nacht = newValue } }
    }
}

// Een kop met wat eronder staat: Vandaag, Vanavond, Morgen, Overdag.
struct Blok: Identifiable {
    var kop: String
    var items: [Agendaitem]
    var later: Bool = false
    var id: String { kop }
}

// Alles wat op één datum staat, bij elkaar: het bijzondere uit de agenda en een
// stap die maar één ochtend meedoet.
enum EenmaligDing {
    case event(datum: String, item: Eenmalig)
    case stap(datum: String, ritme: Ritme, groep: Groep, stap: Stap)

    var datum: String {
        switch self {
        case let .event(datum, _): return datum
        case let .stap(datum, _, _, _): return datum
        }
    }
}
