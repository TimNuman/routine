import Foundation

struct Payload {
    var text: String
    var today: String
    var round: Int
    var children: [Person]
    /// Wat er al staat, in vorm: de groepen met hun tijden en de labels van de
    /// stappen, plus wat er elke week is. Zonder dat stelt de uitlezer *School*
    /// voor de tweede keer voor. De eenmalige dingen blijven thuis — die zeggen
    /// het meest over een gezin en het minst over wat er nog bij moet.
    var house: Content?

    var body: [String: Any] {
        [
            "text": text,
            "today": today,
            "round": round,
            "children": children.map {
                ["id": $0.id, "name": $0.name, "traits": $0.traits,
                 "birthday": $0.birthday] as [String: Any]
            },
            "house": [
                "day": groupsOut(house?.day ?? []),
                "night": groupsOut(house?.night ?? []),
                "week": (house?.week ?? []).map { $0.text }.filter { !$0.isEmpty },
            ],
        ]
    }

    private func groupsOut(_ groups: [StepGroup]) -> [[String: Any]] {
        groups.map { group in
            ["name": group.name, "time": group.time,
             "steps": group.steps.map { $0.label }.filter { !$0.isEmpty }]
        }
    }
}

struct Question {
    var key: String
    var question: String
    var options: [String]
    var multiple: Bool
}

/// Een kind dat de uitlezer voorstelt. Het `id` is wat hij zelf verzon: de
/// andere voorstellen wijzen daarmee naar dit kind, en pas bij het toevoegen
/// wordt het een echt id.
struct NewPerson {
    var id: String
    var name: String
    var emoji: String
    var birthday: String
    var traits: [String: String]
}

struct Suggestion: Identifiable {
    let id = UUID()
    var entry: Entry
    /// Gevuld als dit voorstel een kind is; dan zegt `entry` alleen nog hoe de
    /// regel eruitziet (het gezicht en de naam).
    var person: NewPerson? = nil
    var source: String
}

struct ReadError: LocalizedError {
    var message: String
    var fromServer: Bool
    var errorDescription: String? { message }
}

func askAssistant(_ payload: Payload, _ endpoint: Endpoint?) async throws -> Json {
    guard let endpoint, let address = endpoint.assistant else {
        throw ReadError(message: String(localized: "Er is nog geen adres voor de uitlezer."),
                        fromServer: false)
    }
    var request = URLRequest(url: address)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: payload.body)
    request.timeoutInterval = 90

    let (data, http) = try await endpoint.perform(request)
    let out = Json.parse(data)
    if !(200..<300).contains(http.statusCode) {
        let reason = out["error"].text
        throw ReadError(message: reason.isEmpty ? "HTTP \(http.statusCode)" : reason,
                        fromServer: !reason.isEmpty)
    }
    return out.isNull ? .object(["type": .text("nothing")]) : out
}

private let KINDS = ["occasion", "step", "weekly"]

func cleanSuggestion(_ raw: Json, _ people: [Person]) -> Suggestion? {
    let asked = raw["kind"].text
    let kind = KINDS.contains(asked) ? asked : "occasion"
    let date = isDate(raw["date"].text) ? raw["date"].text : ""

    var entry = Entry()
    entry.icon = raw["icon"].text(kind == "step" ? "⭐" : "🎉")
    entry.text = raw["text"].text.isEmpty ? raw["label"].text : raw["text"].text
    entry.weekly = kind == "weekly"
    entry.task = kind == "step"
    entry.time = raw["time"].text
    entry.until = raw["until"].text
    entry.date = date
    entry.days = daysFrom(raw["days"])
    // Nog niet zeven: een who kan naar een kind wijzen dat in dezelfde ronde
    // voorgesteld wordt. Wie er dan nog niet is valt af bij het toevoegen.
    entry.who = raw["who"].array.map { $0.text }.filter { !$0.isEmpty }
    entry.routine = raw["routine"].text == "night" ? .night : .day
    entry.group = raw["group"].text
    entry.groupTime = raw["groupTime"].text

    if entry.text.isEmpty { return nil }
    guard entry.weekly || !entry.date.isEmpty else { return nil }
    return Suggestion(entry: entry, source: String(raw["source"].text.prefix(200)))
}

/// Een kind uit het aparte lijstje dat de uitlezer terugstuurt. Het staat
/// niet tussen de voorstellen: een kind heeft andere velden, en die passen
/// niet meer bij een voorstel — zie `worker/assistant.ts`.
func cleanPerson(_ raw: Json) -> Suggestion? {
    let name = raw["name"].text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }

    let person = NewPerson(
        id: stepKey(raw["id"].text.isEmpty ? name : raw["id"].text),
        name: name,
        emoji: raw["icon"].text("🙂"),
        birthday: isDate(raw["birthday"].text) ? raw["birthday"].text : "",
        traits: traitsFromLine(raw["traits"].text)
    )

    var entry = Entry()
    entry.icon = person.emoji
    entry.text = name
    return Suggestion(entry: entry, person: person,
                      source: String(raw["source"].text.prefix(200)))
}

/// "school: Vondelschool, schoolgroep: 3B" wordt twee kenmerken.
private func traitsFromLine(_ line: String) -> [String: String] {
    var out: [String: String] = [:]
    for part in line.split(separator: ",") {
        let pair = part.split(separator: ":", maxSplits: 1)
        guard pair.count == 2 else { continue }
        let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty && !value.isEmpty { out[String(key)] = String(value) }
    }
    return out
}

/// Staat dit kind er al? Op de naam, want het id verzint de uitlezer.
func alreadyKnown(_ source: Draft, _ person: NewPerson) -> Bool {
    let name = person.name.lowercased()
    return source.people.contains { $0.name.lowercased() == name }
}

private func entryKey(_ text: String, _ date: String, _ days: [String], _ who: [String]) -> String {
    [text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
     date.trimmingCharacters(in: .whitespacesAndNewlines),
     daysFrom(days).joined(separator: "+"),
     who.joined(separator: "+")].joined(separator: "|")
}

func alreadyKnown(_ source: Draft, _ e: Entry) -> Bool {
    let key = entryKey(e.text, e.date, e.days, e.who)
    if e.task {
        return source[e.routine].contains { group in
            group.steps.contains {
                entryKey($0.label, $0.date, $0.days, $0.who) == key
            }
        }
    }
    if e.weekly {
        return source.week.contains {
            entryKey($0.text, "", $0.days, $0.who) == key
        }
    }
    return source.events.contains {
        entryKey($0.text, $0.date, [], $0.who) == key
    }
}
