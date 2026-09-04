import SwiftUI

private let MAX_QUESTIONS = 2

struct AssistantSheet: View {
    @Environment(Household.self) private var household
    let content: Content
    /// Tekst die al klaarstaat — dan slaat het blad het invulvak over en gaat
    /// meteen lezen. Zo begint een leeg huis: je typt op de bladzijde zelf.
    var opening: String = ""
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
        case .busy: return String(localized: "Even lezen")
        case .nothing: return String(localized: "Niets gevonden")
        case .question: return String(localized: "Even iets vragen")
        case .suggestions: return String(localized: "Dit haalde ik eruit")
        case .paste: return String(localized: "Typ of plak iets")
        }
    }

    private var button: String {
        switch phase {
        case .busy: return String(localized: "Even lezen…")
        case .nothing: return String(localized: "Opnieuw proberen")
        case .question: return String(localized: "Ga verder")
        case .suggestions: return String(localized: "Zet er \(pickedCount) in de app")
        case .paste: return String(localized: "Lees uit")
        }
    }

    var body: some View {
        ZStack {
            Sheet(title: title, alert: alert, button: button,
                  busy: phase == .busy || (phase == .suggestions && pickedCount == 0),
                  onCancel: onCancel, onButton: next) {
                switch phase {
                case .paste:
                    FormHead(String(localized: "De tekst"), first: true)
                    PasteBox(value: $message)

                case .busy:
                    Busy(String(localized: "Even kijken wat erin staat…"))

                case .nothing:
                    Busy(String(localized: """
                        Hier kon ik niets uithalen dat in de app hoort. Probeer het wat concreter, \
                        of plak er meer bij.
                        """))

                case .question:
                    if let question {
                        FormHead(String(localized: "Vraag"), first: true)
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
                    ForEach(Array(chapters.enumerated()), id: \.offset) { (c, chapter) in
                        FormHead(chapter.title, first: c == 0)
                        Glass(radius: 22) {
                            VStack(spacing: 0) {
                                ForEach(Array(chapter.rows.enumerated()), id: \.offset) { (row, i) in
                                    if row > 0 { HairLine() }
                                    Found(
                                        item: items[i],
                                        on: i < picked.count && picked[i],
                                        people: everyone,
                                        onCheck: { if i < picked.count { picked[i].toggle() } },
                                        onOpen: { draft = asDraft(content); editing = i }
                                    )
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }

            if let i = editing, i < items.count, let person = items[i].person {
                ChildSheet(
                    title: person.name.isEmpty ? String(localized: "Kind") : person.name,
                    child: ChildData(id: person.id, name: person.name, emoji: person.emoji,
                                     color: COLORS[0], traits: person.traits,
                                     birthday: person.birthday),
                    onCancel: { editing = nil },
                    onSave: { fresh in
                        items[i].person = NewPerson(id: person.id, name: fresh.name,
                                                    emoji: fresh.emoji.isEmpty ? "🙂" : fresh.emoji,
                                                    birthday: fresh.birthday,
                                                    traits: fresh.traits)
                        items[i].entry.icon = fresh.emoji.isEmpty ? "🙂" : fresh.emoji
                        items[i].entry.text = fresh.name
                        if i < picked.count { picked[i] = true }
                        editing = nil
                    }
                )
            } else if let i = editing, i < items.count, let working = draft {
                EntrySheet(
                    title: items[i].entry.text.isEmpty ? String(localized: "Voorstel") : items[i].entry.text,
                    entry: withGroup(items[i].entry, working),
                    place: nil,
                    source: { working },
                    people: content.people,
                    onCancel: { editing = nil },
                    onSave: { fresh in
                        items[i].entry = fresh
                        if i < picked.count { picked[i] = true }
                        editing = nil
                    }
                )
            }
        }
        .task {
            guard !opening.isEmpty, message.isEmpty else { return }
            message = opening
            await read()
        }
    }

    /// De kinderen zoals ze straks heten: die er al zijn plus die in deze
    /// ronde voorgesteld worden. Alleen om namen te tonen bij een voorstel.
    private var everyone: [Person] {
        content.people + items.compactMap { item in
            item.person.map {
                Person(id: $0.id, name: $0.name, emoji: $0.emoji, color: COLORS[0],
                       traits: $0.traits, birthday: $0.birthday)
            }
        }
    }

    /// De voorstellen op een hoop is een lijst waar niemand doorheen komt.
    /// Dus in stukken, in de volgorde waarin ze in de app landen.
    private struct Chapter {
        var title: String
        var rows: [Int]
    }

    private var chapters: [Chapter] {
        let all = Array(items.indices)
        let parts: [(String, (Suggestion) -> Bool)] = [
            (String(localized: "Kinderen"), { $0.person != nil }),
            (String(localized: "In het ritme"), { $0.person == nil && $0.entry.task }),
            (String(localized: "Elke week"), { $0.person == nil && !$0.entry.task && $0.entry.weekly }),
            (String(localized: "Eenmalig"), { $0.person == nil && !$0.entry.task && !$0.entry.weekly }),
        ]
        return parts.compactMap { (title, matches) in
            let rows = all.filter { matches(items[$0]) }
            return rows.isEmpty ? nil : Chapter(title: title, rows: rows)
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
                alert = String(localized: "Plak eerst een bericht.")
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
                children: content.people,
                house: content
            ), household.endpoint)
        } catch let problem as ReadError {
            phase = .paste
            alert = problem.fromServer ? problem.message
                                       : String(localized:
                                           "Het uitlezen lukte niet (\(problem.message)).")
            return
        } catch {
            phase = .paste
            alert = String(localized:
                "Het uitlezen lukte niet (\(error.localizedDescription)).")
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
                question: out["question"].text(String(localized: "Waar hoort dit bij?")),
                options: options,
                multiple: out["multiple"].flag
            )
            phase = .question
            return
        }

        // De kinderen eerst: de rest van de voorstellen wijst met "who" naar
        // de ids die de uitlezer daar verzon.
        let found = out["people"].array.compactMap(cleanPerson)
            + out["items"].array.compactMap { cleanSuggestion($0, content.people) }
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
            alert = String(localized: "Kies er minstens één.")
            return
        }
        let working = asDraft(content)

        // Eerst de kinderen. De uitlezer verzon hun id en wijst daar met "who"
        // naar; hier wordt dat een echt id, en onthouden we welk id waarheen
        // ging zodat de rest van de voorstellen bij de goede naam landt.
        var real: [String: String] = [:]
        for suggestion in chosen {
            guard let person = suggestion.person else { continue }
            if let existing = working.people.first(where: {
                $0.name.lowercased() == person.name.lowercased()
            }) {
                real[person.id] = existing.id
                continue
            }
            let id = freeId(person.id, working)
            real[person.id] = id
            working.people.append(DraftPerson(
                id: id,
                name: person.name,
                emoji: person.emoji.isEmpty ? "🙂" : person.emoji,
                color: COLORS[working.people.count % COLORS.count],
                traits: person.traits,
                birthday: person.birthday
            ))
        }

        let known = Set(working.people.map { $0.id })
        for suggestion in chosen where suggestion.person == nil {
            var entry = suggestion.entry
            let wanted = entry.who
            entry.who = wanted.map { real[$0] ?? $0 }.filter { known.contains($0) }
            // Ging dit alleen over een kind dat niet meegaat, dan gaat het
            // voorstel ook niet mee — anders werd het ineens voor iedereen.
            if !wanted.isEmpty && entry.who.isEmpty { continue }
            if alreadyKnown(working, entry) { continue }
            placeEntry(working, entry, "", nil)
        }

        if let problem = await onSave(working) { alert = problem } else { onCancel() }
    }

    /// Het id dat de uitlezer verzon, of hetzelfde met een cijfer erachter als
    /// het al bezet is.
    private func freeId(_ wanted: String, _ working: Draft) -> String {
        let taken = Set(working.people.map { $0.id })
        let base = wanted.isEmpty ? newId() : wanted
        if !taken.contains(base) { return base }
        for n in 2...20 where !taken.contains("\(base)\(n)") { return "\(base)\(n)" }
        return newId()
    }
}

struct PasteBox: View {
    @Binding var value: String
    var hint: String = String(localized: """
        Plak een mail of appje, typ het gewoon —

        iedere dinsdag om 18:00 tennis Emma

        — of vraag om iets:

        maak een voedings- en slaapschema voor Filip
        """)
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .topLeading) {
            if value.isEmpty {
                Text(hint)
                    .textStyle(TextStyle(font: Fonts.nunito(14)))
                    .foregroundStyle(SOFT_INK.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $value)
                .accessibilityIdentifier("assistant.text")
                .accessibilityLabel(Spoken.message)
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
                Chip(label: String(localized: "geen van deze"), on: picked.isEmpty, quiet: true) { onNone() }
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
            .accessibilityLabel(on ? Spoken.skip : Spoken.take)

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
        // Een kind vertelt iets anders dan een afspraak: wanneer hij jarig is
        // en wat er van hem bekend is.
        if let person = item.person {
            let age = person.birthday.isEmpty ? "" : longDate(person.birthday)
            let known = person.traits.sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: " · ")
            let both = [age, known].filter { !$0.isEmpty }
            return both.isEmpty ? String(localized: "nieuw kind") : both.joined(separator: " · ")
        }
        let e = item.entry
        let when = e.weekly ? (daysText(e.days).isEmpty ? String(localized: "elke dag") : daysText(e.days))
                            : longDate(e.date)
        let names = e.who.compactMap { id in people.first { $0.id == id }?.name }
        let kind = e.task
            ? "✅ " + (e.routine == .night ? "🌙 " : "☀️ ")
                + (e.group.trimmingCharacters(in: .whitespaces).isEmpty
                   ? String(localized: "ritme") : e.group)
            : (e.weekly ? String(localized: "elke week") : "")
        return [when, timeText(time: e.time, until: e.until),
                names.isEmpty ? String(localized: "iedereen") : names.joined(separator: String(localized: " en ")), kind]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func longDate(_ value: String) -> String {
        guard let d = asDate(value) else { return "" }
        return dateText(d)
    }
}
