import Foundation

/// Eén stap, met de naam van het onderdeel waar hij bij hoort.
struct Job: Hashable {
    var group: String
    var step: Step
}

struct Tally {
    var done: Int = 0
    var total: Int = 0
    var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    var complete: Bool { total > 0 && done >= total }
}

/// Welke bladzijden er vandaag zijn, en in welke volgorde.
///
/// Overdag begint het met wat er die ochtend op de agenda staat en daarna de
/// stappen; 's avonds eindigt het ermee, want wat er dan toe doet is morgen.
struct Plan {
    enum Page: Hashable {
        case agenda
        case progress
        case task(Int)
    }

    var pages: [Page] = []
    var blocks: [Block] = []
    var jobs: [Job] = []
    var tallies: [String: Tally] = [:]

    init(_ content: Content, _ routine: Routine, _ now: Date, _ checks: Checks) {
        let today = Today(now)

        blocks = routineBlocks(content, routine, now).filter { !$0.items.isEmpty }

        for group in content[routine] {
            for step in group.steps where !step.label.isEmpty && onDay(step, today) {
                jobs.append(Job(group: group.name, step: step))
            }
        }

        for person in content.people { tallies[person.id] = Tally() }
        for job in jobs {
            for person in participants(job.step, content.people) {
                guard tallies[person.id] != nil else { continue }
                tallies[person.id]?.total += 1
                if checks[checkKey(routine, job.step.key, person.id)] == true {
                    tallies[person.id]?.done += 1
                }
            }
        }

        let cards: [Page] = jobs.indices.map { .task($0) }
        let agenda: [Page] = blocks.isEmpty ? [] : [.agenda]
        let progress: [Page] = [.progress]
        pages = routine == .night
            ? progress + cards + agenda
            : agenda + progress + cards
    }
}
