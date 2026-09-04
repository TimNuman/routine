import SwiftUI

private struct Plan {
    var blocks: [Block] = []
    var early: [Block] = []
    var later: [Block] = []
    var all: [StepGroup] = []
    var groups: [StepGroup] = []
    /// Waar de kaartjes van vandaag beginnen: onderaan op een breed scherm,
    /// in een lijst op de telefoon.
    var cardStarts: [Int] = []
    var earlyStarts: [Int] = []
    var laterStarts: [Int] = []
    var groupStarts: [Int] = []
    var resetSlot: Int = 0
    /// Alle stappen van dit ritme achter elkaar, om er groot doorheen te
    /// vegen, met per groep waar hij in die rij begint.
    var tasks: [Step] = []
    var taskStarts: [Int] = []
}

struct RoutineScreen: View {
    @Environment(Household.self) private var household
    @Environment(Session.self) private var session
    /// De schuif tussen ochtend en avond; de schakelaar zet hem in gang.
    @State private var panes = Slide<Routine>(.day)
    @State private var live = false
    @State private var typed = ""
    @State private var opening = ""
    @State private var assistantOpen = false
    @State private var kids: [ChildData] = []
    @State private var saving = false
    /// "Dat doe ik later" op het tweede scherm: dan is het huis nog leeg maar
    /// staat het gewone ritme er weer, met wat er is.
    @State private var skipped = false
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    @State private var heights: [Routine: CGFloat] = [:]
    @State private var focus = Focus()

    private var everyone: Set<String> {
        Set((household.content?.people ?? []).map(\.id))
    }

    private var visible: Set<String> {
        let left = everyone.subtracting(household.hidden)
        return left.isEmpty ? everyone : left
    }

    private var filtered: Bool { visible.count < everyone.count }

    private func belongs(_ item: AgendaItem) -> Bool {
        guard filtered else { return true }
        return item.who.isEmpty || item.who.contains { visible.contains($0) }
    }

    private func plan(_ r: Routine, _ content: Content?, _ today: Today) -> Plan {
        var out = Plan()
        guard let content else { return out }

        out.blocks = routineBlocks(content, r, household.now,
                                   also: session.members.map(\.asPerson))
            .map { block in
                var block = block
                block.items = block.items.filter(belongs)
                return block
            }
            .filter { !$0.items.isEmpty }
        out.early = out.blocks.filter { !$0.later }
        out.later = out.blocks.filter { $0.later }

        out.all = content[r]
            .map { group in
                var group = group
                group.steps = group.steps.filter { !$0.label.isEmpty && onDay($0, today) }
                return group
            }
            .filter { !$0.steps.isEmpty }

        out.groups = filtered
            ? out.all
                .map { group in
                    var group = group
                    group.steps = group.steps.filter { step in
                        participants(step, content.people).contains { visible.contains($0.id) }
                    }
                    return group
                }
                .filter { !$0.steps.isEmpty }
            : out.all

        for group in out.groups {
            out.taskStarts.append(out.tasks.count)
            out.tasks += group.steps
        }

        var lead = 0
        if !m.wide {
            for block in out.early {
                out.earlyStarts.append(lead)
                lead += 1 + block.items.count
            }
        }

        for group in out.groups {
            out.groupStarts.append(lead)
            lead += 1 + group.steps.count
        }

        if m.wide {
            for block in out.blocks {
                out.cardStarts.append(lead)
                lead += 1 + block.items.count
            }
        } else {
            for block in out.later {
                out.laterStarts.append(lead)
                lead += 1 + block.items.count
            }
        }
        out.resetSlot = lead + 1

        return out
    }

    private func tallies(_ content: Content, _ groups: [StepGroup]) -> [String: Tally] {
        var out: [String: Tally] = [:]
        for person in content.people { out[person.id] = Tally() }
        for group in groups {
            for step in group.steps {
                for person in participants(step, content.people) {
                    guard out[person.id] != nil else { continue }
                    out[person.id]?.total += 1
                    if household.checks[checkKey(household.routine, step.key, person.id)] == true {
                        out[person.id]?.done += 1
                    }
                }
            }
        }
        return out
    }

    var body: some View {
        let today = Today(household.now)
        let here = plan(household.routine, household.content, today)

        ZStack {
            Screen(
                title: fresh ? String(localized: "Hallo!")
                    : (household.routine == .night ? String(localized: "Avond")
                                                   : String(localized: "Ochtend")),
                subtitle: fresh
                    ? (household.content?.people.isEmpty ?? true
                        ? String(localized: "laten we je huis opzetten")
                        : String(localized: "nog één ding: de week"))
                    : dateText(household.now),
                center: fresh ? nil : AnyView(Segment(routine: household.routine,
                                                      onSelect: select, topPad: 16)),
                aside: m.wide && !fresh ? AnyView(bars(here)) : nil,
                quiet: fresh
            ) {
                if fresh {
                    if household.content?.people.isEmpty ?? true {
                        StartWho(kids: $kids, busy: saving) {
                            Task { await savePeople() }
                        }
                    } else {
                        StartWeek(people: household.content?.people ?? [], typed: $typed,
                                  onRead: {
                                      opening = typed.trimmingCharacters(in: .whitespacesAndNewlines)
                                      assistantOpen = true
                                  },
                                  onSkip: { skipped = true })
                    }
                } else {
                    pages(here, today)
                }
            }

            if assistantOpen {
                AssistantSheet(
                    content: household.content ?? Content(title: "", people: [], day: [],
                                                          night: [], week: [], events: []),
                    opening: opening,
                    onCancel: { assistantOpen = false; household.sheetOpen = false },
                    onSave: { await household.save($0) }
                )
                .environment(\.palette, Palette(dark: false))
            }

            if focus.open, let content = household.content {
                TaskFocus(focus: focus, people: content.people, visible: visible)
                    // Bij het sluiten vervaagt de kaart precies waar het
                    // kaartje weer verschijnt, dus zonder sprong.
                    .transition(.opacity)
            }
        }
        // Zolang een stap groot staat blijft de menubalk weg, net als bij
        // een blad.
        .onAppear {
            if kids.isEmpty {
                kids = [ChildData(id: newId(), name: "", emoji: "🦁", color: COLORS[0],
                                  traits: [:])]
            }
        }
        .onChange(of: focus.open) { _, open in household.sheetOpen = open }
        .onChange(of: assistantOpen) { _, open in household.sheetOpen = open }
        .onDisappear { household.sheetOpen = false }
    }

    /// Een huis waar nog niets in staat. Dan is er geen ritme om te tonen,
    /// maar wel iets te vertellen: wie er in huis zijn.
    private var fresh: Bool {
        guard household.opened, !skipped else { return false }
        guard let content = household.content else { return true }
        // Kinderen alleen zijn nog geen huis: zolang er niets te doen valt
        // staat het opzetten er, en gaat het verder waar het gebleven was.
        return stepCount(content.day) + stepCount(content.night) == 0
            && content.week.isEmpty
            && content.events.isEmpty
    }

    /// De kinderen uit het eerste scherm het huis in. Namen die leeg bleven
    /// tellen niet mee; wie geen kleur koos krijgt de volgende uit de rij.
    private func savePeople() async {
        let content = household.content
            ?? Content(title: "", people: [], day: [], night: [], week: [], events: [])
        let working = asDraft(content)
        for kid in kids {
            let name = kid.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            working.people.append(DraftPerson(
                id: kid.id,
                name: name,
                emoji: kid.emoji.isEmpty ? "🙂" : kid.emoji,
                color: kid.color.isEmpty
                    ? COLORS[working.people.count % COLORS.count] : kid.color,
                traits: kid.traits,
                birthday: kid.birthday
            ))
        }
        guard !working.people.isEmpty else { return }
        saving = true
        _ = await household.save(working)
        saving = false
    }

    private func toggleChild(_ id: String) {
        Haptics.select()
        withAnimation(Motion.spring) { household.toggleChild(id) }
    }

    private func select(_ fresh: Routine) {
        guard fresh != household.routine else { return }
        Haptics.select()
        household.setRoutine(fresh)
    }

    @ViewBuilder
    private func pages(_ here: Plan, _ today: Today) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            columns(household.content, here, today)
        }
        .onChange(of: household.routine, initial: true) { _, fresh in
            if live { panes.go(to: fresh) } else { panes.jump(to: fresh); live = true }
        }
    }

    @ViewBuilder
    private func columns(_ content: Content?, _ here: Plan, _ today: Today) -> some View {
        if !m.wide { bars(here).entrance(1) }

        SlideView(slide: panes, span: m.width + 60) { r in
            pane(r, content, r == household.routine ? here : plan(r, content, today))
        }
        // De hoogte loopt mee met het paneel dat eraan komt, op dezelfde veer.
        .frame(height: heights[panes.arriving], alignment: .top)
        .animation(Motion.glide, value: panes.arriving)
    }

    /// De kinderen met hun balkje: op een breed scherm rechts in de kop,
    /// op de telefoon boven de kaartjes. Het is tegelijk de zeef — tik een
    /// kind aan en alleen zijn stappen blijven staan.
    @ViewBuilder
    private func bars(_ here: Plan) -> some View {
        if let content = household.content {
            ProgressBars(people: content.people, tallies: tallies(content, here.all),
                         topPad: m.wide ? 0 : 14,
                         visible: visible, filtered: filtered, onSelect: toggleChild)
        }
    }

    private func pane(_ r: Routine, _ content: Content?, _ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let content { column(r, content, plan) }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height },
                          action: { heights[r] = $0 })
    }

    @ViewBuilder
    private func column(_ r: Routine, _ content: Content, _ plan: Plan) -> some View {
        if !m.wide {
            ForEach(Array(plan.early.enumerated()), id: \.element.id) { (i, block) in
                Agenda(block: block, people: content.people,
                       slot: plan.earlyStarts[i])
            }
        }

        ForEach(Array(plan.groups.enumerated()), id: \.offset) { (gi, group) in
            let start = plan.groupStarts[gi]

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(group.name)
                    .textStyle(Fonts.group(m.wide ? 22 : 17))
                    .foregroundStyle(palette.ink)
                if !group.time.isEmpty {
                    Text(group.time)
                        .textStyle(Fonts.groupTime(m.wide ? 15 : 13))
                        .foregroundStyle(palette.muted)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, m.indent)
            .padding(.bottom, 10)
            .entrance(start)
            // De kopjes horen bij het raster, dus die gaan met de kaartjes
            // mee weg zolang de stapel er ligt.
            .opacity(focus.hides(r) ? 0 : 1)
            .animation(Motion.quick, value: focus.hides(r))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: m.gridGap),
                               count: m.perRow),
                spacing: m.gridGap
            ) {
                ForEach(Array(group.steps.enumerated()), id: \.element) { (si, step) in
                    Card(step: step, content: content, routine: r, visible: visible,
                         slot: start + 1 + si,
                         focus: focus, tasks: plan.tasks, at: plan.taskStarts[gi] + si)
                }
            }
        }

        if m.wide {
            ForEach(Array(plan.blocks.enumerated()), id: \.element.id) { (i, block) in
                AgendaCards(block: block, people: content.people,
                            slot: plan.cardStarts[i])
            }
        } else {
            ForEach(Array(plan.later.enumerated()), id: \.element.id) { (i, block) in
                Agenda(block: block, people: content.people,
                       slot: plan.laterStarts[i])
            }
        }

        if !plan.groups.isEmpty {
            ResetButton()
                .entrance(plan.resetSlot)
        }
    }

}

private struct ResetButton: View {
    @Environment(Household.self) private var household
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.spring) { household.clear() }
        } label: {
            Text("opnieuw beginnen")
                .textStyle(Fonts.pill)
                .foregroundStyle(palette.muted)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .overlay(Capsule().strokeBorder(INK.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.press(0.94, fade: 0.7))
        .accessibilityIdentifier("routine.reset")
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
    }
}

/// Het begin van een leeg huis, in twee stappen.
///
/// Eerst wie er wonen: een vakje per kind, met een naam, een gezicht en een
/// geboortedag. Dat is sneller ingevuld dan uitgeschreven, en het scheelt de
/// uitlezer het lastigste stuk werk.
///
/// Daarna hoe de week eruitziet. Dan staan de kinderen er al, dus hoeft er
/// niemand meer bedacht te worden en kan alles wat er verteld wordt meteen bij
/// de goede naam gezet worden.
private struct StartWho: View {
    @Binding var kids: [ChildData]
    var busy: Bool
    let onNext: () -> Void

    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    private static let faces = ["🦁", "🐱", "🦔", "🐸", "🐰", "🦊", "🐼", "🐨"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Line("Wie wonen er in huis? De namen en gezichtjes zien de kinderen straks op hun kaartjes.")

            FormHead(String(localized: "Hoeveel kinderen"), first: true)
            Chips {
                ForEach(1...6, id: \.self) { count in
                    Chip(label: "\(count)", on: kids.count == count,
                         id: "start.count.\(count)") { setCount(count) }
                }
            }

            FormHead(String(localized: "Wie zijn het"))
            Paper(radius: 26) {
                VStack(spacing: 0) {
                    ForEach(Array(kids.enumerated()), id: \.element.id) { (i, _) in
                        if i > 0 { HairLine() }
                        Kid(kid: $kids[i], row: i)
                    }
                }
            }

            CardButton(String(localized: "Verder"), glyph: busy ? "⏳" : "→",
                       id: "start.people", onTap: onNext)
                .padding(.top, 16)
                .opacity(busy || !anyName ? 0.5 : 1)
                .disabled(busy || !anyName)
        }
        .frame(maxWidth: 640, alignment: .leading)
        .entrance(1)
    }

    private var anyName: Bool {
        kids.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func setCount(_ count: Int) {
        while kids.count < count {
            kids.append(ChildData(id: newId(), name: "",
                                  emoji: Self.faces[kids.count % Self.faces.count],
                                  color: COLORS[kids.count % COLORS.count], traits: [:]))
        }
        if kids.count > count { kids.removeSubrange(count...) }
    }
}

/// Eén regel in dat vakje: gezicht, naam, geboortedag.
private struct Kid: View {
    @Binding var kid: ChildData
    let row: Int

    @Environment(\.palette) private var palette

    private static let faces = ["🦁", "🐱", "🦔", "🐸", "🐰", "🦊", "🐼", "🐨",
                                "🐧", "🐢", "🐥", "🦉"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Tikken geeft het volgende dier: een blad met alle emoji is
                // hier te veel gedoe voor iets dat later toch nog te kiezen is.
                EmojiButton(value: kid.emoji, size: 46) { nextFace() }
                    .accessibilityIdentifier("start.face.\(row)")
                    .accessibilityLabel(Spoken.icon)
                Field(value: $kid.name, placeholder: String(localized: "Naam"),
                      id: "start.name.\(row)")
            }
            HStack(spacing: 10) {
                DatePicker("Verjaardag", selection: bornBinding, in: ...Date(),
                           displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .opacity(0.02)
                    .overlay {
                        Chip(label: bornLabel, on: !kid.birthday.isEmpty) {}
                            .allowsHitTesting(false)
                    }
                    .accessibilityIdentifier("start.born.\(row)")
                    .accessibilityLabel(Spoken.date)
                if !kid.birthday.isEmpty {
                    Text(ageText(kid.birthday))
                        .textStyle(Fonts.listNote)
                        .foregroundStyle(palette.muted)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    private func nextFace() {
        let i = Self.faces.firstIndex(of: kid.emoji) ?? -1
        kid.emoji = Self.faces[(i + 1) % Self.faces.count]
    }

    private var bornLabel: String {
        guard let day = asDate(kid.birthday) else {
            return String(localized: "Verjaardag erbij")
        }
        return day.formatted(.dateTime.day().month(.abbreviated).year()
            .locale(.autoupdatingCurrent))
    }

    private var bornBinding: Binding<Date> {
        Binding(get: { asDate(kid.birthday) ?? Date() },
                set: { kid.birthday = dateString($0) })
    }
}

/// Stap twee: de week, in gewone woorden.
private struct StartWeek: View {
    let people: [Person]
    @Binding var typed: String
    let onRead: () -> Void
    let onSkip: () -> Void

    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Line("Vertel hoe een week eruitziet: school, bso, sport, clubjes. Ik maak er het ritme en de weekregels bij, en je ziet alles eerst als voorstel.")

            Paper(radius: 26) {
                PasteBox(value: $typed, hint: hint)
                    .frame(minHeight: m.wide ? 240 : 190)
            }

            CardButton(String(localized: "Maak er een ritme van"), glyph: "✨",
                       id: "start.read", onTap: onRead)
                .padding(.top, 16)

            TextButton(String(localized: "Dat doe ik later"), id: "start.skip", onTap: onSkip)
                .padding(.top, 14)
                .padding(.leading, 4)
        }
        .frame(maxWidth: 640, alignment: .leading)
        .entrance(1)
    }

    private var hint: String {
        let names = people.prefix(2).map { $0.name }.filter { !$0.isEmpty }
        let first = names.first ?? String(localized: "Emma")
        let second = names.count > 1 ? names[1] : String(localized: "Mads")
        return String(localized: """
            \(first) zit in groep 3B op de Vondelschool. Di, wo en vr gaan ze naar de bso.

            \(second) voetbalt op woensdagmiddag, en zwemles is zaterdagochtend om 9 uur.
            """)
    }
}

/// De regel tekst boven een stap van het begin.
private struct Line: View {
    let text: String

    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(TextStyle(font: Fonts.nunito(m.wide ? 17 : 15)))
            .foregroundStyle(palette.subtle)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, m.indent)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }
}

private struct Card: View {
    let step: Step
    let content: Content
    let routine: Routine
    let visible: Set<String>
    let slot: Int
    let focus: Focus
    let tasks: [Step]
    let at: Int

    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    private var taking: [Person] {
        participants(step, content.people).filter { visible.contains($0.id) }
    }

    private var allDone: Bool {
        let people = taking
        guard !people.isEmpty else { return false }
        return people.allSatisfy {
            household.checks[checkKey(routine, step.key, $0.id)] == true
        }
    }

    var body: some View {
        let key = step.key

        Paper(radius: m.cardRadius) {
            VStack(spacing: 0) {
                // Drie veren om dezelfde ruimte: boven het plaatje, tussen
                // het plaatje en de naam, en tussen de naam en de gezichtjes.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(step.icon)
                        .font(.system(size: m.iconSize))
                        .scaleEffect(allDone ? 1.12 : 1)
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    Text(step.label)
                        .textStyle(Fonts.taskName(m.nameSize))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                // De naam en het plaatje zijn de knop naar de grote kaart;
                // de gezichtjes eronder blijven van het vinkje.
                .contentShape(Rectangle())
                .accessibilityElement()
                .accessibilityLabel(step.label)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("card.open.\(key)")

                // Zo breed dat de rij precies bij het juiste kind afbreekt:
                // drie naast elkaar, met z'n vieren twee bij twee.
                Flow(gap: 2, rowGap: 2, centered: true) {
                    ForEach(taking) { person in
                        Ring(
                            person: person,
                            stepName: step.label,
                            stepId: key,
                            on: household.checks[checkKey(routine, key, person.id)] == true,
                            size: m.ringSize, faceSize: m.faceSize, glyphSize: m.glyphSize,
                            onTap: { household.toggle(checkKey(routine, key, person.id)) }
                        )
                    }
                }
                .frame(width: CGFloat(childrenPerRow(taking.count)) * (m.ringSize + 2) - 2)
            }
            .padding(.horizontal, m.cardX)
            .padding(.vertical, m.cardY)
            // Vierkant, net als de kaart die er groot uit groeit.
            .frame(maxWidth: .infinity, minHeight: m.cardHeight)
        }
        .scaleEffect(allDone ? 0.985 : 1)
        .animation(Motion.pop, value: allDone)
        .accessibilityIdentifier("card.\(key)")
        .entrance(slot)
        // Zolang de stapel er ligt is het raster leeg: alle kaartjes liggen
        // dan in het midden op elkaar.
        //
        // Het kaartje van de kaart die bovenop ligt gaat ineens weg en komt
        // ineens terug, zonder overgang. De grote kaart vervaagt bij het
        // landen wél, en die twee tegelijk laten vervagen gaf een knippering:
        // twee halfdoorzichtige kaarten over elkaar zijn samen niet één hele,
        // dus zakt het beeld er middenin even doorheen. Nu staat het kaartje
        // er meteen weer en vervaagt de kaart daar overheen — hetzelfde
        // plaatje twee keer, dus je ziet er niets van. De rest van het raster
        // heeft dat niet en vervaagt gewoon mee.
        .opacity(focus.hides(routine) ? 0 : 1)
        .animation(focus.swapped(routine, key) ? nil : Motion.quick,
                   value: focus.hides(routine))
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            focus.show(tasks, at: at, routine: routine)
        }
        // Waar het kaartje staat, zodat de grote kaart eruit groeit en er
        // straks weer in terugzakt.
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) {
            focus.place(routine, key, $0)
        }
        .onDisappear { focus.place(routine, key, nil) }
    }
}
