import SwiftUI

/// Eén stap, groot: hetzelfde kaartje als op de telefoon — het plaatje, de
/// naam, en de gezichtjes eronder om af te vinken. Vegen brengt de volgende.
struct TaskPage: View {
    let job: Job
    let routine: Routine
    let people: [Person]

    @Environment(WatchHousehold.self) private var household
    @Environment(\.palette) private var palette
    @Environment(\.sizes) private var m

    private var taking: [Person] { participants(job.step, people) }

    private var allDone: Bool {
        !taking.isEmpty && taking.allSatisfy { household.done(routine, job.step, $0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                if !job.group.isEmpty {
                    Text(job.group)
                        .textStyle(Wrist.group)
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }

                Glass(radius: 20) {
                    VStack(spacing: 7) {
                        Text(job.step.icon)
                            .font(.system(size: m.icon))
                            .scaleEffect(allDone ? 1.10 : 1)
                        Text(job.step.label)
                            .textStyle(Wrist.task(m.name))
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Flow(gap: 3, rowGap: 3, centered: true) {
                            ForEach(taking) { person in
                                Face(
                                    person: person,
                                    step: job.step,
                                    on: household.done(routine, job.step, person),
                                    size: m.face,
                                    glyph: m.glyph,
                                    onTap: {
                                        household.toggle(
                                            checkKey(routine, job.step.key, person.id))
                                    }
                                )
                            }
                        }
                        .padding(.top, 1)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                }
                .scaleEffect(allDone ? 0.985 : 1)
                .animation(Motion.pop, value: allDone)
            }
            .padding(.horizontal, m.gutter)
            .padding(.bottom, 12)
        }
    }
}
