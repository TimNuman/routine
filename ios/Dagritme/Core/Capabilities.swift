import Foundation

/// Wat het profiel waarmee deze build gesigneerd is toestaat. Een
/// persoonlijk (gratis) team mag geen Sign in with Apple; dan blijft die knop
/// weg in plaats van bij het tikken te falen.
enum Capabilities {
    static let signInWithApple: Bool = {
        guard let entitlements = provisioningEntitlements() else { return true }
        return entitlements["com.apple.developer.applesignin"] != nil
    }()

    /// De entitlements uit `embedded.mobileprovision`. Nil als die er niet is,
    /// zoals op de simulator; dan is er ook niets dat het tegenhoudt.
    private static func provisioningEntitlements() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url),
              let start = raw.range(of: Data("<plist".utf8)),
              let end = raw.range(of: Data("</plist>".utf8), in: start.upperBound..<raw.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: raw[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return nil }
        return plist["Entitlements"] as? [String: Any] ?? [:]
    }
}
