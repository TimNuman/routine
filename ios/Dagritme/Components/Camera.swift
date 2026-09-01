import Foundation
import Observation

/// Waar het oog staat. Het huis zegt welk tabblad en welk ritme gekozen zijn;
/// de camera loopt daar een stap achteraan, want een bladzijde moet eerst
/// buiten beeld gebouwd zijn voordat hij kan aanschuiven.
///
/// In rust staat er precies één bladzijde in de boom. Bij een tik komt de
/// nieuwe erbij, buiten beeld; zodra hij er staat schuift de oude eruit en
/// de nieuwe erin, en even later gaat de oude weer uit de boom. Meer dan die
/// twee zijn er nooit tegelijk.
///
/// De kolommen: 0 ochtend, 1 avond, 2 week, 3 instellingen. Wat lager
/// genummerd is ligt links.
@MainActor
@Observable
final class Camera {
    private(set) var tab: Tab = .routine
    private(set) var routine: Routine = .day
    /// De bladzijde die net verlaten is en nog naar buiten schuift.
    private(set) var leaving: Int?
    /// De bladzijde die net gebouwd is en buiten beeld wacht tot hij er staat.
    private(set) var entering: Int?

    @ObservationIgnored private var pending: (tab: Tab, routine: Routine)?
    @ObservationIgnored private var settle: Task<Void, Never>?

    var column: Int { columnOf(tab, routine) }

    var mounted: Set<Int> { Set([column, leaving, entering].compactMap { $0 }) }

    /// Wat uit beeld is staat precies één breedte opzij, aan de kant waar
    /// het in de rij hoort.
    func offset(of column: Int) -> CGFloat {
        column == self.column ? 0 : (column < self.column ? -1 : 1)
    }

    func look(at tab: Tab, _ routine: Routine) {
        let target = columnOf(tab, routine)
        if target == column {
            // Terug naar waar we al staan: wat klaarstond hoeft niet meer.
            pending = nil
            entering = nil
        } else if target == entering {
            pending = (tab, routine)
        } else if target == leaving {
            // Hij is nog onderweg naar buiten: draai hem om.
            pending = nil
            entering = nil
            point(at: tab, routine)
        } else {
            // Wat nog naar buiten schoof is nu weg; er schuiven er nooit twee.
            leaving = nil
            entering = target
            pending = (tab, routine)
        }
    }

    /// De bladzijde staat in de boom; nu kan het oog erheen.
    func arrived(_ column: Int) {
        guard let pending, column == entering else { return }
        self.pending = nil
        entering = nil
        point(at: pending.tab, pending.routine)
    }

    private func point(at tab: Tab, _ routine: Routine) {
        settle?.cancel()
        leaving = column
        self.tab = tab
        self.routine = routine
        settle = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.7))
            guard let self, !Task.isCancelled else { return }
            leaving = nil
        }
    }
}

func columnOf(_ tab: Tab, _ routine: Routine) -> Int {
    switch tab {
    case .routine: return routine == .night ? 1 : 0
    case .week: return 2
    case .settings: return 3
    }
}
