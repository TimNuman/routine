import SwiftUI

/// De bladzijden van het horloge, van links naar rechts. Vegen wisselt van
/// bladzijde — meer knoppen zijn er niet.
///
/// Overdag begint het bij wat er vandaag op de agenda staat, dan hoever
/// iedereen is, en dan de stappen één voor één. 's Avonds staat de agenda
/// juist achteraan: wat er dan toe doet is morgen.
struct Pages: View {
    @Environment(WatchHousehold.self) private var household
    @State private var at = 0

    var body: some View {
        let content = household.content
        let plan = content.map { Plan($0, household.routine, household.now, household.checks) }

        ZStack {
            Sky(dark: household.evening)

            if let plan, let content, !plan.pages.isEmpty {
                TabView(selection: $at) {
                    ForEach(Array(plan.pages.enumerated()), id: \.offset) { (i, leaf) in
                        view(leaf, plan, content, first: i == 0)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page)
                // Een stap die van de lijst valt — afgevinkt is hij niet weg,
                // maar een eenmalige van gisteren wel — mag de veeg niet
                // buiten de rand laten staan.
                .onChange(of: plan.pages.count) { _, count in
                    if at >= count { at = max(0, count - 1) }
                }
            } else {
                Waiting()
            }
        }
        // Wordt het avond, dan verschuiven de bladzijden; begin dan opnieuw
        // vooraan.
        .onChange(of: household.routine) { at = 0 }
    }

    @ViewBuilder
    private func view(_ leaf: Plan.Page, _ plan: Plan, _ content: Content,
                      first: Bool) -> some View {
        switch leaf {
        case .agenda:
            AgendaPage(blocks: plan.blocks, people: content.people, first: first)
        case .progress:
            ProgressPage(plan: plan, people: content.people, first: first)
        case let .task(i):
            if plan.jobs.indices.contains(i) {
                TaskPage(job: plan.jobs[i], routine: household.routine, people: content.people)
            }
        }
    }
}

/// Zolang er nog niets is: waarom niet, en wat eraan te doen.
private struct Waiting: View {
    @Environment(WatchHousehold.self) private var household
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            if !household.known {
                Text("📱").font(.system(size: 34))
                Text("Open Routines even op je telefoon, dan weet het horloge waar het huis staat.")
                    .textStyle(Wrist.note)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
            } else if !household.error.isEmpty {
                Text("Het huis laden lukte niet (\(household.error)).")
                    .textStyle(Wrist.note)
                    .foregroundStyle(RED)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView().tint(ORANGE)
            }
        }
        .padding(.horizontal, 12)
    }
}
