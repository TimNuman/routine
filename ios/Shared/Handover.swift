import Foundation

/// Wat de telefoon aan het horloge doorgeeft: waar het huis staat en met
/// welke kopjes het erbij mag. Meer niet — de refresh-token blijft op de
/// telefoon, en het horloge vraagt om een verse sleutel zodra deze om is.
struct Handover: Sendable, Equatable {
    var store: String
    var headers: [String: String]
    /// Wanneer de telefoon hem klaarzette; een sleutel is een uur geldig.
    var at: Date

    init(store: String, headers: [String: String], at: Date) {
        self.store = store
        self.headers = headers
        self.at = at
    }

    init?(_ raw: [String: Any]) {
        guard let store = raw["store"] as? String, !store.isEmpty else { return nil }
        self.store = store
        self.headers = raw["headers"] as? [String: String] ?? [:]
        self.at = Date(timeIntervalSince1970: raw["at"] as? Double ?? 0)
    }

    /// Zoals hij over de lijn gaat: alleen dingen die een property list kent.
    var payload: [String: Any] {
        ["store": store, "headers": headers, "at": at.timeIntervalSince1970]
    }

    /// Dezelfde plek en dezelfde sleutel; de tijd erbij telt niet mee.
    func sameAs(_ other: Handover?) -> Bool {
        guard let other else { return false }
        return store == other.store && headers == other.headers
    }
}
