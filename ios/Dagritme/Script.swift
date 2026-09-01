import SwiftUI

/// Alleen voor Driver: een rijtje tikken dat de app zelf uitvoert, met echte
/// tussenpozen. De UI-test wacht vóór elke tik tot de app stilstaat en kan dus
/// nooit midden in een schuif tikken; dit wel. Komt uit `SCRIPT` in de
/// omgeving, bijvoorbeeld `wait 3, week, wait 0.15, instellingen, ritme, avond`.
@MainActor
enum Script {
    static func run(_ household: Household) async {
        guard let raw = ProcessInfo.processInfo.environment["SCRIPT"], !raw.isEmpty else { return }
        for step in raw.split(separator: ",") {
            let words = step.split(separator: " ").map(String.init)
            switch words.first {
            case "wait":
                let seconds = words.dropFirst().first.flatMap(Double.init) ?? 1
                try? await Task.sleep(for: .seconds(seconds))
            case "ritme": household.go(.routine)
            case "week": household.go(.week)
            case "instellingen": household.go(.settings)
            case "ochtend": household.setRoutine(.day)
            case "avond": household.setRoutine(.night)
            // Het eerste vinkje van het eerste kind, zoals een tik op de ring.
            case "vink":
                if let content = household.content, let person = content.people.first,
                   let step = content[household.routine].first?.steps.first {
                    household.toggle(checkKey(household.routine, step.key, person.id))
                }
            case "herlaad": await household.reload()
            default: break
            }
        }
    }
}
