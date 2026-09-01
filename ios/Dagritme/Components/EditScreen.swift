import SwiftUI
import UniformTypeIdentifiers

enum EditKind: String, Identifiable {
    case children, day, night, week, oneOff, general
    var id: String { rawValue }

    var title: String {
        switch self {
        case .children: return String(localized: "Kinderen")
        case .day: return String(localized: "Ochtendritme")
        case .night: return String(localized: "Avondritme")
        case .week: return String(localized: "Weekritme")
        case .oneOff: return String(localized: "Eenmalig")
        case .general: return String(localized: "Naam")
        }
    }
}

func bind<T: AnyObject>(_ object: T, _ path: ReferenceWritableKeyPath<T, String>) -> Binding<String> {
    Binding(get: { object[keyPath: path] }, set: { object[keyPath: path] = $0 })
}

struct SheetState {
    var title: String
    var place: Place?
    var entry: Entry
}

struct ChildState {
    var title: String
    var child: ChildData
}

struct EditScreen: View {
    let kind: EditKind
    let onCancel: () -> Void
    let onSave: (Draft) async -> String?

    @State private var draft: Draft
    @State private var redraw = 0
    @State private var alert = ""
    @State private var busy = false
    @State private var routine: Routine
    @State private var sheet: SheetState?
    @State private var childSheet: ChildState?
    @State private var draggedChild: DraftPerson?
    @State private var draggedStep: DraftStep?
    @State private var draggedWeek: DraftWeekItem?

    init(kind: EditKind, content: Content, onCancel: @escaping () -> Void,
         onSave: @escaping (Draft) async -> String?) {
        self.kind = kind
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: asDraft(content))
        _routine = State(initialValue: kind == .night ? .night : .day)
    }

    private var people: [Person] {
        draft.people.map {
            Person(id: $0.id, name: $0.name, emoji: $0.emoji.isEmpty ? "🙂" : $0.emoji,
                   color: $0.color.isEmpty ? COLORS[0] : $0.color, traits: $0.traits)
        }
    }

    private func whoForRow(_ who: [String]) -> [Person] {
        let picked = who.compactMap { id in people.first { $0.id == id } }
        return picked.count > 0 && picked.count < people.count ? picked : []
    }

    private func refresh() { redraw += 1 }

    private func openEntry(_ title: String, _ place: Place?, _ adjust: (inout Entry) -> Void) {
        var entry = entryFrom(draft, place)
        adjust(&entry)
        sheet = SheetState(title: title, place: place, entry: entry)
    }

    var body: some View {
        let _ = redraw

        ZStack {
            FullSheet(title: kind.title, alert: alert, busy: busy,
                      ownScroll: kind != .general,
                      onCancel: onCancel, onDone: done) {
                switch kind {
                case .children:
                    childrenList
                case .day, .night:
                    routineList
                case .week:
                    weekList
                case .oneOff:
                    oneOffList
                case .general:
                    generalList
                }
            }

            if let state = sheet {
                EntrySheet(
                    title: state.title,
                    entry: state.entry,
                    place: state.place,
                    source: { draft },
                    people: people,
                    onCancel: { sheet = nil },
                    onSave: { _ in sheet = nil; refresh() }
                )
                .environment(\.palette, Palette(dark: false))
            }

            if let state = childSheet {
                ChildSheet(
                    title: state.title,
                    child: state.child,
                    onCancel: { childSheet = nil },
                    onSave: saveChild
                )
                .environment(\.palette, Palette(dark: false))
            }
        }
    }

    private func saveChild(_ fresh: ChildData) {
        if let existing = draft.people.first(where: { $0.id == fresh.id }) {
            existing.name = fresh.name
            existing.emoji = fresh.emoji.isEmpty ? "🙂" : fresh.emoji
            existing.color = fresh.color
            existing.traits = fresh.traits
        } else if !fresh.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.people.append(DraftPerson(
                id: fresh.id,
                name: fresh.name,
                emoji: fresh.emoji.isEmpty ? "🙂" : fresh.emoji,
                color: fresh.color.isEmpty ? COLORS[draft.people.count % COLORS.count] : fresh.color,
                traits: fresh.traits
            ))
        }
        childSheet = nil
        refresh()
    }

    private func done() {
        let fresh = cleaned(draft)
        if (fresh["people"] as? [[String: Any]] ?? []).isEmpty {
            alert = String(localized: "Er moet minstens één kind zijn.")
            return
        }
        let daySteps = countSteps(fresh["day"] as? [[String: Any]] ?? [])
        let nightSteps = countSteps(fresh["night"] as? [[String: Any]] ?? [])
        if daySteps == 0 && nightSteps == 0 {
            alert = String(localized: "Er moet minstens één stap overblijven.")
            return
        }
        busy = true
        Task {
            let problem = await onSave(draft)
            busy = false
            if let problem { alert = problem } else { onCancel() }
        }
    }

    @ViewBuilder
    private var childrenList: some View {
        List {
            Section {
                ForEach(draft.people) { person in
                    ChildRow(person: person, onOpen: { openChild(person) })
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { removeChild(person) } label: {
                                Image(systemName: "trash")
                            }
                            .tint(RED)
                        }
                        .onDrag {
                            draggedChild = person
                            return NSItemProvider(object: person.name as NSString)
                        }
                }
                .onInsert(of: [.utf8PlainText, .plainText, .text]) { index, _ in
                    dropChild(index)
                }
                .plainRow()

                AddRow(String(localized: "Kind toevoegen")) {
                    childSheet = ChildState(
                        title: String(localized: "Nieuw kind"),
                        child: ChildData(id: newId(), name: "", emoji: "🙂",
                                         color: COLORS[draft.people.count % COLORS.count],
                                         traits: [:])
                    )
                }
                .plainRow()
            }
            .listRowBackground(rowBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var rowBackground: some View {
        Rectangle().fill(.ultraThinMaterial)
            .overlay(Rectangle().fill(Palette(dark: false).glass))
    }

    private func openChild(_ person: DraftPerson) {
        childSheet = ChildState(
            title: person.name.isEmpty ? String(localized: "Kind") : person.name,
            child: ChildData(id: person.id, name: person.name,
                             emoji: person.emoji.isEmpty ? "🙂" : person.emoji,
                             color: person.color,
                             traits: person.traits)
        )
    }

    private func removeChild(_ person: DraftPerson) {
        if draft.people.count <= 1 {
            alert = String(localized: "Er moet minstens één kind overblijven.")
            return
        }
        detach(person.id)
        draft.people.removeAll { $0 === person }
        alert = ""
        refresh()
    }

    private func detach(_ id: String) {
        for which in [Routine.day, .night] {
            for group in draft[which] {
                for step in group.steps { step.who.removeAll { $0 == id } }
            }
        }
        for item in draft.week { item.who.removeAll { $0 == id } }
        for event in draft.events { event.who.removeAll { $0 == id } }
    }

    @ViewBuilder
    private var routineList: some View {
        List {
            Section {
                Segment(routine: routine, onSelect: { routine = $0 }, topPad: 0)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }
            .listRowBackground(Color.clear)

            ForEach(draft[routine]) { group in
                let fixed = group.steps.filter { $0.date.isEmpty }
                let oneOffs = group.steps.count - fixed.count

                Section {
                    HStack(spacing: 8) {
                        Field(value: bind(group, \.name), placeholder: String(localized: "Groep"))
                        Field(value: bind(group, \.time), placeholder: String(localized: "tijd"), kind: .time)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { removeGroup(group) } label: {
                            Image(systemName: "trash")
                        }
                        .tint(RED)
                    }
                    .moveDisabled(true)

                    ForEach(fixed) { step in
                        EditRow(
                            icon: step.icon.isEmpty ? "⭐" : step.icon,
                            label: step.label,
                            empty: String(localized: "Naamloze stap"),
                            days: daysText(step.days),
                            who: whoForRow(step.who),
                            onOpen: {
                                openEntry(step.label.isEmpty ? String(localized: "Stap") : step.label,
                                          .step(routine: routine, group: group, step: step)) { _ in }
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                group.steps.removeAll { $0 === step }
                                refresh()
                            } label: { Image(systemName: "trash") }
                            .tint(RED)
                        }
                        .onDrag {
                            draggedStep = step
                            return NSItemProvider(object: step.label as NSString)
                        }
                    }
                    .onInsert(of: [.utf8PlainText, .plainText, .text]) { index, _ in
                        dropStep(index, into: group)
                    }
                    .plainRow()

                    if oneOffs > 0 {
                        CardNote(String(localized:
                            "Hier staan ook \(oneOffs) dingen voor één dag; die bewerk je bij Eenmalig."))
                            .moveDisabled(true)
                    }

                    AddRow(String(localized: "Stap toevoegen")) {
                        openEntry(String(localized: "Nieuwe stap"), nil) { entry in
                            entry.icon = "⭐"
                            entry.task = true
                            entry.routine = routine
                            entry.group = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .plainRow()
                    .moveDisabled(true)
                }
                .listRowBackground(rowBackground)
            }

            Section {
                CardButton(String(localized: "Groep toevoegen"), plus: true, id: "edit.addGroup") {
                    draft[routine].append(DraftGroup(name: String(localized: "Nieuwe groep"), time: "", steps: []))
                    refresh()
                }
                .padding(.top, 0)
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func removeGroup(_ group: DraftGroup) {
        guard group.steps.isEmpty else {
            alert = String(localized: "Haal eerst de stappen uit '\(group.name)'.")
            return
        }
        draft[routine].removeAll { $0 === group }
        alert = ""
        refresh()
    }

    // Vastpakken en slepen: binnen een groep, of naar een andere groep.
    private func dropStep(_ index: Int, into group: DraftGroup) {
        guard let step = draggedStep else { return }
        draggedStep = nil
        let fixed = group.steps.filter { $0.date.isEmpty }
        let ref = index < fixed.count ? fixed[index] : nil
        guard ref !== step else { return }
        for g in draft[routine] { g.steps.removeAll { $0 === step } }
        if let ref, let at = group.steps.firstIndex(where: { $0 === ref }) {
            group.steps.insert(step, at: at)
        } else {
            group.steps.append(step)
        }
        refresh()
    }

    private func dropChild(_ index: Int) {
        guard let person = draggedChild else { return }
        draggedChild = nil
        let ref = index < draft.people.count ? draft.people[index] : nil
        guard ref !== person else { return }
        draft.people.removeAll { $0 === person }
        if let ref, let at = draft.people.firstIndex(where: { $0 === ref }) {
            draft.people.insert(person, at: at)
        } else {
            draft.people.append(person)
        }
        refresh()
    }

    private func dropWeek(_ index: Int) {
        guard let item = draggedWeek else { return }
        draggedWeek = nil
        let ref = index < draft.week.count ? draft.week[index] : nil
        guard ref !== item else { return }
        draft.week.removeAll { $0 === item }
        if let ref, let at = draft.week.firstIndex(where: { $0 === ref }) {
            draft.week.insert(item, at: at)
        } else {
            draft.week.append(item)
        }
        refresh()
    }


    @ViewBuilder
    private var weekList: some View {
        List {
            Section {
                ForEach(draft.week) { item in
                    EditRow(
                        icon: item.icon.isEmpty ? "📅" : item.icon,
                        label: item.text,
                        empty: String(localized: "Naamloos"),
                        time: (isEvening(time: item.time, until: item.until,
                                         evening: item.evening, from: EVENING_FROM) ? "🌙 " : "")
                            + timeText(time: item.time, until: item.until),
                        days: daysText(item.days),
                        who: whoForRow(item.who),
                        twoLines: true,
                        onOpen: {
                            openEntry(item.text.isEmpty ? String(localized: "Item") : item.text, .week(item)) { _ in }
                        }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            draft.week.removeAll { $0 === item }
                            refresh()
                        } label: { Image(systemName: "trash") }
                        .tint(RED)
                    }
                    .onDrag {
                        draggedWeek = item
                        return NSItemProvider(object: item.text as NSString)
                    }
                }
                .onInsert(of: [.utf8PlainText, .plainText, .text]) { index, _ in
                    dropWeek(index)
                }
                .plainRow()

                AddRow(String(localized: "Item toevoegen")) {
                    openEntry(String(localized: "Nieuw item"), nil) { entry in
                        entry.icon = "📅"
                        entry.weekly = true
                        entry.task = false
                    }
                }
                .plainRow()
                .moveDisabled(true)
            }
            .listRowBackground(rowBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var oneOffList: some View {
        let entries = oneOffRows()
        List {
            if entries.isEmpty {
                Section {
                    Text("Er staat niets op een datum.")
                        .textStyle(Fonts.empty)
                        .foregroundStyle(SOFT_INK)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .listRowBackground(rowBackground)
            } else {
                Section {
                    ForEach(Array(entries.enumerated()), id: \.offset) { (_, row) in
                        EditRow(
                            icon: row.icon,
                            label: row.name,
                            empty: String(localized: "Naamloos"),
                            time: shortDate(row.date),
                            extra: row.extra,
                            who: whoForRow(row.who),
                            twoLines: true,
                            onOpen: {
                                openEntry(row.name.isEmpty ? String(localized: "Iets eenmaligs") : row.name,
                                          row.place) { _ in }
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeEntry(draft, row.place)
                                refresh()
                            } label: { Image(systemName: "trash") }
                            .tint(RED)
                        }
                        .plainRow()
                    }
                }
                .listRowBackground(rowBackground)
            }

            Section {
                CardButton(String(localized: "Iets eenmaligs toevoegen"), plus: true, id: "edit.addOneOff") {
                    openEntry(String(localized: "Iets eenmaligs"), nil) { entry in
                        entry.icon = "🎉"
                        entry.weekly = false
                        entry.task = false
                    }
                }
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private struct OneOffRow {
        var icon: String
        var name: String
        var date: String
        var extra: String
        var who: [String]
        var place: Place
        var time: String
    }

    private func oneOffRows() -> [OneOffRow] {
        var out: [OneOffRow] = draft.events.filter { !$0.date.isEmpty }.map { item in
            OneOffRow(
                icon: item.icon.isEmpty ? "📌" : item.icon,
                name: item.text,
                date: item.date,
                extra: timeText(time: item.time, until: item.until),
                who: item.who,
                place: .event(item),
                time: item.time
            )
        }
        for which in [Routine.day, .night] {
            for group in draft[which] {
                for step in group.steps where !step.date.isEmpty {
                    let name = group.name.trimmingCharacters(in: .whitespaces)
                    out.append(OneOffRow(
                        icon: step.icon.isEmpty ? "📌" : step.icon,
                        name: step.label,
                        date: step.date,
                        extra: "✅ " + (which == .day ? "☀️ " : "🌙 ")
                            + (name.isEmpty ? String(localized: "ritme") : name),
                        who: step.who,
                        place: .step(routine: which, group: group, step: step),
                        time: ""
                    ))
                }
            }
        }
        return out.sorted { ($0.date, $0.time) < ($1.date, $1.time) }
    }

    @ViewBuilder
    private var generalList: some View {
        EditCard {
            HStack(spacing: 10) {
                Text("🏡").font(.system(size: 24)).frame(width: 46)
                Field(value: bind(draft, \.title), placeholder: String(localized: "Naam van de app"))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minHeight: 58)
        }
    }
}

private struct CardNote: View {
    let text: String
    @Environment(\.palette) private var palette

    init(_ text: String) { self.text = text }

    var body: some View {
        VStack(spacing: 0) {
            HairLine()
            Text(text)
                .textStyle(TextStyle(font: Fonts.nunitoHeavy(12.5)))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension View {
    /// Rijen zonder eigen lijstinzet, met één nette scheidslijn die op de
    /// binnenrand van de kaart begint.
    func plainRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparatorTint(Palette(dark: false).line)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 12 }
    }
}

private struct ChildRow: View {
    let person: DraftPerson
    let onOpen: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Text(person.emoji.isEmpty ? "🙂" : person.emoji)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text(person.name.isEmpty ? "Naamloos" : person.name)
                    .textStyle(Fonts.rowLabel)
                    .foregroundStyle(person.name.isEmpty ? palette.muted : palette.ink)
                    .lineLimit(1)
                if !person.color.isEmpty {
                    Circle().fill(Color(hex: person.color)).frame(width: 16, height: 16)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
    }
}

