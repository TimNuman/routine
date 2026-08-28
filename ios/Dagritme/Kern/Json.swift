// Wat er uit het huis komt is los zand: een tak kan een lijst zijn of een
// woordenboek met nummers als sleutel, een getal kan er als tekst in staan, en
// een oud veld kan er nog naast staan. Deze waarde neemt dat op zoals het is,
// zodat Inhoud.swift het daarna in één keer gladstrijkt — precies wat de
// javascript-versie doet met een gewoon object.
import Foundation

enum Json {
    case tekst(String)
    case getal(Double)
    case waar(Bool)
    case lijst([Json])
    case boek([String: Json])
    case niets

    init(_ ruw: Any?) {
        guard let ruw else { self = .niets; return }
        switch ruw {
        case let waarde as Json:
            self = waarde
        case let waarde as String:
            self = .tekst(waarde)
        case let waarde as NSNumber:
            // Een bool komt uit JSONSerialization als NSNumber terug; alleen de
            // type-id verraadt het verschil.
            self = CFGetTypeID(waarde) == CFBooleanGetTypeID()
                ? .waar(waarde.boolValue) : .getal(waarde.doubleValue)
        case let waarde as [Any]:
            self = .lijst(waarde.map { Json($0) })
        case let waarde as [String: Any]:
            self = .boek(waarde.mapValues { Json($0) })
        default:
            self = .niets
        }
    }

    static func lees(_ gegevens: Data) -> Json {
        guard let ding = try? JSONSerialization.jsonObject(
            with: gegevens, options: [.fragmentsAllowed]) else { return .niets }
        return Json(ding)
    }

    subscript(sleutel: String) -> Json {
        if case let .boek(boek) = self { return boek[sleutel] ?? .niets }
        return .niets
    }

    // Een tekst is alleen een tekst; een getal of een lijst levert niets op.
    // Zo hoeft nergens anders gecontroleerd te worden wat er stond.
    var tekst: String {
        if case let .tekst(waarde) = self {
            return waarde.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    func tekst(_ terugval: String) -> String {
        let waarde = tekst
        return waarde.isEmpty ? terugval : waarde
    }

    var getal: Double? {
        switch self {
        case let .getal(waarde): return waarde
        case let .tekst(waarde): return Double(waarde.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    var vlag: Bool {
        switch self {
        case let .waar(waarde): return waarde
        case let .getal(waarde): return waarde != 0
        case let .tekst(waarde): return !waarde.isEmpty
        default: return false
        }
    }

    // Een lijst, of een woordenboek met nummers als sleutel — zo bewaarde de
    // oude database een lijst waar iets uit weggehaald was.
    var lijst: [Json] {
        switch self {
        case let .lijst(waarden):
            return waarden.filter { !$0.isNiets }
        case let .boek(boek):
            return boek.keys
                .sorted { (Int($0) ?? .max, $0) < (Int($1) ?? .max, $1) }
                .compactMap { boek[$0] }
                .filter { !$0.isNiets }
        default:
            return []
        }
    }

    var sleutels: [String] {
        if case let .boek(boek) = self { return Array(boek.keys) }
        return []
    }

    var isBoek: Bool {
        if case .boek = self { return true }
        return false
    }

    var isLijst: Bool {
        if case .lijst = self { return true }
        return false
    }

    var isNiets: Bool {
        if case .niets = self { return true }
        return false
    }

    // Terug naar gewone Foundation-waarden, voor als er iets de deur uit moet.
    var ding: Any? {
        switch self {
        case let .tekst(waarde): return waarde
        case let .getal(waarde): return waarde
        case let .waar(waarde): return waarde
        case let .lijst(waarden): return waarden.map { $0.ding as Any }
        case let .boek(boek): return boek.mapValues { $0.ding as Any }
        case .niets: return nil
        }
    }
}
