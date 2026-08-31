import Foundation

let DAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
let COLORS = ["#2FA37C", "#7C6BD6", "#D9724F", "#3B82C4", "#C2417E", "#E0A33E"]
let WEEKDAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
let WORKDAYS: Set<String> = ["mon", "tue", "wed", "thu", "fri"]
let WEEKEND: Set<String> = ["sat", "sun"]

let EVENING_FROM = 17

let calendar = Calendar.current

private let symbols: Calendar = {
    var c = Calendar.current
    c.locale = .autoupdatingCurrent
    return c
}()

func dayLetter(_ code: String) -> String {
    guard let i = DAYS.firstIndex(of: code) else { return "" }
    return symbols.veryShortStandaloneWeekdaySymbols[i]
}

func dayLabel(_ code: String) -> String {
    guard let i = DAYS.firstIndex(of: code) else { return code }
    return symbols.shortStandaloneWeekdaySymbols[i].lowercased()
}

func weekdayIndex(_ d: Date) -> Int {
    calendar.component(.weekday, from: d) - 1
}

func dateString(_ d: Date) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

func dateText(_ d: Date) -> String {
    d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.autoupdatingCurrent))
}

func weekOf(_ d: Date, _ weeks: Int = 0) -> [Date] {
    let shift = -((weekdayIndex(d) + 6) % 7) + weeks * 7
    let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: shift, to: d) ?? d)
    return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start) ?? start }
}

func traitsFrom(_ value: Json) -> [String: String] {
    var out: [String: String] = [:]
    for key in value.keys {
        let name = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = value[key].text
        if !name.isEmpty && !content.isEmpty { out[name] = content }
    }
    return out
}

func daysFrom(_ value: Json) -> [String] {
    value.array
        .map { $0.text.lowercased() }
        .filter { DAYS.contains($0) }
}

func whoFrom(_ item: Json) -> [String] {
    item["who"].array.map { $0.text }.filter { !$0.isEmpty }
}

private func isDateString(_ value: String) -> Bool {
    value.matchesWhole(pattern: "\\d{4}-\\d{2}-\\d{2}")
}

private func makeGroups(_ value: Json) -> [StepGroup] {
    let list = value.array
    if list.isEmpty { return [] }
    let grouped = list.contains { !$0["steps"].isNull || !$0["name"].isNull }
    let raw: [Json] = grouped
        ? list
        : [.object(["name": .text(""), "time": .text(""), "steps": .array(list)])]
    return raw.map { item in
        StepGroup(
            name: item["name"].text,
            time: item["time"].text,
            steps: item["steps"].array.map { s in
                Step(
                    icon: s["icon"].text("⭐"),
                    label: s["label"].text,
                    days: daysFrom(s["days"]),
                    date: isDateString(s["date"].text) ? s["date"].text : "",
                    who: whoFrom(s)
                )
            }
        )
    }
}

private func timeRange(_ raw: Json) -> (time: String, until: String) {
    var time = raw["time"].text
    var until = raw["until"].text
    if until.isEmpty,
       let parts = time.firstMatch(pattern: "^(.*?)\\s*(?:–|—|-|tot|t/m)\\s*(.+)$"),
       parts.count == 3,
       hourFromTime(parts[1]) != nil, hourFromTime(parts[2]) != nil {
        time = parts[1].trimmingCharacters(in: .whitespaces)
        until = parts[2].trimmingCharacters(in: .whitespaces)
    }
    return (time, until)
}

func minuteFromTime(_ value: String) -> Int? {
    let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let found = t.firstMatch(pattern: "(\\d{1,2})\\s*[:.uh]\\s*(\\d{2})?")
        ?? t.firstMatch(pattern: "^\\s*(\\d{1,2})\\s*$")
    guard let parts = found, let hour = Int(parts[1]), (0...23).contains(hour) else { return nil }
    let minute = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
    return hour * 60 + ((0...59).contains(minute) ? minute : 0)
}

func hourFromTime(_ value: String) -> Int? {
    minuteFromTime(value).map { $0 / 60 }
}

func minuteOfDay(_ d: Date) -> Int {
    let parts = calendar.dateComponents([.hour, .minute], from: d)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
}

extension AgendaItem {
    var startsAt: Int? { minuteFromTime(time) ?? minuteFromTime(until) }

    var endsAt: Int? { minuteFromTime(until) ?? minuteFromTime(time) }
}

func isEvening(time: String, until: String, evening: Bool, from: Int) -> Bool {
    guard let hour = hourFromTime(time) ?? hourFromTime(until) else { return evening }
    return hour >= from
}

func isEvening(_ item: AgendaItem, _ from: Int) -> Bool {
    isEvening(time: item.time, until: item.until, evening: item.evening, from: from)
}

func timeText(time: String, until: String) -> String {
    if !time.isEmpty && !until.isEmpty { return "\(time) – \(until)" }
    if !until.isEmpty { return String(localized: "tot \(until)") }
    return time
}

func timeText(_ item: AgendaItem) -> String { timeText(time: item.time, until: item.until) }

private func weekItem(_ raw: Json) -> WeekItem {
    let clock = timeRange(raw)
    return WeekItem(
        icon: raw["icon"].text("📅"),
        text: raw["text"].text,
        time: clock.time,
        until: clock.until,
        days: daysFrom(raw["days"]),
        who: whoFrom(raw),
        evening: raw["evening"].flag
    )
}

private func weekList(_ value: Json) -> [WeekItem] {
    let flat = { value.array.map(weekItem).filter { !$0.text.isEmpty } }
    guard value.isObject, !value.isArray else { return flat() }
    let keys = value.keys
    let perDay = !keys.isEmpty && keys.allSatisfy {
        DAYS.contains($0.trimmingCharacters(in: .whitespaces).lowercased())
    }
    if !perDay { return flat() }

    var out: [WeekItem] = []
    var seen: [String: Int] = [:]
    for day in WEEKDAYS {
        for raw in value[day].array {
            var item = weekItem(raw)
            if item.text.isEmpty { continue }
            let key = [item.icon, item.text, item.time, item.until,
                       item.who.joined(separator: "+"), String(item.evening)].joined(separator: "|")
            if let earlier = seen[key] {
                out[earlier].days.append(day)
                continue
            }
            item.days = [day]
            seen[key] = out.count
            out.append(item)
        }
    }
    for i in out.indices where out[i].days.count == 7 { out[i].days = [] }
    return out
}

private func oneOff(_ raw: Json) -> OneOff {
    let clock = timeRange(raw)
    return OneOff(
        id: raw["id"].text.isEmpty ? newId("e") : raw["id"].text,
        icon: raw["icon"].text("🎉"),
        text: raw["text"].text,
        time: clock.time,
        until: clock.until,
        date: isDateString(raw["date"].text) ? raw["date"].text : "",
        who: whoFrom(raw)
    )
}

func normalize(_ raw: Json) -> Content {
    let people = raw["people"].array.enumerated().map { (i, p) in
        Person(
            id: p["id"].text("p\(i)"),
            name: p["name"].text(String(localized: "Naamloos")),
            emoji: p["emoji"].text("🙂"),
            color: p["color"].text(COLORS[i % COLORS.count]),
            traits: traitsFrom(p["traits"])
        )
    }
    var out = Content(
        title: raw["title"].text(String(localized: "Ons dagritme")),
        people: people,
        day: makeGroups(raw["day"]),
        night: makeGroups(raw["night"]),
        week: weekList(raw["week"]),
        events: raw["events"].array.map(oneOff)
            .filter { !$0.text.isEmpty && !$0.date.isEmpty }
            .sorted { ($0.date, $0.time) < ($1.date, $1.time) }
    )
    let known = Set(people.map { $0.id })
    let onlyKnown = { (who: [String]) in who.filter { known.contains($0) } }
    for routine in [Routine.day, .night] {
        var groups = out[routine]
        for g in groups.indices {
            for s in groups[g].steps.indices {
                groups[g].steps[s].who = onlyKnown(groups[g].steps[s].who)
            }
        }
        out[routine] = groups
    }
    for i in out.week.indices { out.week[i].who = onlyKnown(out.week[i].who) }
    for i in out.events.indices { out.events[i].who = onlyKnown(out.events[i].who) }
    return out
}

func itemsOn(_ content: Content, _ d: Date) -> [AgendaItem] {
    let day = DAYS[weekdayIndex(d)]
    let date = dateString(d)
    let special = content.events.filter { $0.date == date }.map { AgendaItem(oneOff: $0) }
    let weekly = content.week
        .filter { $0.days.isEmpty || $0.days.contains(day) }
        .map { AgendaItem(week: $0) }
    return special + weekly
}

func routineBlocks(_ content: Content, _ routine: Routine, _ now: Date) -> [Block] {
    let clock = minuteOfDay(now)
    let daytime = { (d: Date) in itemsOn(content, d).filter { !isEvening($0, EVENING_FROM) } }

    if routine != .night {
        return [Block(heading: String(localized: "Vandaag"),
                      items: byTime(daytime(now), past: clock))]
    }
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
    return [
        Block(heading: String(localized: "Vanavond"),
              items: byTime(itemsOn(content, now).filter { isEvening($0, EVENING_FROM) },
                            past: clock)),
        Block(heading: String(localized: "Morgen"),
              items: byTime(daytime(tomorrow), past: nil), later: true),
    ]
}

func byTime(_ items: [AgendaItem], past clock: Int?) -> [AgendaItem] {
    items
        .filter { item in
            guard let clock, let end = item.endsAt else { return true }
            return end > clock
        }
        .enumerated()
        .sorted { left, right in
            switch (left.element.startsAt, right.element.startsAt) {
            case let (l?, r?): return l == r ? left.offset < right.offset : l < r
            case (nil, .some): return true
            case (.some, nil): return false
            case (nil, nil): return left.offset < right.offset
            }
        }
        .map(\.element)
}

func stepKey(_ step: Step) -> String {
    let flat = step.label.lowercased()
        .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "nl_NL"))
    var out = ""
    var dash = false
    for scalar in flat.unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
            if dash && !out.isEmpty { out.append("-") }
            dash = false
            out.unicodeScalars.append(scalar)
        } else {
            dash = true
        }
    }
    return out.isEmpty ? "stap" : out
}

func onDay(_ step: Step, _ d: Date) -> Bool {
    if !step.date.isEmpty { return step.date == dateString(d) }
    if step.days.isEmpty { return true }
    return step.days.contains(DAYS[weekdayIndex(d)])
}

func stepCount(_ groups: [StepGroup]) -> Int {
    groups.reduce(0) { $0 + $1.steps.count }
}

func oneOffEntries(_ content: Content) -> [OneOffEntry] {
    var out: [OneOffEntry] = content.events
        .filter { !$0.date.isEmpty }
        .map { .event(date: $0.date, item: $0) }
    for routine in [Routine.day, .night] {
        for group in content[routine] {
            for step in group.steps where !step.date.isEmpty {
                out.append(.step(date: step.date, routine: routine, group: group, step: step))
            }
        }
    }
    return out.sorted { a, b in
        if a.date != b.date { return a.date < b.date }
        let timeOf = { (entry: OneOffEntry) -> String in
            if case let .event(_, item) = entry { return item.time }
            return ""
        }
        return timeOf(a) < timeOf(b)
    }
}

func participants(_ step: Step, _ people: [Person]) -> [Person] {
    step.who.isEmpty ? people : people.filter { step.who.contains($0.id) }
}

func newId(_ prefix: String = "p") -> String {
    prefix + String(UUID().uuidString.lowercased().prefix(6))
}

extension String {
    func firstMatch(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self))
        else { return nil }
        return (0..<match.numberOfRanges).map { i in
            guard let range = Range(match.range(at: i), in: self) else { return "" }
            return String(self[range])
        }
    }

    func matchesWhole(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "^(?:" + pattern + ")$"),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self))
        else { return false }
        return match.range.length == (self as NSString).length
    }
}
