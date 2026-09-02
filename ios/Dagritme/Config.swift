import Foundation

enum Config {
    static let defaultURL = "https://routine.voorbeeld.workers.dev"

    static let defaultKey = ""

    static var baseURL: String {
        let fromPlist = plist("ROUTINE_URL")
        return (fromPlist.isEmpty ? defaultURL : fromPlist)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    static var key: String {
        let fromPlist = plist("ROUTINE_KEY")
        return fromPlist.isEmpty ? defaultKey : fromPlist
    }

    /// Het iOS-client-id van Google; leeg betekent geen Google-knop die werkt.
    static var googleClientID: String { plist("GOOGLE_CLIENT_ID") }

    static var apiURL: URL? { baseURL.hasPrefix("http") ? URL(string: baseURL + "/api/v2") : nil }
    static var assistantURL: URL? { apiURL?.appendingPathComponent("read") }

    private static func plist(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
}
