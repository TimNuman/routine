import Foundation
import Observation

enum Tab: Hashable, CaseIterable {
    case routine
    case week
    case settings
}

struct Move: Equatable {
    var tab: Tab
    var routine: Routine
}

@MainActor
@Observable
final class Household {
    var content: Content?
    var error = ""
    var checks: Checks = [:]
    var routine: Routine = .day
    var tab: Tab = .routine
    /// Welke kant de laatste tabwissel op ging: 1 naar rechts, -1 naar links.
    var direction = 1
    /// De gevraagde wissel; het scherm voert hem een beeld later uit, zodat de
    /// bladzijde die weggaat de richting al kent.
    var pending: Move?
    var sheetOpen = false
    var hidden: Set<String> = []
    var now = Date()

    var date: String { dateString(now) }

    var evening: Bool { routine == .night && tab == .routine }

    @ObservationIgnored private var stream: LiveStream?
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var chosen = false

    init() {
        Task { await reload() }
        listen()
        tick()
    }

    func reload() async {
        do {
            async let fresh = Store.loadContent()
            async let stored = Store.loadChecks(date)
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
        Task { await reload() }
        stream?.watch(date)
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
        let day = date
        Task {
            do {
                try await Store.writeCheck(date: day, key: key, on: on)
            } catch {
                set(key, !on)
            }
        }
    }

    func clear() {
        let which = routine
        checks = checks.filter { !$0.key.hasPrefix(which.rawValue + "/") }
        let day = date
        Task { try? await Store.clearRoutine(date: day, routine: which) }
    }

    func save(_ draft: Draft) async -> String? {
        let fresh = cleaned(draft)
        do {
            try await Store.saveContent(fresh)
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
        stream = LiveStream(date: date) { [weak self] message in
            guard let self else { return }
            switch message {
            case let .start(_, fresh, stored):
                self.error = ""
                if !fresh.isNull { self.content = normalize(fresh) }
                self.checks = stored
            case let .content(fresh):
                if !fresh.isNull { self.content = normalize(fresh) }
            case let .check(_, key, on):
                self.set(key, on)
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
