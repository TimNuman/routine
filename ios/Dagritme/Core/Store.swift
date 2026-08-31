import Foundation

typealias Checks = [String: Bool]

enum StoreError: LocalizedError {
    case noAddress
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .noAddress: return "geen adres ingesteld"
        case let .http(status): return "HTTP \(status)"
        }
    }
}

func checkKey(_ routine: Routine, _ step: String, _ person: String) -> String {
    "\(routine.rawValue)/\(step)/\(person)"
}

enum Store {
    private static var headers: [String: String] {
        Config.key.isEmpty ? [:] : ["X-Routine-Key": Config.key]
    }

    private static func url(_ path: String, _ query: [String: String] = [:]) throws -> URL {
        guard let base = Config.storeURL,
              var parts = URLComponents(url: base.appendingPathComponent(path),
                                        resolvingAgainstBaseURL: false)
        else { throw StoreError.noAddress }
        if !query.isEmpty {
            parts.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let out = parts.url else { throw StoreError.noAddress }
        return out
    }

    private static func get(_ path: String, _ query: [String: String] = [:]) async throws -> Json {
        var request = URLRequest(url: try url(path, query))
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response)
        return Json.parse(data)
    }

    private static func send(_ path: String, _ method: String, _ body: [String: Any]) async throws {
        var request = URLRequest(url: try url(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try check(response)
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else { throw StoreError.http(http.statusCode) }
    }

    static func loadContent() async throws -> Content {
        normalize(try await get("content")["content"])
    }

    static func saveContent(_ content: [String: Any]) async throws {
        try await send("content", "PUT", content)
    }

    static func loadChecks(_ date: String) async throws -> Checks {
        let raw = try await get("day", ["date": date])["checks"]
        var checks: Checks = [:]
        for key in raw.keys where raw[key].flag { checks[key] = true }
        return checks
    }

    static func writeCheck(date: String, key: String, on: Bool) async throws {
        try await send("check", "PUT", ["date": date, "key": key, "on": on])
    }

    static func clearRoutine(date: String, routine: Routine) async throws {
        try await send("routine", "DELETE", ["date": date, "routine": routine.rawValue])
    }
}

enum StreamMessage {
    case start(date: String, content: Json, checks: Checks)
    case content(Json)
    case check(date: String, key: String, on: Bool)
    case routine(date: String, routine: Routine)

    init?(_ raw: Json) {
        switch raw["kind"].text {
        case "start":
            var checks: Checks = [:]
            let source = raw["checks"]
            for key in source.keys where source[key].flag { checks[key] = true }
            self = .start(date: raw["date"].text, content: raw["content"], checks: checks)
        case "content":
            self = .content(raw["content"])
        case "check":
            self = .check(date: raw["date"].text, key: raw["key"].text,
                          on: raw["on"].flag)
        case "routine":
            self = .routine(date: raw["date"].text,
                            routine: raw["routine"].text == "night" ? .night : .day)
        default:
            return nil
        }
    }
}

@MainActor
final class LiveStream {
    private var task: URLSessionWebSocketTask?
    private var closed = false
    private var attempts = 0
    private var retry: Task<Void, Never>?
    private var day: String
    private let onMessage: (StreamMessage) -> Void

    init(date: String, onMessage: @escaping (StreamMessage) -> Void) {
        self.day = date
        self.onMessage = onMessage
        connect()
    }

    func watch(_ fresh: String) {
        day = fresh
        guard let task, task.state == .running,
              let body = try? JSONSerialization.data(
                withJSONObject: ["kind": "day", "date": fresh]),
              let text = String(data: body, encoding: .utf8)
        else { return }
        task.send(.string(text)) { _ in }
    }

    func stop() {
        closed = true
        retry?.cancel()
        retry = nil
        attempts = 0
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func connect() {
        guard !closed, var address = Config.streamURL else { return }
        if var parts = URLComponents(url: address, resolvingAgainstBaseURL: false) {
            parts.queryItems = [URLQueryItem(name: "date", value: day)]
            if let out = parts.url { address = out }
        }
        var request = URLRequest(url: address)
        if !Config.key.isEmpty {
            request.setValue(Config.key, forHTTPHeaderField: "X-Routine-Key")
        }
        let fresh = URLSession.shared.webSocketTask(with: request)
        task = fresh
        fresh.resume()
        listen(fresh)
    }

    private func listen(_ socket: URLSessionWebSocketTask) {
        socket.receive { result in
            Task { @MainActor [weak self] in
                guard let self, !self.closed, self.task === socket else { return }
                switch result {
                case let .success(message):
                    self.attempts = 0
                    self.receive(message)
                    self.listen(socket)
                case .failure:
                    self.task = nil
                    self.reconnect()
                }
            }
        }
    }

    private func receive(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case let .string(text): data = text.data(using: .utf8)
        case let .data(raw): data = raw
        @unknown default: data = nil
        }
        guard let data, let out = StreamMessage(Json.parse(data)) else { return }
        onMessage(out)
    }

    private func reconnect() {
        guard !closed, retry == nil else { return }
        let pause = min(pow(2.0, Double(attempts)), 30)
        attempts += 1
        retry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.retry = nil
            self.connect()
        }
    }
}
