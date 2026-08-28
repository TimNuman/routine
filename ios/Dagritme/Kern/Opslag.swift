// Praat met de eigen achterkant: /api/opslag op de Worker die ook de webversie
// uitserveert. Naast lezen en schrijven is er een stroom — een WebSocket die
// openblijft — zodat elke telefoon meteen ziet wat er op een andere gebeurt.
import Foundation

typealias Vinkjes = [String: Bool]

enum Opslagfout: LocalizedError {
    case geenAdres
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .geenAdres: return "geen adres ingesteld"
        case let .http(status): return "HTTP \(status)"
        }
    }
}

// De sleutel waaronder een vinkje staat: '<ritme>/<stap>/<persoon>'.
func vinkSleutel(_ ritme: Ritme, _ stap: String, _ persoon: String) -> String {
    "\(ritme.rawValue)/\(stap)/\(persoon)"
}

enum Opslag {
    private static var kopjes: [String: String] {
        Configuratie.sleutel.isEmpty ? [:] : ["X-Routine-Sleutel": Configuratie.sleutel]
    }

    private static func adres(_ pad: String, _ vragen: [String: String] = [:]) throws -> URL {
        guard let basis = Configuratie.opslag,
              var delen = URLComponents(url: basis.appendingPathComponent(pad),
                                        resolvingAgainstBaseURL: false)
        else { throw Opslagfout.geenAdres }
        if !vragen.isEmpty {
            delen.queryItems = vragen.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let uit = delen.url else { throw Opslagfout.geenAdres }
        return uit
    }

    private static func haal(_ pad: String, _ vragen: [String: String] = [:]) async throws -> Json {
        var verzoek = URLRequest(url: try adres(pad, vragen))
        kopjes.forEach { verzoek.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (gegevens, antwoord) = try await URLSession.shared.data(for: verzoek)
        try controleer(antwoord)
        return Json.lees(gegevens)
    }

    private static func stuur(_ pad: String, _ wijze: String, _ lijf: [String: Any]) async throws {
        var verzoek = URLRequest(url: try adres(pad))
        verzoek.httpMethod = wijze
        verzoek.setValue("application/json", forHTTPHeaderField: "Content-Type")
        kopjes.forEach { verzoek.setValue($0.value, forHTTPHeaderField: $0.key) }
        verzoek.httpBody = try JSONSerialization.data(withJSONObject: lijf)
        let (_, antwoord) = try await URLSession.shared.data(for: verzoek)
        try controleer(antwoord)
    }

    private static func controleer(_ antwoord: URLResponse) throws {
        guard let http = antwoord as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else { throw Opslagfout.http(http.statusCode) }
    }

    static func haalInhoud() async throws -> Inhoud {
        normaliseer(try await haal("inhoud")["inhoud"])
    }

    // De hele inhoud gaat in één keer terug: de app bewerkt hem ook als één stuk.
    static func bewaarConfig(_ inhoud: [String: Any]) async throws {
        try await stuur("inhoud", "PUT", inhoud)
    }

    static func haalVinkjes(_ datum: String) async throws -> Vinkjes {
        let uit = try await haal("dag", ["datum": datum])["vinkjes"]
        var vinkjes: Vinkjes = [:]
        for sleutel in uit.sleutels where uit[sleutel].vlag { vinkjes[sleutel] = true }
        return vinkjes
    }

    static func schrijfVink(datum: String, sleutel: String, aan: Bool) async throws {
        try await stuur("vink", "PUT", ["datum": datum, "sleutel": sleutel, "aan": aan])
    }

    // Alles van dit ritme op deze dag in één keer weg: opnieuw beginnen.
    static func wisRitme(datum: String, ritme: Ritme) async throws {
        try await stuur("ritme", "DELETE", ["datum": datum, "ritme": ritme.rawValue])
    }
}

// -------------------------------------------------------------------- stroom ---

enum Bericht {
    case begin(datum: String, inhoud: Json, vinkjes: Vinkjes)
    case inhoud(Json)
    case vink(datum: String, sleutel: String, aan: Bool)
    case ritme(datum: String, ritme: Ritme)

    init?(_ ruw: Json) {
        switch ruw["soort"].tekst {
        case "begin":
            var vinkjes: Vinkjes = [:]
            let bron = ruw["vinkjes"]
            for sleutel in bron.sleutels where bron[sleutel].vlag { vinkjes[sleutel] = true }
            self = .begin(datum: ruw["datum"].tekst, inhoud: ruw["inhoud"], vinkjes: vinkjes)
        case "inhoud":
            self = .inhoud(ruw["inhoud"])
        case "vink":
            self = .vink(datum: ruw["datum"].tekst, sleutel: ruw["sleutel"].tekst,
                         aan: ruw["aan"].vlag)
        case "ritme":
            self = .ritme(datum: ruw["datum"].tekst,
                          ritme: ruw["ritme"].tekst == "nacht" ? .nacht : .dag)
        default:
            return nil
        }
    }
}

// Blijft zichzelf opnieuw verbinden zolang je hem niet stopzet: een telefoon die
// uit zijn slaap komt heeft geen verbinding meer, en dat merk je pas als je het
// probeert.
@MainActor
final class Stroom {
    private var taak: URLSessionWebSocketTask?
    private var dicht = false
    private var pogingen = 0
    private var wachten: Task<Void, Never>?
    private var dag: String
    private let opBericht: (Bericht) -> Void

    init(datum: String, opBericht: @escaping (Bericht) -> Void) {
        self.dag = datum
        self.opBericht = opBericht
        verbind()
    }

    // Na middernacht kijk je naar een andere dag; de stroom volgt mee.
    func kijkNaar(_ nieuw: String) {
        dag = nieuw
        guard let taak, taak.state == .running,
              let lijf = try? JSONSerialization.data(
                withJSONObject: ["soort": "dag", "datum": nieuw]),
              let tekst = String(data: lijf, encoding: .utf8)
        else { return }
        taak.send(.string(tekst)) { _ in }
    }

    func stop() {
        dicht = true
        wachten?.cancel()
        wachten = nil
        pogingen = 0
        taak?.cancel(with: .goingAway, reason: nil)
        taak = nil
    }

    private func verbind() {
        guard !dicht, var adres = Configuratie.stroom else { return }
        if var delen = URLComponents(url: adres, resolvingAgainstBaseURL: false) {
            delen.queryItems = [URLQueryItem(name: "datum", value: dag)]
            if let uit = delen.url { adres = uit }
        }
        var verzoek = URLRequest(url: adres)
        if !Configuratie.sleutel.isEmpty {
            verzoek.setValue(Configuratie.sleutel, forHTTPHeaderField: "X-Routine-Sleutel")
        }
        let nieuw = URLSession.shared.webSocketTask(with: verzoek)
        taak = nieuw
        nieuw.resume()
        luister(nieuw)
    }

    private func luister(_ nieuw: URLSessionWebSocketTask) {
        nieuw.receive { uitkomst in
            Task { @MainActor [weak self] in
                guard let self, !self.dicht, self.taak === nieuw else { return }
                switch uitkomst {
                case let .success(bericht):
                    self.pogingen = 0
                    self.ontvang(bericht)
                    self.luister(nieuw)
                case .failure:
                    self.taak = nil
                    self.opnieuw()
                }
            }
        }
    }

    private func ontvang(_ bericht: URLSessionWebSocketTask.Message) {
        let gegevens: Data?
        switch bericht {
        case let .string(tekst): gegevens = tekst.data(using: .utf8)
        case let .data(ruw): gegevens = ruw
        @unknown default: gegevens = nil
        }
        guard let gegevens, let uit = Bericht(Json.lees(gegevens)) else { return }
        opBericht(uit)
    }

    // Rustig aan als het blijft mislukken, maar nooit langer dan een halve minuut.
    private func opnieuw() {
        guard !dicht, wachten == nil else { return }
        let pauze = min(pow(2.0, Double(pogingen)), 30)
        pogingen += 1
        wachten = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(pauze * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.wachten = nil
            self.verbind()
        }
    }
}
