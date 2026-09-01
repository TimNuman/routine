import SwiftUI

struct EntrySheet: View {
    let title: String
    let place: Place?
    let source: () -> Draft
    let people: [Person]
    var busy: Bool = false
    let onCancel: () -> Void
    let onSave: (Entry) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var entry: Entry
    @State private var alert = ""
    @State private var picker = false

    init(title: String, entry: Entry, place: Place?, source: @escaping () -> Draft,
         people: [Person], busy: Bool = false, onCancel: @escaping () -> Void,
         onSave: @escaping (Entry) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.place = place
        self.source = source
        self.people = people
        self.busy = busy
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _entry = State(initialValue: entry)
        _startIcon = State(initialValue: entry.icon)
    }

    /// Het icoon waarmee het blad openging, en wat de app er zelf van maakte:
    /// zolang er niet met de hand gekozen is, kiest hij mee met de naam.
    @State private var startIcon: String
    @State private var autoIcon: String?
    @State private var handPicked = false
    private static let plainIcons: Set<String> = ["", "📅", "⭐", "📌", "🎉"]

    private func suggestIcon() {
        guard !handPicked,
              Self.plainIcons.contains(entry.icon) || entry.icon == autoIcon else { return }
        if let glyph = suggestEmoji(for: entry.text) {
            entry.icon = glyph
            autoIcon = glyph
        } else if entry.icon == autoIcon {
            entry.icon = startIcon
            autoIcon = nil
        }
    }

    var body: some View {
        ZStack {
            Sheet(title: title, alert: alert, button: String(localized: "Bewaar"), busy: busy,
                  onCancel: onCancel, onButton: save) {
                nameSection
                whenSection
                kindSection
                whoSection
                deleteButton
            }

            if picker {
                EmojiPicker(title: String(localized: "Kies een icoon"), current: entry.icon,
                            onCancel: { picker = false },
                            onDone: { glyph in entry.icon = glyph; handPicked = true; picker = false })
            }
        }
    }

    @ViewBuilder
    private var nameSection: some View {
        FormHead(String(localized: "Icoon en naam"), first: true)
        HStack(spacing: 10) {
            EmojiButton(value: entry.icon, size: 52) { picker = true }
            Field(value: $entry.text, placeholder: String(localized: "Wat is er"), id: "entry.text")
        }
        .onChange(of: entry.text) { suggestIcon() }
    }

    @ViewBuilder
    private var whenSection: some View {
        FormHead(String(localized: "Hoe vaak"))
        Chips {
            Chip(label: String(localized: "🔁 herhalen"), on: entry.weekly,
                 id: "entry.weekly") { entry.weekly = true }
            Chip(label: String(localized: "📌 één keer"), on: !entry.weekly,
                 id: "entry.once") { entry.weekly = false }
        }

        if entry.weekly {
            FormHead(String(localized: "Op welke dagen"))
            Chips(equal: true) {
                ForEach(WEEKDAYS, id: \.self) { day in
                    Chip(label: dayLabel(day), on: entry.days.contains(day),
                         id: "entry.day.\(day)") {
                        if let i = entry.days.firstIndex(of: day) { entry.days.remove(at: i) }
                        else { entry.days.append(day) }
                    }
                }
            }
        } else {
            FormHead(String(localized: "Op welke dag"))
            // De compacte DatePicker laat zijn letter niet kiezen; hij ligt er
            // onzichtbaar onder voor de tik en de kalender, en de app tekent
            // er zijn eigen knop overheen.
            DatePicker("Datum", selection: dateBinding, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .opacity(0.02)
                .overlay {
                    Chip(label: dateBinding.wrappedValue
                        .formatted(.dateTime.day().month(.abbreviated).year()
                            .locale(.autoupdatingCurrent)),
                         on: true) {}
                        .allowsHitTesting(false)
                }
                .accessibilityLabel(Spoken.date)
                .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var kindSection: some View {
        FormHead(String(localized: "Wat voor iets"))
        Chips {
            Chip(label: String(localized: "✅ taak"), on: entry.task) {
                entry.task = true
                if entry.group.trimmingCharacters(in: .whitespaces).isEmpty {
                    entry.group = firstGroupName(source(), entry.routine)
                }
            }
            Chip(label: String(localized: "🗓️ agenda"), on: !entry.task) { entry.task = false }
        }

        if entry.task {
            FormHead(String(localized: "In welk ritme"))
            Chips {
                Chip(label: String(localized: "☀️ ochtend"), on: entry.routine == .day) {
                    entry.routine = .day
                    entry.group = firstGroupName(source(), .day)
                }
                Chip(label: String(localized: "🌙 avond"), on: entry.routine == .night) {
                    entry.routine = .night
                    entry.group = firstGroupName(source(), .night)
                }
            }

            FormHead(String(localized: "Bij welk onderdeel"))
            Chips {
                ForEach(groupNames, id: \.self) { name in
                    Chip(label: name, on: entry.group == name) { entry.group = name }
                }
            }
        } else {
            FormHead(String(localized: "Hoe laat"))
            HStack(spacing: 10) {
                Field(value: $entry.time, placeholder: String(localized: "van"), kind: .time)
                Text("–").textStyle(Fonts.rowMeta).foregroundStyle(SOFT_INK)
                Field(value: $entry.until, placeholder: String(localized: "tot"), kind: .time)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var whoSection: some View {
        FormHead(String(localized: "Voor wie"))
        Chips {
            Chip(label: String(localized: "iedereen"), on: entry.who.isEmpty) { entry.who = [] }
            ForEach(people) { person in
                Chip(label: "\(person.emoji) \(person.name.isEmpty ? String(localized: "kind") : person.name)",
                     on: entry.who.contains(person.id),
                     color: Color(hex: person.color)) {
                    if let i = entry.who.firstIndex(of: person.id) { entry.who.remove(at: i) }
                    else { entry.who.append(person.id) }
                }
            }
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        if let onDelete {
            Button(action: onDelete) {
                Text("Verwijderen")
                    .textStyle(TextStyle(font: Fonts.balooHeavy(14.5)))
                    .foregroundStyle(RED)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(RED.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(RED.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.press)
            .padding(.top, 18)
        }
    }

    private var groupNames: [String] {
        source()[entry.routine]
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { asDate(entry.date) ?? Date() },
            set: { entry.date = dateString($0) }
        )
    }

    private func save() {
        if let problem = moveEntry(source(), place, entry) {
            alert = problem
            return
        }
        onSave(entry)
    }

    private var timeNote: String {
        let from = EVENING_FROM
        guard let hour = hourFromTime(entry.time) else {
            return entry.evening
                ? "Zonder tijd blijft dit bij Vanavond staan, zoals het was. Vul een tijd in vanaf \(from):00 om dat zo te houden."
                : "Zonder tijd komt dit bij Overdag te staan. Vanaf \(from):00 gaat het naar Vanavond."
        }
        return hour >= from
            ? "Komt bij Vanavond te staan — dat begint om \(from):00."
            : "Komt bij Overdag te staan; vanaf \(from):00 zou het Vanavond zijn."
    }
}
