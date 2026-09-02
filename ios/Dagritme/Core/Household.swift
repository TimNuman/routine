import Foundation
import Observation

enum Tab: Hashable, CaseIterable {
    case routine
    case week
    case settings
}

/// Eén vinkje dat écht gezet of weggehaald is — door een tik hier, of door
/// een tik op een ander toestel. Niet wat er bij laden of herverbinden
/// binnenkomt: daar viert niemand iets om.
struct Tick: Equatable {
    var key: String
    var on: Bool
    var n: Int
}

@MainActor
@Observable
final class Household {
    var content: Content?
    var error = ""
    var checks: Checks = [:]
    var routine: Routine = .day
    var tab: Tab = .routine
    var sheetOpen = false
    var hidden: Set<String> = []
    var now = Date()
    /// Het laatste vinkje dat iemand zette; de voortgangsbalk viert alleen daarop.
    var lastTick: Tick?

    var date: String { dateString(now) }

    var evening: Bool { routine == .night && tab == .routine }

    @ObservationIgnored let session: Session
    @ObservationIgnored private var stream: LiveStream?
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var chosen = false

    var endpoint: Endpoint? { session.endpoint }

    init(session: Session) {
        self.session = session
        start()
    }

    /// Van voren af aan, voor dit huis: bij de start, en zodra de sessie een
    /// ander huis aanwijst.
    func start() {
        stream?.stop()
        stream = nil
        content = nil
        checks = [:]
        error = ""
        guard endpoint != nil else { return }
        Task { await reload() }
        listen()
        if clock == nil { tick() }
    }

    func reload() async {
        guard let endpoint else { return }
        do {
            async let fresh = Store.loadContent(endpoint)
            async let stored = Store.loadChecks(endpoint, date)
            let (c, v) = try await (fresh, stored)
            content = c
            checks = v
            error = ""
            if !chosen {
                routine = calendar.component(.hour, from: Date()) >= EVENING_FROM ? .night : .day
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func wake() {
        guard endpoint != nil else { return }
        session.wake()
        if stream == nil { listen() } else { stream?.watch(date) }
        if clock == nil { tick() }
        Task { await reload() }
    }

    /// Naar de achtergrond: de stroom dicht en de klok stil. Zo doet de app
    /// daar niets, en ligt hij straks niet steeds opnieuw te verbinden — elke
    /// poging haalt de radio uit zijn slaap.
    func sleep() {
        stream?.stop()
        stream = nil
        clock?.cancel()
        clock = nil
    }

    func toggleChild(_ id: String) {
        let everyone = Set((content?.people ?? []).map(\.id))
        hidden.formIntersection(everyone)

        if hidden.isEmpty {
            hidden = everyone.subtracting([id])
        } else if hidden.contains(id) {
            hidden.remove(id)
        } else {
            hidden.insert(id)
            if hidden == everyone { hidden.removeAll() }
        }
    }

    func setRoutine(_ fresh: Routine) {
        chosen = true
        routine = fresh
    }

    func toggle(_ key: String) {
        let on = checks[key] != true
        set(key, on)
        lastTick = Tick(key: key, on: on, n: (lastTick?.n ?? 0) + 1)
        let day = date
        guard let endpoint else { return }
        Task {
            do {
                try await Store.writeCheck(endpoint, date: day, key: key, on: on)
            } catch {
                set(key, !on)
            }
        }
    }

    func clear() {
        let which = routine
        checks = checks.filter { !$0.key.hasPrefix(which.rawValue + "/") }
        let day = date
        guard let endpoint else { return }
        Task { try? await Store.clearRoutine(endpoint, date: day, routine: which) }
    }

    func save(_ draft: Draft) async -> String? {
        let fresh = cleaned(draft)
        guard let endpoint else { return String(localized: "Er is geen huis om in te bewaren.") }
        do {
            try await Store.saveContent(endpoint, fresh)
        } catch {
            return String(localized: "Opslaan lukte niet (\(error.localizedDescription)).")
        }
        content = normalize(Json(fresh))
        return nil
    }

    private func set(_ key: String, _ on: Bool) {
        if on { checks[key] = true } else { checks.removeValue(forKey: key) }
    }

    private func listen() {
        stream = LiveStream(date: date, endpoint: { [weak self] in self?.endpoint }) { [weak self] message in
            guard let self else { return }
            switch message {
            // Alleen toekennen wat echt anders is: elke herverbinding begint
            // met een start, en die hoeft het scherm niet opnieuw op te bouwen.
            case let .start(_, fresh, stored):
                self.error = ""
                if !fresh.isNull {
                    let content = normalize(fresh)
                    if content != self.content { self.content = content }
                }
                if stored != self.checks { self.checks = stored }
            case let .content(fresh):
                if !fresh.isNull {
                    let content = normalize(fresh)
                    if content != self.content { self.content = content }
                }
            case let .check(_, key, on):
                self.set(key, on)
                self.lastTick = Tick(key: key, on: on, n: (self.lastTick?.n ?? 0) + 1)
            case let .routine(_, which):
                self.checks = self.checks.filter { !$0.key.hasPrefix(which.rawValue + "/") }
            }
        }
    }

    private func tick() {
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self else { return }
                let later = Date()
                let otherDay = dateString(later) != self.date
                self.now = later
                if otherDay {
                    self.stream?.watch(self.date)
                    await self.reload()
                }
            }
        }
    }
}
