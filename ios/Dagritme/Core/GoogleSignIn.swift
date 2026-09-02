import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct SignInResult {
    var idToken: String
    var name: String?
}

/// Inloggen bij Google zonder hun sdk: de gewone OAuth-dans met PKCE in een
/// `ASWebAuthenticationSession`. Een iOS-client heeft geen geheim, dus het
/// enige wat de app kent is het client-id uit `Info.plist`.
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    private static let authorize = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let exchange = "https://oauth2.googleapis.com/token"

    func run() async throws -> SignInResult {
        let client = Config.googleClientID
        guard !client.isEmpty, let scheme = Self.scheme(for: client) else {
            throw SignInError(message: String(localized: "Inloggen met Google is nog niet ingesteld."))
        }
        let redirect = scheme + ":/oauth2redirect"
        let verifier = Self.random()
        let state = Self.random()

        var parts = URLComponents(string: Self.authorize)!
        parts.queryItems = [
            .init(name: "client_id", value: client),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: Self.challenge(verifier)),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "nonce", value: Self.random()),
        ]
        let callback = try await open(parts.url!, scheme: scheme)

        let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard query.first(where: { $0.name == "state" })?.value == state,
              let code = query.first(where: { $0.name == "code" })?.value
        else { throw SignInError(message: String(localized: "Google gaf geen code terug.")) }

        return try await trade(code, client: client, redirect: redirect, verifier: verifier)
    }

    private func open(_ url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: SignInCancelled())
                } else {
                    continuation.resume(throwing: error ?? SignInCancelled())
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
    }

    private func trade(_ code: String, client: String, redirect: String,
                       verifier: String) async throws -> SignInResult {
        var request = URLRequest(url: URL(string: Self.exchange)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.form([
            "code": code, "client_id": client, "redirect_uri": redirect,
            "grant_type": "authorization_code", "code_verifier": verifier,
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        let out = Json.parse(data)
        let idToken = out["id_token"].text
        guard !idToken.isEmpty else {
            let reason = out["error_description"].text(out["error"].text("geen id-token"))
            throw SignInError(message: String(localized: "Google wees het af (\(reason))."))
        }
        return SignInResult(idToken: idToken, name: Self.claims(of: idToken)["name"].text)
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { UIApplication.keyWindow ?? ASPresentationAnchor() }
    }

    // MARK: - Hulpjes

    /// `123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`.
    static func scheme(for client: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard client.hasSuffix(suffix) else { return nil }
        return "com.googleusercontent.apps." + client.dropLast(suffix.count)
    }

    private static func random() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64url(Data(bytes))
    }

    private static func challenge(_ verifier: String) -> String {
        base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func form(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    /// De inhoud van een JWT, zonder de handtekening te controleren; die
    /// controleert de Worker. Hier alleen om de naam te lezen.
    private static func claims(of jwt: String) -> Json {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return .null }
        var body = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while body.count % 4 != 0 { body += "=" }
        guard let data = Data(base64Encoded: body) else { return .null }
        return Json.parse(data)
    }
}

extension UIApplication {
    @MainActor
    static var keyWindow: UIWindow? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
