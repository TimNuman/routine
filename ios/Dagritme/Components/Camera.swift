import Foundation
import Observation

/// Een rij bladzijden waar er één van in beeld staat. Wat in de rij staat
/// heeft een vaste plek, precies één breedte uit elkaar; alleen de rij zelf
/// schuift, op één veer. Zo blijft de afstand tussen de bladzijde die gaat
/// en de bladzijde die komt altijd gelijk, ook als er halverwege wordt getikt.
///
/// In rust staat er één bladzijde in de rij. Bij een tik komt de nieuwe erbij,
/// buiten beeld; zodra hij er staat (`arrived`) schuift de rij, en even later
/// (`rest`) gaat de oude er weer uit. Meer dan twee zijn er nooit tegelijk.
struct Strip<Key: CaseIterable & Hashable> {
    private(set) var current: Key
    /// Net verlaten, schuift nog naar buiten.
    private(set) var leaving: Key?
    /// Net gebouwd, wacht buiten beeld tot hij er staat.
    private(set) var entering: Key?
    /// De plek in de rij die in beeld hoort; de weergave veert erheen.
    private(set) var eye = 0
    private var lane: [Key: Int]

    init(_ current: Key) {
        self.current = current
        lane = [current: 0]
    }

    var mounted: Set<Key> { Set([current, leaving, entering].compactMap { $0 }) }

    func position(of key: Key) -> Int { lane[key] ?? eye }

    /// Geeft terug of het oog nu verschuift.
    mutating func look(at target: Key) -> Bool {
        if target == current {
            entering = nil
            return false
        }
        if target == entering { return false }
        if target == leaving {
            // Hij is nog onderweg naar buiten: draai de rij om.
            entering = nil
            turn(to: target)
            return true
        }
        // Wat nog naar buiten schoof is nu weg; er schuiven er nooit twee.
        leaving = nil
        entering = target
        lane[target] = eye + (index(target) > index(current) ? 1 : -1)
        return false
    }

    /// De bladzijde staat in de rij; nu kan het oog erheen.
    mutating func arrived(_ key: Key) -> Bool {
        guard key == entering else { return false }
        entering = nil
        turn(to: key)
        return true
    }

    mutating func rest() {
        leaving = nil
        lane = lane.filter { mounted.contains($0.key) }
    }

    private mutating func turn(to key: Key) {
        leaving = current
        current = key
        eye = lane[key] ?? eye
    }

    private func index(_ key: Key) -> Int {
        Array(Key.allCases).firstIndex(of: key) ?? 0
    }
}

/// Waar het oog staat. Het huis zegt welk tabblad en welk ritme gekozen zijn;
/// de camera loopt daar een stap achteraan, want een bladzijde moet eerst
/// buiten beeld gebouwd zijn voordat hij kan aanschuiven. De tabbladen vormen
/// één rij; binnen het ritme-scherm vormen ochtend en avond er nog een.
@MainActor
@Observable
final class Camera {
    private(set) var tabs = Strip<Tab>(.routine)
    private(set) var routines = Strip<Routine>(.day)

    @ObservationIgnored private var settleTabs: Task<Void, Never>?
    @ObservationIgnored private var settleRoutines: Task<Void, Never>?

    var tab: Tab { tabs.current }
    var routine: Routine { routines.current }

    func look(at tab: Tab, _ routine: Routine) {
        if tab == tabs.current && tabs.entering == nil {
            if tab == .routine, routines.look(at: routine) { restRoutines() }
            return
        }
        let fresh = !tabs.mounted.contains(tab)
        if tabs.look(at: tab) { restTabs() }
        guard tab == .routine else { return }
        if fresh {
            routines = Strip(routine)
        } else if routines.look(at: routine) {
            restRoutines()
        }
    }

    func arrived(_ tab: Tab) {
        if tabs.arrived(tab) { restTabs() }
    }

    func arrived(_ routine: Routine) {
        if routines.arrived(routine) { restRoutines() }
    }

    private func restTabs() {
        settleTabs?.cancel()
        settleTabs = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.7))
            guard let self, !Task.isCancelled else { return }
            tabs.rest()
        }
    }

    private func restRoutines() {
        settleRoutines?.cancel()
        settleRoutines = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.7))
            guard let self, !Task.isCancelled else { return }
            routines.rest()
        }
    }
}
