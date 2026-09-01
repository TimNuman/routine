import Foundation

enum Routine: String, Codable, Hashable, CaseIterable {
    case day
    case night
}

struct Person: Identifiable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var color: String
    var traits: [String: String]
}

struct Step: Hashable {
    var icon: String
    var label: String
    var days: [String]
    var date: String
    var who: [String]
    let key: String

    init(icon: String, label: String, days: [String], date: String, who: [String]) {
        self.icon = icon
        self.label = label
        self.days = days
        self.date = date
        self.who = who
        self.key = stepKey(label)
    }
}

struct StepGroup: Hashable {
    var name: String
    var time: String
    var steps: [Step]
}

struct WeekItem: Hashable {
    var icon: String
    var text: String
    var time: String
    var until: String
    var days: [String]
    var who: [String]
    var evening: Bool
}

struct OneOff: Identifiable, Hashable {
    var id: String
    var icon: String
    var text: String
    var time: String
    var until: String
    var date: String
    var who: [String]
}

struct AgendaItem: Hashable {
    var icon: String
    var text: String
    var time: String
    var until: String
    var days: [String]
    var who: [String]
    var evening: Bool
    var id: String?
    var date: String?
    var special: Bool

    init(week: WeekItem) {
        icon = week.icon
        text = week.text
        time = week.time
        until = week.until
        days = week.days
        who = week.who
        evening = week.evening
        id = nil
        date = nil
        special = false
    }

    init(oneOff: OneOff) {
        icon = oneOff.icon
        text = oneOff.text
        time = oneOff.time
        until = oneOff.until
        days = []
        who = oneOff.who
        evening = false
        id = oneOff.id
        date = oneOff.date
        special = true
    }
}

struct Content: Hashable {
    var title: String
    var people: [Person]
    var day: [StepGroup]
    var night: [StepGroup]
    var week: [WeekItem]
    var events: [OneOff]

    subscript(routine: Routine) -> [StepGroup] {
        get { routine == .day ? day : night }
        set { if routine == .day { day = newValue } else { night = newValue } }
    }
}

struct Block: Identifiable {
    var heading: String
    var items: [AgendaItem]
    var later: Bool = false
    var id: String { heading }
}

enum OneOffEntry {
    case event(date: String, item: OneOff)
    case step(date: String, routine: Routine, group: StepGroup, step: Step)

    var date: String {
        switch self {
        case let .event(date, _): return date
        case let .step(date, _, _, _): return date
        }
    }
}
