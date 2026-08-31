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

    static var storeURL: URL? { URL(string: baseURL + "/api/v2/storage") }
    static var assistantURL: URL? { URL(string: baseURL + "/api/v2/read") }

    static var streamURL: URL? {
        guard baseURL.hasPrefix("http") else { return nil }
        return URL(string: "ws" + String(baseURL.dropFirst(4)) + "/api/v2/storage/stream")
    }

    private static func plist(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
}
