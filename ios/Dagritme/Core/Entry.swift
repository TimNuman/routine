import Foundation

struct Entry {
    var icon: String = "📅"
    var text: String = ""
    var weekly: Bool = true
    var task: Bool = false
    var days: [String] = []
    var date: String = dateString(Date())
    var time: String = ""
    var until: String = ""
    var who: [String] = []
    var routine: Routine = .day
    var group: String = ""
    /// De klok van een groep die nog gemaakt moet worden ("6:00 – 6:30").
    var groupTime: String = ""
    var evening: Bool = false
}

enum Place {
    case week(DraftWeekItem)
    case event(DraftEvent)
    case step(routine: Routine, group: DraftGroup, step: DraftStep)
}

enum Origin {
    case step(group: DraftGroup, index: Int)
    case event(index: Int)
    case week(index: Int)
}

func firstGroupName(_ source: Draft, _ routine: Routine) -> String {
    let groups = source[routine].filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    return groups.last?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func entryFrom(_ source: Draft, _ place: Place?) -> Entry {
    var blank = Entry()
    blank.group = firstGroupName(source, .day)
    guard let place else { return blank }

    switch place {
    case let .step(routine, group, step):
        var out = blank
        out.icon = step.icon
        out.text = step.label
        out.task = true
        out.weekly = !isDate(step.date)
        out.days = step.days
        out.date = isDate(step.date) ? step.date : blank.date
        out.who = step.who
        out.routine = routine
        out.group = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return out

    case let .week(item):
        var out = blank
        out.icon = item.icon
        out.text = item.text
        out.task = false
        out.weekly = true
        out.days = item.days
        out.time = item.time
        out.until = item.until
        out.who = item.who
        out.evening = item.evening
        return out

    case let .event(item):
        var out = blank
        out.icon = item.icon
        out.text = item.text
        out.task = false
        out.weekly = false
        out.date = isDate(item.date) ? item.date : blank.date
        out.time = item.time
        out.until = item.until
        out.who = item.who
        return out
    }
}

@discardableResult
func removeEntry(_ source: Draft, _ place: Place?) -> Origin? {
    guard let place else { return nil }
    switch place {
    case let .step(routine, _, step):
        var origin: Origin?
        for group in source[routine] {
            if let i = group.steps.firstIndex(where: { $0 === step }) {
                origin = .step(group: group, index: i)
                group.steps.remove(at: i)
            }
        }
        return origin

    case let .event(item):
        let i = source.events.firstIndex { $0.id == item.id }
        source.events.removeAll { $0.id == item.id }
        return i.map { .event(index: $0) }

    case let .week(item):
        let i = source.week.firstIndex { $0 === item }
        source.week.removeAll { $0 === item }
        return i.map { .week(index: $0) }
    }
}

private func insertAt<T>(_ list: inout [T], _ fresh: T, _ index: Int?) {
    if let index { list.insert(fresh, at: min(index, list.count)) } else { list.append(fresh) }
}

func placeEntry(_ source: Draft, _ e: Entry, _ id: String, _ origin: Origin?) {
    let trimmed = { (t: String) in t.trimmingCharacters(in: .whitespacesAndNewlines) }

    if e.task {
        var groups = source[e.routine]
        // Een naam die er nog niet is wordt een nieuw onderdeel; zonder naam
        // valt de stap in het laatste onderdeel dat er is.
        let wanted = trimmed(e.group)
        var target = groups.first { trimmed($0.name) == wanted }
        if target == nil && wanted.isEmpty { target = groups.last }
        if target == nil {
            let fresh = DraftGroup(name: trimmed(e.group).isEmpty
                                       ? String(localized: "Erbij") : trimmed(e.group),
                                   time: trimmed(e.groupTime), steps: [])
            groups.append(fresh)
            target = fresh
        }
        source[e.routine] = groups
        guard let target else { return }
        var slot: Int?
        if case let .step(group, index) = origin, group === target { slot = index }
        insertAt(&target.steps, DraftStep(
            icon: trimmed(e.icon).isEmpty ? "⭐" : trimmed(e.icon),
            label: trimmed(e.text),
            days: e.weekly ? daysFrom(e.days) : [],
            date: e.weekly ? "" : trimmed(e.date),
            who: e.who
        ), slot)
        return
    }

    if e.weekly {
        var slot: Int?
        if case let .week(index) = origin { slot = index }
        insertAt(&source.week, DraftWeekItem(
            icon: trimmed(e.icon).isEmpty ? "📅" : trimmed(e.icon),
            text: trimmed(e.text),
            time: trimmed(e.time),
            until: trimmed(e.until),
            days: daysFrom(e.days),
            who: e.who,
            evening: e.evening
        ), slot)
        return
    }

    var slot: Int?
    if case let .event(index) = origin { slot = index }
    insertAt(&source.events, DraftEvent(
        id: id.isEmpty ? newId() : id,
        icon: trimmed(e.icon).isEmpty ? "🎉" : trimmed(e.icon),
        text: trimmed(e.text),
        time: trimmed(e.time),
        until: trimmed(e.until),
        date: trimmed(e.date),
        who: e.who
    ), slot)
}

func moveEntry(_ source: Draft, _ place: Place?, _ e: Entry) -> String? {
    if e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return String(localized: "Vul een naam in.")
    }
    if !e.weekly && !isDate(e.date) {
        return String(localized: "Vul een datum in, of zet hem op herhalen.")
    }
    var id = newId()
    if case let .event(item) = place { id = item.id }
    let origin = removeEntry(source, place)
    placeEntry(source, e, id, origin)
    return nil
}
