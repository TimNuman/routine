import Foundation

/// "Emma", "Emma en Mads", "Emma, Mads en Julia".
func namesOf(_ people: [Person]) -> String {
    let names = people.map(\.name).filter { !$0.isEmpty }
    if names.isEmpty { return String(localized: "nog niemand") }
    return ListFormatter.localizedString(byJoining: names)
}

enum Spoken {
    static func step(_ step: String, _ person: String) -> String {
        String(format: NSLocalizedString(
            "a11y.step.person", value: "%1$@, %2$@",
            comment: "VoiceOver label for one child's circle on a step card"), step, person)
    }

    static let stepDone = String(localized: "a11y.step.done", defaultValue: "afgevinkt",
                                 comment: "State of a ticked circle")
    static let stepOpen = String(localized: "a11y.step.open", defaultValue: "nog niet afgevinkt",
                                 comment: "State of an unticked circle")

    static func tally(_ done: Int, _ total: Int) -> String {
        String(format: NSLocalizedString(
            "a11y.tally", value: "%1$lld van %2$lld af",
            comment: "VoiceOver value for a child's progress bar"), done, total)
    }

    static func soloChild(_ name: String) -> String {
        String(format: NSLocalizedString(
            "a11y.child.solo", value: "Alleen %@ tonen",
            comment: "Tapping a progress tile when everyone is shown"), name)
    }

    static func hideChild(_ name: String) -> String {
        String(format: NSLocalizedString(
            "a11y.child.hide", value: "%@ verbergen",
            comment: "Tapping a progress tile that is currently shown"), name)
    }

    static func showChild(_ name: String) -> String {
        String(format: NSLocalizedString(
            "a11y.child.show", value: "%@ er weer bij",
            comment: "Tapping a progress tile that is currently hidden"), name)
    }

    static let close = String(localized: "a11y.close", defaultValue: "Sluiten",
                              comment: "Tapping the dimmed backdrop behind a sheet")
    static let icon = String(localized: "a11y.icon", defaultValue: "Icoon",
                             comment: "The emoji button in a form")
    static let color = String(localized: "a11y.color", defaultValue: "Kleur",
                              comment: "A colour swatch in the child form")
    static let date = String(localized: "a11y.date", defaultValue: "Datum",
                             comment: "The date picker in the entry form")
    static let message = String(localized: "a11y.message", defaultValue: "Bericht om uit te lezen",
                                comment: "The paste box in the assistant sheet")
    static let previousWeek = String(localized: "a11y.week.previous", defaultValue: "Vorige week",
                                     comment: "Arrow left of the week strip")
    static let nextWeek = String(localized: "a11y.week.next", defaultValue: "Volgende week",
                                 comment: "Arrow right of the week strip")
    static let take = String(localized: "a11y.suggestion.take", defaultValue: "Wel overnemen",
                             comment: "Checkbox on an unchecked suggestion")
    static let skip = String(localized: "a11y.suggestion.skip", defaultValue: "Niet overnemen",
                             comment: "Checkbox on a checked suggestion")
}
