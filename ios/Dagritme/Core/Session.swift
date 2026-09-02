import Foundation
import Observation

struct Account: Codable, Equatable {
    var id: String
    var email: String?
    var name: String?

    var label: String { name ?? email ?? String(localized: "zonder naam") }
}

struct Home: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var role: String
}

enum SignInProvider: String {
    case apple
    case google
}

struct SignInCancelled: Error {}

struct SignInError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

/// Wat er in de sleutelhanger staat.
private struct Stored: Codable {
    var access: String
    var refresh: String
    var issued: Date
    var account: Account
    var homes: [Home]
}

enum SessionState: Equatable {
    /// Nog aan het kijken wat er in de sleutelhanger staat.
    case unknown
    case signedOut
    /// Zonder account: het ene huis uit de Worker, met de gedeelde sleutel.
    case legacy
    case signedIn
}

/// Wie er ingelogd is, en met welke tokens. De access-token is een uur
/// geldig; de refresh-token ruilt hem in voor een nieuwe, en is daarna zelf
/// ook vervangen.
@MainActor
@Observable
final class Session {
    private(set) var state: SessionState = .unknown
    private(set) var account: Account?
    private(set) var homes: [Home] = []
    var busy = false
    var error = ""

    @ObservationIgnored private var access = ""
    @ObservationIgnored private var refreshToken = ""
    @ObservationIgnored private var issued = Date.distantPast
    @ObservationIgnored private var refreshing: Task<String?, Never>?

    private static let accessLifetime: TimeInterval = 60 * 60
    private static let legacyKey = "legacy"

    /// Eén huis per persoon, voorlopig: het eerste dat de server noemt.
    var home: Home? { homes.first }
    var needsHome: Bool { state == .signedIn && home == nil }

    /// Verandert zodra er iets anders geladen moet worden: een ander huis, of
    /// geen huis meer. Het huishouden begint dan opnieuw.
    var scope: String? {
        switch state {
        case .legacy: return "legacy"
        case .signedIn: return home.map { "home:" + $0.id }
        default: return nil
        }
    }

    init() { restore() }

    private func restore() {
        if ProcessInfo.processInfo.environment["SESSION"] == "legacy" {
            state = .legacy
            return
        }
        if let data = Keychain.load(), let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            access = stored.access
            refreshToken = stored.refresh
            issued = stored.issued
            account = stored.account
            homes = stored.homes
            state = .signedIn
            Task { await sync() }
            return
        }
        state = UserDefaults.standard.bool(forKey: Self.legacyKey) ? .legacy : .signedOut
    }

    // MARK: - Wat de rest van de app nodig heeft

    /// Waar de opslag staat en wat er in de kopjes moet. Nil zolang er niets
    /// te laden is.
    var endpoint: Endpoint? {
        guard let api = Config.apiURL else { return nil }
        switch state {
        case .legacy:
            let key = Config.key
            return Endpoint(
                store: api.appendingPathComponent("storage"),
                headers: key.isEmpty ? [:] : ["X-Routine-Key": key],
                refresh: nil
            )
        case .signedIn:
            guard let home else { return nil }
            return Endpoint(
                store: api.appendingPathComponent("homes/\(home.id)/storage"),
                headers: ["Authorization": "Bearer " + access],
                refresh: { [weak self] in await self?.refresh() }
            )
        default:
            return nil
        }
    }

    /// Bij het wakker worden: een token dat bijna om is alvast vernieuwen,
    /// zodat de stroom niet eerst op een 401 hoeft te lopen.
    func wake() {
        guard state == .signedIn else { return }
        if Date().timeIntervalSince(issued) > Self.accessLifetime - 10 * 60 {
            Task { _ = await refresh() }
        } else {
            Task { await sync() }
        }
    }

    // MARK: - Inloggen

    func continueWithoutAccount() {
        UserDefaults.standard.set(true, forKey: Self.legacyKey)
        error = ""
        state = .legacy
    }

    func showSignIn() {
        error = ""
        state = .signedOut
    }

    func signIn(_ provider: SignInProvider, idToken: String, name: String?) async {
        busy = true
        defer { busy = false }
        var body: [String: Any] = ["provider": provider.rawValue, "idToken": idToken]
        if let name, !name.isEmpty { body["name"] = name }
        do {
            let out = try await post("auth/sign-in", body, authorized: false)
            take(out)
            UserDefaults.standard.set(false, forKey: Self.legacyKey)
            error = ""
            state = .signedIn
            if homes.isEmpty { await ensureHome() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signInWithGoogle() async {
        do {
            let result = try await GoogleSignIn().run()
            await signIn(.google, idToken: result.idToken, name: result.name)
        } catch is SignInCancelled {
            // Zelf weggeklikt; niets te melden.
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() async {
        let token = refreshToken
        forget()
        state = .signedOut
        if !token.isEmpty {
            _ = try? await post("auth/sign-out", ["refreshToken": token], authorized: false)
        }
    }

    // MARK: - Het huis

    /// De server maakt bij het inloggen een huis; mocht dat toch ontbreken,
    /// dan hier alsnog.
    func ensureHome() async {
        guard state == .signedIn, homes.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            let out = try await post("homes", ["name": "Thuis"])
            let home = Home(id: out["home"]["id"].text, name: out["home"]["name"].text,
                            role: out["home"]["role"].text)
            guard !home.id.isEmpty else { return }
            homes = [home]
            persist()
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Onder de motorkap

    /// Haalt op wie we zijn en welke huizen er zijn. Een 401 die ook na een
    /// refresh blijft, betekent dat het account weg is: dan uitloggen.
    private func sync() async {
        do {
            let out = try await request("GET", "me", nil)
            take(out)
            if homes.isEmpty { await ensureHome() }
        } catch let error as StoreError {
            if case .http(401) = error {
                forget()
                state = .signedOut
            }
        } catch {
            // Geen verbinding; wat we hadden blijft staan.
        }
    }

    private func take(_ out: Json) {
        if !out["accessToken"].text.isEmpty {
            access = out["accessToken"].text
            issued = Date()
        }
        if !out["refreshToken"].text.isEmpty { refreshToken = out["refreshToken"].text }
        let user = out["user"]
        if !user["id"].text.isEmpty {
            account = Account(id: user["id"].text,
                              email: user["email"].text.isEmpty ? nil : user["email"].text,
                              name: user["name"].text.isEmpty ? nil : user["name"].text)
        }
        if out["homes"].isArray {
            homes = out["homes"].array.map {
                Home(id: $0["id"].text, name: $0["name"].text, role: $0["role"].text)
            }
        }
        persist()
    }

    private func persist() {
        guard let account, !access.isEmpty, !refreshToken.isEmpty else { return }
        let stored = Stored(access: access, refresh: refreshToken, issued: issued,
                            account: account, homes: homes)
        if let data = try? JSONEncoder().encode(stored) { Keychain.save(data) }
    }

    private func forget() {
        access = ""
        refreshToken = ""
        issued = .distantPast
        account = nil
        homes = []
        Keychain.clear()
    }

    /// Ruilt de refresh-token in. Meerdere verzoeken die tegelijk op een 401
    /// lopen delen één poging.
    private func refresh() async -> String? {
        if let refreshing { return await refreshing.value }
        let task = Task<String?, Never> { [weak self] in
            guard let self, !self.refreshToken.isEmpty else { return nil }
            do {
                let out = try await self.post("auth/refresh", ["refreshToken": self.refreshToken],
                                              authorized: false)
                self.take(out)
                return self.access
            } catch let error as StoreError {
                if case .http(401) = error {
                    self.forget()
                    self.state = .signedOut
                }
                return nil
            } catch {
                return nil
            }
        }
        refreshing = task
        let out = await task.value
        refreshing = nil
        return out
    }

    private func post(_ path: String, _ body: [String: Any], authorized: Bool = true) async throws -> Json {
        try await request("POST", path, body, authorized: authorized)
    }

    private func request(_ method: String, _ path: String, _ body: [String: Any]?,
                         authorized: Bool = true) async throws -> Json {
        guard let api = Config.apiURL else { throw StoreError.noAddress }
        var request = URLRequest(url: api.appendingPathComponent(path))
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if authorized { request.setValue("Bearer " + access, forHTTPHeaderField: "Authorization") }
        var (data, response) = try await URLSession.shared.data(for: request)
        if authorized, (response as? HTTPURLResponse)?.statusCode == 401, let fresh = await refresh() {
            request.setValue("Bearer " + fresh, forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: request)
        }
        let out = Json.parse(data)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let reason = out["error"].text
            if reason.isEmpty || http.statusCode == 401 { throw StoreError.http(http.statusCode) }
            throw SignInError(message: reason)
        }
        return out
    }
}
