import SwiftUI

private let MAX_QUESTIONS = 2

struct AssistantSheet: View {
    let content: Content
    let onCancel: () -> Void
    let onSave: (Draft) async -> String?

    private enum Phase { case paste, busy, question, suggestions, nothing }

    @Environment(\.palette) private var palette

    @State private var phase: Phase = .paste
    @State private var alert = ""
    @State private var message = ""
    @State private var round = 0
    @State private var asked = 0
    @State private var question: Question?
    @State private var answers: [String: [String]] = [:]
    @State private var items: [Suggestion] = []
    @State private var picked: [Bool] = []
    @State private var editing: Int?
    @State private var draft: Draft?

    private var pickedCount: Int { picked.filter { $0 }.count }

    private var title: String {
        switch phase {
        case .busy: return "Even lezen"
        case .nothing: return "Niets gevonden"
        case .question: return "Even iets vragen"
        case .suggestions: return "Dit haalde ik eruit"
        case .paste: return "Typ of plak iets"
        }
    }

    private var button: String {
        switch phase {
        case .busy: return "Even lezen…"
        case .nothing: return "Opnieuw proberen"
        case .question: return "Ga verder"
        case .suggestions: return pickedCount == 1
            ? "Zet er 1 in de app" : "Zet er \(pickedCount) in de app"
        case .paste: return "Lees uit"
        }
    }

    var body: some View {
        ZStack {
            Sheet(title: title, alert: alert, button: button,
                  busy: phase == .busy || (phase == .suggestions && pickedCount == 0),
                  onCancel: onCancel, onButton: next) {
                switch phase {
                case .paste:
                    FormHead("De tekst", first: true)
                    PasteBox(value: $message)

                case .busy:
                    Busy("Even kijken wat erin staat…")

                case .nothing:
                    Busy("""
                        Hier kon ik niets uithalen dat in de app hoort. Probeer het wat concreter, \
                        of plak er meer bij.
                        """)

                case .question:
                    if let question {
                        FormHead("Vraag", first: true)
                        Note(question.question)
                        ForEach(content.people) { person in
                            AskChild(
                                person: person,
                                question: question,
                                picked: answers[person.id] ?? [],
                                onPick: { option in choose(person, option, question) },
                                onNone: { answers[person.id] = [] }
                            )
                        }
                    }

                case .suggestions:
                    FormHead("Voorstellen", first: true)
                    Glass(radius: 22) {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { (i, item) in
                                if i > 0 { HairLine() }
                                Found(
                                    item: item,
                                    on: i < picked.count && picked[i],
                                    people: content.people,
                                    onCheck: { if i < picked.count { picked[i].toggle() } },
                                    onOpen: { draft = asDraft(content); editing = i }
                                )
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if let i = editing, i < items.count, let working = draft {
                EntrySheet(
                    title: items[i].entry.text.isEmpty ? "Voorstel" : items[i].entry.text,
                    entry: withGroup(items[i].entry, working),
                    place: nil,
                    source: { working },
                    people: content.people,
                    onCancel: { editing = nil },
                    onSave: { fresh in
                        let source = items[i].source
                        items[i] = Suggestion(entry: fresh, source: source)
                        if i < picked.count { picked[i] = true }
                        editing = nil
                    }
                )
            }
        }
    }

    private func withGroup(_ entry: Entry, _ working: Draft) -> Entry {
        var out = entry
        if out.group.trimmingCharacters(in: .whitespaces).isEmpty {
            out.group = firstGroupName(working, out.routine)
        }
        return out
    }

    private func choose(_ person: Person, _ option: String, _ question: Question) {
        var current = answers[person.id] ?? []
        if let i = current.firstIndex(of: option) {
            current.remove(at: i)
        } else if question.multiple {
            current.append(option)
        } else {
            current = [option]
        }
        answers[person.id] = current
    }

    private func next() {
        switch phase {
        case .nothing:
            phase = .paste
        case .paste:
            if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                alert = "Plak eerst een bericht."
                return
            }
            Task { await read() }
        case .question:
            Task {
                if await saveAnswers() { await read() }
            }
        case .suggestions:
            Task { await apply() }
        case .busy:
            break
        }
    }

    private func read() async {
        alert = ""
        phase = .busy
        let out: Json
        do {
            out = try await askAssistant(Payload(
                text: message,
                today: dateString(Date()),
                round: round + 1,
                children: content.people
            ))
        } catch let problem as ReadError {
            phase = .paste
            alert = problem.fromServer ? problem.message
                                       : "Het uitlezen lukte niet (\(problem.message))."
            return
        } catch {
            phase = .paste
            alert = "Het uitlezen lukte niet (\(error.localizedDescription))."
            return
        }

        round += 1
        let kind = out["type"].text
        let options = out["options"].array.map { $0.text }.filter { !$0.isEmpty }
        if kind == "question" && !options.isEmpty && asked < MAX_QUESTIONS {
            asked += 1
            answers = [:]
            question = Question(
                key: out["key"].text("kenmerk"),
                question: out["question"].text("Waar hoort dit bij?"),
                options: options,
                multiple: out["multiple"].flag
            )
            phase = .question
            return
        }

        let found = out["items"].array.compactMap { cleanSuggestion($0, content.people) }
        items = found
        picked = found.map { _ in true }
        phase = found.isEmpty ? .nothing : .suggestions
    }

    private func saveAnswers() async -> Bool {
        guard let question else { return true }
        let working = asDraft(content)
        var any = false
        for person in working.people {
            let chosen = (answers[person.id] ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if chosen.isEmpty {
                person.traits.removeValue(forKey: question.key)
            } else {
                person.traits[question.key] = chosen.joined(separator: ", ")
                any = true
            }
        }
        if !any { return true }
        if let problem = await onSave(working) {
            alert = problem
            return false
        }
        return true
    }

    private func apply() async {
        let chosen = items.enumerated().filter { $0.offset < picked.count && picked[$0.offset] }
            .map { $0.element }
        if chosen.isEmpty {
            alert = "Kies er minstens één."
            return
        }
        let working = asDraft(content)
        for suggestion in chosen where !alreadyKnown(working, suggestion.entry) {
            placeEntry(working, suggestion.entry, "", nil)
        }
        if let problem = await onSave(working) { alert = problem } else { onCancel() }
    }
}

private struct PasteBox: View {
    @Binding var value: String
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .topLeading) {
            if value.isEmpty {
                Text("Plak een mail of appje, of typ het gewoon:\n\niedere dinsdag om 18:00 tennis Emma")
                    .textStyle(TextStyle(font: Fonts.nunito(14)))
                    .foregroundStyle(SOFT_INK.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $value)
                .textStyle(TextStyle(font: Fonts.nunito(14)))
                .foregroundStyle(palette.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minHeight: 148)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.field))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(palette.fieldEdge, lineWidth: 1))
    }
}

private struct Busy: View {
    let text: String
    @Environment(\.palette) private var palette

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(Fonts.busy)
            .foregroundStyle(palette.muted)
            .multilineTextAlignment(.center)
            .padding(.vertical, 34)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
    }
}

private struct AskChild: View {
    let person: Person
    let question: Question
    let picked: [String]
    let onPick: (String) -> Void
    let onNone: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(person.emoji).font(.system(size: 19))
                Text(person.name).textStyle(Fonts.askName).foregroundStyle(palette.ink)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 7)

            Chips {
                ForEach(question.options, id: \.self) { option in
                    Chip(label: option, on: picked.contains(option),
                         color: Color(hex: person.color)) { onPick(option) }
                }
                Chip(label: "geen van deze", on: picked.isEmpty, quiet: true) { onNone() }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
}

private struct Found: View {
    let item: Suggestion
    let on: Bool
    let people: [Person]
    let onCheck: () -> Void
    let onOpen: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button(action: onCheck) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(on ? ORANGE : palette.tile)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(on ? ORANGE : palette.tileEdge, lineWidth: 1.5))
                    .overlay { if on { Text("✓").font(.system(size: 13)).foregroundStyle(.white) } }
                    .frame(width: 23, height: 23)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .padding(.leading, 13)
                    .padding(.trailing, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityLabel(on ? "Niet overnemen" : "Wel overnemen")

            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 11) {
                    Text(item.entry.icon).font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.entry.text)
                            .textStyle(Fonts.findName)
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if !meta.isEmpty {
                            Text(meta)
                                .textStyle(Fonts.findMeta)
                                .foregroundStyle(palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !item.source.isEmpty {
                            Text("„\(item.source)”")
                                .textStyle(Fonts.findSource)
                                .italic()
                                .foregroundStyle(palette.muted)
                                .opacity(0.85)
                                .lineSpacing(2)
                                .padding(.top, 3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Chevron().opacity(0.5).padding(.top, 4)
                }
                .padding(.vertical, 12)
                .padding(.trailing, 13)
                .padding(.leading, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
        }
    }

    private var meta: String {
        let e = item.entry
        let when = e.weekly ? (daysText(e.days).isEmpty ? "elke dag" : daysText(e.days))
                            : longDate(e.date)
        let names = e.who.compactMap { id in people.first { $0.id == id }?.name }
        let kind = e.task
            ? "✅ " + (e.routine == .night ? "🌙 " : "☀️ ")
                + (e.group.trimmingCharacters(in: .whitespaces).isEmpty ? "ritme" : e.group)
            : (e.weekly ? "elke week" : "")
        return [when, timeText(time: e.time, until: e.until),
                names.isEmpty ? "iedereen" : names.joined(separator: " en "), kind]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func longDate(_ value: String) -> String {
        guard let d = asDate(value) else { return "" }
        return dateText(d)
    }
}
