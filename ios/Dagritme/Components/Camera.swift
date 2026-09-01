import Foundation
import Observation

/// Waar het oog staat. Het huis zegt welk tabblad en welk ritme gekozen zijn;
/// de camera loopt daar een stap achteraan, want een kolom die nog niet in de
/// boom staat moet eerst gebouwd zijn voordat hij kan aanschuiven. Alleen de
/// kolommen naast de camera staan in de boom; de rest wordt na de schuif
/// opgeruimd.
///
/// De kolommen: 0 ochtend, 1 avond, 2 week, 3 instellingen.
@MainActor
@Observable
final class Camera {
    private(set) var tab: Tab = .routine
    private(set) var routine: Routine = .day
    private(set) var mounted: Set<Int> = [0, 1]
    /// Net gebouwd om naartoe te schuiven: die slaan de intrede-animatie over.
    private(set) var entering: Set<Int> = []

    @ObservationIgnored private var pending: (tab: Tab, routine: Routine)?
    @ObservationIgnored private var settle: Task<Void, Never>?

    static let last = 3

    var column: Int { columnOf(tab, routine) }

    func look(at tab: Tab, _ routine: Routine) {
        settle?.cancel()
        let target = columnOf(tab, routine)
        if mounted.contains(target) {
            pending = nil
            self.tab = tab
            self.routine = routine
        } else {
            mounted.insert(target)
            entering.insert(target)
            pending = (tab, routine)
        }
        settle = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard let self, !Task.isCancelled else { return }
            if let pending { arrived(columnOf(pending.tab, pending.routine)) }
            mounted = Set(max(0, column - 1)...min(Self.last, column + 1))
            entering = []
        }
    }

    /// De kolom staat in de boom; nu kan het oog erheen.
    func arrived(_ column: Int) {
        guard let pending, columnOf(pending.tab, pending.routine) == column else { return }
        self.pending = nil
        tab = pending.tab
        routine = pending.routine
    }
}

func columnOf(_ tab: Tab, _ routine: Routine) -> Int {
    switch tab {
    case .routine: return routine == .night ? 1 : 0
    case .week: return 2
    case .settings: return 3
    }
}
