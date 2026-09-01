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
    /// De rij die net is neergezet: die houdt heel even de zwevende look
    /// vast en laat die dan wegvloeien, zodat het systeemvoorbeeld geruisloos
    /// kan verdwijnen.
    @State private var landing: ObjectIdentifier?

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
                        .landingGlow(landing == ObjectIdentifier(person))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { removeChild(person) } label: {
                                Image(systemName: "trash")
                            }
                            .tint(RED)
                        }
                }
                .onMove { from, to in
                    let moved = from.first.map { draft.people[$0] }
                    draft.people.move(fromOffsets: from, toOffset: to)
                    if let moved { landed(moved) }
                    refresh()
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
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
    }

    // Effen, in de kleur die het glas hier toch al oplevert: een rij die je
    // optilt blijft dan dicht in plaats van doorschijnend.
    private var rowBackground: some View {
        Color(hex: "#FBF3F1")
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

    /// Eén doorlopende lijst: een stap hoort bij de groepskop die erboven
    /// staat. Zo sleep je een stap ook naar een andere groep, en een kop
    /// zelf is net zo goed te verslepen.
    private enum RoutineRow: Identifiable {
        case head(DraftGroup)
        case step(DraftStep)
        case add(DraftGroup)

        var id: String {
            switch self {
            case .head(let group): "g\(UInt(bitPattern: ObjectIdentifier(group).hashValue))"
            case .step(let step): "s\(UInt(bitPattern: ObjectIdentifier(step).hashValue))"
            case .add(let group): "a\(UInt(bitPattern: ObjectIdentifier(group).hashValue))"
            }
        }
    }

    private func flatRows() -> [RoutineRow] {
        draft[routine].flatMap { group in
            [RoutineRow.head(group)]
                + group.steps.filter { $0.date.isEmpty }.map { RoutineRow.step($0) }
        }
    }

    @ViewBuilder
    private var routineList: some View {
        let rows = flatRows()
        List {
            Section {
                Segment(routine: routine, onSelect: { routine = $0 }, topPad: 0)
                    .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)

            Section {
                ForEach(rows) { row in
                    switch row {
                    case .head(let group): headRow(group, first: rows.first?.id == row.id)
                    case .step(let step): stepRow(step)
                    case .add: EmptyView()
                    }
                }
                .onMove { from, to in moveRow(from, to) }
                .plainRow()

                // Onderaan één rij met twee plusjes: een stap en een groep.
                HStack(spacing: 0) {
                    AddRow(String(localized: "Stap")) {
                        openEntry(String(localized: "Nieuwe stap"), nil) { entry in
                            entry.icon = "⭐"
                            entry.task = true
                            entry.routine = routine
                            entry.group = draft[routine].last?.name
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        }
                    }
                    AddRow(String(localized: "Groep"), glyph: "+", color: ORANGE) {
                        draft[routine].append(DraftGroup(
                            name: String(localized: "Nieuwe groep"), time: "", steps: []))
                        refresh()
                    }
                }
                .plainRow()
                .moveDisabled(true)
            }
            .listRowBackground(rowBackground)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func headRow(_ group: DraftGroup, first: Bool) -> some View {
        HStack(spacing: 8) {
            Field(value: bind(group, \.name), placeholder: String(localized: "Groep"))
            Field(value: bind(group, \.time), placeholder: String(localized: "tijd"), kind: .time)
        }
        .padding(.top, first ? 14 : 10)
        .padding(.bottom, 10)
        .padding(.horizontal, 20)
        .landingGlow(landing == ObjectIdentifier(group))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { removeGroup(group) } label: {
                Image(systemName: "trash")
            }
            .tint(RED)
        }
    }

    @ViewBuilder
    private func stepRow(_ step: DraftStep) -> some View {
        EditRow(
            icon: step.icon.isEmpty ? "⭐" : step.icon,
            label: step.label,
            empty: String(localized: "Naamloze stap"),
            days: daysText(step.days),
            who: whoForRow(step.who),
            onOpen: {
                let group = groupOf(step) ?? draft[routine].first
                guard let group else { return }
                openEntry(step.label.isEmpty ? String(localized: "Stap") : step.label,
                          .step(routine: routine, group: group, step: step)) { _ in }
            }
        )
        .landingGlow(landing == ObjectIdentifier(step))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                groupOf(step)?.steps.removeAll { $0 === step }
                refresh()
            } label: { Image(systemName: "trash") }
            .tint(RED)
        }
    }

    private func groupOf(_ step: DraftStep) -> DraftGroup? {
        draft[routine].first { $0.steps.contains { $0 === step } }
    }

    /// Na een sleep wordt de indeling opnieuw afgelezen uit de volgorde:
    /// wat onder een kop staat, hoort bij die kop. Stappen die boven de
    /// eerste kop belanden, schuiven bij de eerste groep in.
    private func moveRow(_ from: IndexSet, _ to: Int) {
        var rows = flatRows()
        guard let source = from.first, rows.indices.contains(source) else { return }
        let moved = rows[source]
        rows.move(fromOffsets: from, toOffset: to)

        var hidden: [ObjectIdentifier: [DraftStep]] = [:]
        for group in draft[routine] {
            hidden[ObjectIdentifier(group)] = group.steps.filter { !$0.date.isEmpty }
        }

        var order: [DraftGroup] = []
        var bucket: [ObjectIdentifier: [DraftStep]] = [:]
        var orphans: [DraftStep] = []
        var current: DraftGroup?
        for row in rows {
            switch row {
            case .head(let group):
                order.append(group)
                current = group
            case .step(let step):
                if let current {
                    bucket[ObjectIdentifier(current), default: []].append(step)
                } else {
                    orphans.append(step)
                }
            case .add:
                break
            }
        }
        guard !order.isEmpty else { return }
        bucket[ObjectIdentifier(order[0])] = orphans + (bucket[ObjectIdentifier(order[0])] ?? [])
        for group in order {
            group.steps = (bucket[ObjectIdentifier(group)] ?? []) + (hidden[ObjectIdentifier(group)] ?? [])
        }
        draft[routine] = order

        switch moved {
        case .head(let group): landed(group)
        case .step(let step): landed(step)
        case .add: break
        }
        refresh()
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



    private func landed(_ object: AnyObject) {
        let mark = ObjectIdentifier(object)
        landing = mark
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard landing == mark else { return }
            withAnimation(.easeOut(duration: 0.35)) { landing = nil }
        }
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
                    .landingGlow(landing == ObjectIdentifier(item))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            draft.week.removeAll { $0 === item }
                            refresh()
                        } label: { Image(systemName: "trash") }
                        .tint(RED)
                    }
                }
                .onMove { from, to in
                    let moved = from.first.map { draft.week[$0] }
                    draft.week.move(fromOffsets: from, toOffset: to)
                    if let moved { landed(moved) }
                    refresh()
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
        .listSectionSpacing(16)
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
        .listSectionSpacing(16)
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
    /// Dezelfde look als het zwevende sleepvoorbeeld; vloeit weg als `on`
    /// weer uit gaat.
    func landingGlow(_ on: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#FBF3F1"))
                .shadow(color: .black.opacity(on ? 0.16 : 0), radius: on ? 8 : 0, y: on ? 3 : 0)
                .opacity(on ? 1 : 0)
        )
    }

    /// Rijen zonder eigen lijstinzet, met één nette scheidslijn die op de
    /// binnenrand van de kaart begint.
    func plainRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparatorTint(Palette(dark: false).line)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 20 }
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
    }
}

