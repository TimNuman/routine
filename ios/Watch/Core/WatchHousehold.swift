import Foundation
import Observation

/// Het huishouden op de pols: dezelfde inhoud en dezelfde vinkjes als op de
/// telefoon, maar zonder alles wat je hier toch niet bewerkt. Het horloge
/// haalt het zelf bij het huis op — de telefoon geeft alleen het adres door —
/// en houdt dezelfde stroom open, dus een vinkje hier staat binnen een
/// seconde op de telefoon en andersom.
@MainActor
@Observable
final class WatchHousehold {
    var content: Content?
    var checks: Checks = [:]
    var error = ""
    var now = Date()

    @ObservationIgnored let link = Link()
    @ObservationIgnored private var stream: LiveStream?
    @ObservationIgnored private var clock: Task<Void, Never>?

    init() {
        link.onChange = { [weak self] in self?.restart() }
        wake()
    }

    /// De klok kiest, en niets anders: op het horloge is er geen schakelaar
    /// tussen ochtend en avond.
    var routine: Routine {
        calendar.component(.hour, from: now) >= EVENING_FROM ? .night : .day
    }

    var evening: Bool { routine == .night }
    var date: String { dateString(now) }
    var endpoint: Endpoint? { link.endpoint }
    /// Weet het horloge waar het huis staat? Zo niet, dan moet de telefoon
    /// eerst even open.
    var known: Bool { link.handover != nil }

    func wake() {
        link.wake()
        if clock == nil { tick() }
        guard endpoint != nil else { return }
        if stream == nil { listen() } else { stream?.watch(date) }
        Task { await reload() }
    }

    /// Naar de achtergrond: de stroom dicht en de klok stil, anders ligt het
    /// horloge te verbinden terwijl niemand kijkt.
    func sleep() {
        stream?.stop()
        stream = nil
        clock?.cancel()
        clock = nil
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
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggle(_ key: String) {
        let on = checks[key] != true
        set(key, on)
        Haptics.tick(on)
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

    func done(_ routine: Routine, _ step: Step, _ person: Person) -> Bool {
        checks[checkKey(routine, step.key, person.id)] == true
    }

    /// Een ander adres of een andere sleutel: opnieuw beginnen.
    private func restart() {
        stream?.stop()
        stream = nil
        error = ""
        wake()
    }

    private func set(_ key: String, _ on: Bool) {
        if on { checks[key] = true } else { checks.removeValue(forKey: key) }
    }

    private func listen() {
        stream = LiveStream(date: date, endpoint: { [weak self] in self?.endpoint }) { [weak self] message in
            guard let self else { return }
            switch message {
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
            case let .routine(_, which):
                self.checks = self.checks.filter { !$0.key.hasPrefix(which.rawValue + "/") }
            }
        }
    }

    /// Elke halve minuut: de klok verzet, en om middernacht een nieuwe dag.
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
