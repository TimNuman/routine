import Foundation

struct Payload {
    var text: String
    var today: String
    var round: Int
    var children: [Person]

    var body: [String: Any] {
        [
            "tekst": text,
            "vandaag": today,
            "ronde": round,
            "kinderen": children.map {
                ["id": $0.id, "naam": $0.name, "kenmerken": $0.traits] as [String: Any]
            },
        ]
    }
}

struct Question {
    var key: String
    var question: String
    var options: [String]
    var multiple: Bool
}

struct Suggestion: Identifiable {
    let id = UUID()
    var entry: Entry
    var source: String
}

struct ReadError: LocalizedError {
    var message: String
    var fromServer: Bool
    var errorDescription: String? { message }
}

func askAssistant(_ payload: Payload) async throws -> Json {
    guard let address = Config.assistantURL else {
        throw ReadError(message: "Er is nog geen adres voor de uitlezer.", fromServer: false)
    }
    var request = URLRequest(url: address)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if !Config.key.isEmpty {
        request.setValue(Config.key, forHTTPHeaderField: "X-Routine-Sleutel")
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: payload.body)
    request.timeoutInterval = 90

    let (data, response) = try await URLSession.shared.data(for: request)
    let out = Json.parse(data)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        let reason = out["fout"].text
        throw ReadError(message: reason.isEmpty ? "HTTP \(http.statusCode)" : reason,
                        fromServer: !reason.isEmpty)
    }
    return out.isNull ? .object(["type": .text("niets")]) : out
}

private let KINDS = ["bijzonderheid", "stap", "weekritme"]

func cleanSuggestion(_ raw: Json, _ people: [Person]) -> Suggestion? {
    let asked = raw["soort"].text
    let kind = KINDS.contains(asked) ? asked : "bijzonderheid"
    let known = Set(people.map { $0.id })
    let date = isDate(raw["datum"].text) ? raw["datum"].text : ""

    var entry = Entry()
    entry.icon = raw["icoon"].text(kind == "stap" ? "⭐" : "🎉")
    entry.text = raw["tekst"].text.isEmpty ? raw["label"].text : raw["tekst"].text
    entry.weekly = kind == "weekritme"
    entry.task = kind == "stap"
    entry.time = raw["tijd"].text
    entry.until = raw["tot"].text
    entry.date = date
    entry.days = daysFrom(raw["dagen"])
    entry.who = raw["wie"].array.map { $0.text }.filter { known.contains($0) }
    entry.routine = raw["ritme"].text == "nacht" ? .night : .day
    entry.group = raw["groep"].text

    if entry.text.isEmpty { return nil }
    guard entry.weekly || !entry.date.isEmpty else { return nil }
    return Suggestion(entry: entry, source: String(raw["bron"].text.prefix(200)))
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
