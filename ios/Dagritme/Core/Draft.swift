import Foundation

final class DraftPerson: Identifiable {
    var id: String
    var name: String
    var emoji: String
    var color: String
    var traits: [String: String]
    var birthday: String

    init(id: String, name: String, emoji: String, color: String,
         traits: [String: String], birthday: String = "") {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.traits = traits
        self.birthday = birthday
    }
}

final class DraftStep: Identifiable {
    var icon: String
    var label: String
    var days: [String]
    var date: String
    var who: [String]

    init(icon: String, label: String, days: [String], date: String, who: [String]) {
        self.icon = icon
        self.label = label
        self.days = days
        self.date = date
        self.who = who
    }
}

final class DraftGroup: Identifiable {
    var name: String
    var time: String
    var steps: [DraftStep]

    init(name: String, time: String, steps: [DraftStep]) {
        self.name = name
        self.time = time
        self.steps = steps
    }
}

final class DraftWeekItem: Identifiable {
    var icon: String
    var text: String
    var time: String
    var until: String
    var days: [String]
    var who: [String]
    var evening: Bool

    init(icon: String, text: String, time: String, until: String,
         days: [String], who: [String], evening: Bool) {
        self.icon = icon
        self.text = text
        self.time = time
        self.until = until
        self.days = days
        self.who = who
        self.evening = evening
    }
}

final class DraftEvent: Identifiable {
    var id: String
    var icon: String
    var text: String
    var time: String
    var until: String
    var date: String
    var who: [String]

    init(id: String, icon: String, text: String, time: String, until: String,
         date: String, who: [String]) {
        self.id = id
        self.icon = icon
        self.text = text
        self.time = time
        self.until = until
        self.date = date
        self.who = who
    }
}

final class Draft {
    var title: String
    var people: [DraftPerson]
    var day: [DraftGroup]
    var night: [DraftGroup]
    var week: [DraftWeekItem]
    var events: [DraftEvent]

    init(title: String, people: [DraftPerson], day: [DraftGroup],
         night: [DraftGroup], week: [DraftWeekItem], events: [DraftEvent]) {
        self.title = title
        self.people = people
        self.day = day
        self.night = night
        self.week = week
        self.events = events
    }

    subscript(routine: Routine) -> [DraftGroup] {
        get { routine == .day ? day : night }
        set { if routine == .day { day = newValue } else { night = newValue } }
    }
}

func isDate(_ value: String) -> Bool {
    value.matchesWhole(pattern: "\\d{4}-\\d{2}-\\d{2}")
}

func asDate(_ value: String) -> Date? {
    guard isDate(value) else { return nil }
    let parts = value.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var stamp = DateComponents()
    stamp.year = parts[0]
    stamp.month = parts[1]
    stamp.day = parts[2]
    return calendar.date(from: stamp)
}

func shortDate(_ value: String) -> String {
    guard let d = asDate(value) else { return "" }
    return d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        .locale(.autoupdatingCurrent))
}

func daysText(_ days: [String]) -> String {
    if days.isEmpty || days.count >= WEEKDAYS.count { return "" }
    let picked = Set(days)
    if picked == WORKDAYS { return String(localized: "weekdagen") }
    if picked == WEEKEND { return String(localized: "weekend") }
    return WEEKDAYS.filter { picked.contains($0) }.map(dayLabel).joined(separator: ", ")
}

func daysFrom(_ value: [String]) -> [String] {
    value
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { DAYS.contains($0) }
}

func asDraft(_ content: Content) -> Draft {
    Draft(
        title: content.title,
        people: content.people.map {
            DraftPerson(id: $0.id, name: $0.name, emoji: $0.emoji, color: $0.color,
                        traits: $0.traits, birthday: $0.birthday)
        },
        day: content.day.map(draftGroup),
        night: content.night.map(draftGroup),
        week: content.week.map {
            DraftWeekItem(icon: $0.icon, text: $0.text, time: $0.time, until: $0.until,
                          days: $0.days, who: $0.who, evening: $0.evening)
        },
        events: content.events.map {
            DraftEvent(id: $0.id, icon: $0.icon, text: $0.text, time: $0.time,
                       until: $0.until, date: $0.date, who: $0.who)
        }
    )
}

private func draftGroup(_ group: StepGroup) -> DraftGroup {
    DraftGroup(name: group.name, time: group.time, steps: group.steps.map {
        DraftStep(icon: $0.icon, label: $0.label, days: $0.days, date: $0.date, who: $0.who)
    })
}

private func cleanGroups(_ list: [DraftGroup]) -> [[String: Any]] {
    list.map { g -> [String: Any] in
        let steps: [[String: Any]] = g.steps
            .filter { !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { s in
                var out: [String: Any] = [
                    "icon": s.icon.isEmpty ? "⭐" : s.icon,
                    "label": s.label.trimmingCharacters(in: .whitespacesAndNewlines),
                ]
                if isDate(s.date) { out["date"] = s.date }
                let days = daysFrom(s.days)
                if !days.isEmpty && out["date"] == nil { out["days"] = days }
                if !s.who.isEmpty { out["who"] = s.who }
                return out
            }
        return [
            "name": g.name.trimmingCharacters(in: .whitespacesAndNewlines),
            "time": g.time.trimmingCharacters(in: .whitespacesAndNewlines),
            "steps": steps,
        ]
    }.filter { g in
        let steps = g["steps"] as? [[String: Any]] ?? []
        let name = g["name"] as? String ?? ""
        return !steps.isEmpty || !name.isEmpty
    }
}

private func cleanWeek(_ source: [DraftWeekItem], _ from: Int) -> [[String: Any]] {
    source
        .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map { item in
            var out: [String: Any] = [
                "icon": item.icon.isEmpty ? "📅" : item.icon,
                "text": item.text.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            let time = item.time.trimmingCharacters(in: .whitespacesAndNewlines)
            let until = item.until.trimmingCharacters(in: .whitespacesAndNewlines)
            if !time.isEmpty { out["time"] = time }
            if !until.isEmpty { out["until"] = until }
            let days = daysFrom(item.days)
            if !days.isEmpty && days.count < WEEKDAYS.count { out["days"] = days }
            if !item.who.isEmpty { out["who"] = item.who }
            if isEvening(time: time, until: until, evening: item.evening, from: from) {
                out["evening"] = true
            }
            return out
        }
}

private func cleanEvents(_ source: [DraftEvent]) -> [[String: Any]] {
    let limit = dateString(Date())
    return source
        .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isDate($0.date) }
        .filter { $0.date >= limit }
        .map { e in
            var out: [String: Any] = [
                "id": e.id.isEmpty ? newId() : e.id,
                "icon": e.icon.isEmpty ? "🎉" : e.icon,
                "text": e.text.trimmingCharacters(in: .whitespacesAndNewlines),
                "date": e.date,
            ]
            let time = e.time.trimmingCharacters(in: .whitespacesAndNewlines)
            let until = e.until.trimmingCharacters(in: .whitespacesAndNewlines)
            if !time.isEmpty { out["time"] = time }
            if !until.isEmpty { out["until"] = until }
            if !e.who.isEmpty { out["who"] = e.who }
            return out
        }
}

func cleaned(_ c: Draft) -> [String: Any] {
    let from = EVENING_FROM
    let title = c.title.trimmingCharacters(in: .whitespacesAndNewlines)
    return [
        "version": 2,
        "title": title.isEmpty ? String(localized: "Ons dagritme") : title,
        "eveningFrom": from,
        "people": c.people.enumerated().map { (i, p) -> [String: Any] in
            [
                "id": p.id.isEmpty ? newId() : p.id,
                "name": p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? String(localized: "Naamloos")
                    : p.name.trimmingCharacters(in: .whitespacesAndNewlines),
                "emoji": p.emoji.isEmpty ? "🙂" : p.emoji,
                "color": p.color.isEmpty ? COLORS[i % COLORS.count] : p.color,
                "traits": p.traits,
                "birthday": isDate(p.birthday) ? p.birthday : "",
            ]
        },
        "day": cleanGroups(c.day),
        "night": cleanGroups(c.night),
        "week": cleanWeek(c.week, from),
        "events": cleanEvents(c.events),
    ]
}

func countSteps(_ groups: [[String: Any]]) -> Int {
    groups.reduce(0) { $0 + (($1["steps"] as? [[String: Any]])?.count ?? 0) }
}

extension Array {
    mutating func moveItem(_ from: Int, _ to: Int) {
        guard indices.contains(from), indices.contains(to), from != to else { return }
        let item = remove(at: from)
        insert(item, at: to)
    }
}
