// Waar de achterkant staat. De webversie hoeft dit niet te weten — die wordt
// door dezelfde Worker uitgeserveerd en vraagt gewoon /api. Een app op een
// telefoon staat nergens, dus hier moet één keer een heel adres staan.
//
// Zet hieronder het adres van je eigen Worker, of — handiger als je meerdere
// omgevingen hebt — de sleutel ROUTINE_ADRES in Info.plist; die wint.
import Foundation

enum Configuratie {
    // Bijvoorbeeld "https://routine.jouwnaam.workers.dev". Draai je wrangler dev
    // op de laptop, dan is het "http://127.0.0.1:8787" — zie ios/README.md,
    // want dan moet er ook iets in Info.plist bij.
    static let standaardAdres = "https://routine.voorbeeld.workers.dev"

    // Alleen nodig als er een SLEUTEL als secret bij de Worker staat.
    static let standaardSleutel = ""

    static var adres: String {
        let uitPlist = plist("ROUTINE_ADRES")
        return (uitPlist.isEmpty ? standaardAdres : uitPlist)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    static var sleutel: String {
        let uitPlist = plist("ROUTINE_SLEUTEL")
        return uitPlist.isEmpty ? standaardSleutel : uitPlist
    }

    static var opslag: URL? { URL(string: adres + "/api/opslag") }
    static var assistent: URL? { URL(string: adres + "/api/lees") }

    // De stroom praat ws in plaats van http; verder is het hetzelfde adres.
    static var stroom: URL? {
        guard adres.hasPrefix("http") else { return nil }
        return URL(string: "ws" + String(adres.dropFirst(4)) + "/api/opslag/stroom")
    }

    private static func plist(_ sleutel: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: sleutel) as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
}
