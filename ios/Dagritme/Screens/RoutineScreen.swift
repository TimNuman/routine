import SwiftUI

struct RoutineScreen: View {
    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette
    @Environment(\.tabOffset) private var tabOffset

    @State private var heights: [Routine: CGFloat] = [:]

    private var everyone: Set<String> {
        Set((household.content?.people ?? []).map(\.id))
    }

    private var visible: Set<String> {
        let left = everyone.subtracting(household.hidden)
        return left.isEmpty ? everyone : left
    }

    private var filtered: Bool { visible.count < everyone.count }

    private func blocks(_ r: Routine) -> [Block] {
        guard let content = household.content else { return [] }
        return routineBlocks(content, r, household.now)
            .map { block in
                var out = block
                out.items = block.items.filter(belongs)
                return out
            }
            .filter { !$0.items.isEmpty }
    }

    private func allGroups(_ r: Routine) -> [StepGroup] {
        guard let content = household.content else { return [] }
        return content[r]
            .map { group in
                var out = group
                out.steps = group.steps.filter { !$0.label.isEmpty && onDay($0, household.now) }
                return out
            }
            .filter { !$0.steps.isEmpty }
    }

    private func groups(_ r: Routine) -> [StepGroup] {
        guard let content = household.content, filtered else { return allGroups(r) }
        return allGroups(r)
            .map { group in
                var out = group
                out.steps = group.steps.filter { step in
                    participants(step, content.people).contains { visible.contains($0.id) }
                }
                return out
            }
            .filter { !$0.steps.isEmpty }
    }

    private func belongs(_ item: AgendaItem) -> Bool {
        guard filtered else { return true }
        return item.who.isEmpty || item.who.contains { visible.contains($0) }
    }

    private var tallies: [String: Tally] {
        guard let content = household.content else { return [:] }
        var out: [String: Tally] = [:]
        for person in content.people {
            var tally = Tally()
            for group in allGroups(household.routine) {
                for step in group.steps {
                    guard participants(step, content.people).contains(where: { $0.id == person.id })
                    else { continue }
                    tally.total += 1
                    if household.checks[checkKey(household.routine, stepKey(step), person.id)] == true {
                        tally.done += 1
                    }
                }
            }
            out[person.id] = tally
        }
        return out
    }

    var body: some View {
        Screen(
            title: household.routine == .night ? String(localized: "Avond") : String(localized: "Ochtend"),
            subtitle: dateText(household.now),
            center: AnyView(Segment(routine: household.routine, onSelect: select,
                                    topPad: m.wide ? 0 : 16))
        ) {
            pages
        }
    }

    private func toggleChild(_ id: String) {
        Haptics.select()
        withAnimation(Motion.spring) { household.toggleChild(id) }
    }

    private func select(_ fresh: Routine) {
        guard fresh != household.routine else { return }
        Haptics.select()
        withAnimation(Motion.slide) { household.setRoutine(fresh) }
    }

    @ViewBuilder
    private var pages: some View {
        let withSide = m.wide && !blocks(household.routine).isEmpty

        if m.wide {
            HStack(alignment: .top, spacing: m.columnGap) {
                VStack(alignment: .leading, spacing: 0) {
                    columns
                }
                .padding(.top, withSide ? 31 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                if withSide, let content = household.content {
                    ZStack(alignment: .topLeading) {
                        sidePane(.day, content)
                        sidePane(.night, content)
                    }
                    .frame(width: m.sideColumn)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) { columns }
        }
    }

    @ViewBuilder
    private var columns: some View {
        if let content = household.content {
            ProgressBars(people: content.people, tallies: tallies, topPad: m.wide ? 0 : 14,
                         visible: visible, filtered: filtered, onSelect: toggleChild)
                .shifted(Shift(slot: 1, steps: tabOffset, span: m.width + 60))
        }
        routinePair
    }

    private var routinePair: some View {
        ZStack(alignment: .topLeading) {
            pane(.day)
            pane(.night)
        }
        .frame(height: heights[household.routine], alignment: .top)
    }

    private func pane(_ r: Routine) -> some View {
        let here = household.routine == r
        return VStack(alignment: .leading, spacing: 0) { column(r) }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height },
                              action: { heights[r] = $0 })
            .zIndex(here ? 1 : 0)
            .allowsHitTesting(here)
            .accessibilityHidden(!here)
    }

    private func sidePane(_ r: Routine, _ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks(r).enumerated()), id: \.element.id) { (i, block) in
                Agenda(block: block, people: content.people, side: true, first: i == 0,
                       shift: shift(r, slots(blocks(r).prefix(i))))
            }
        }
        .zIndex(household.routine == r ? 1 : 0)
        .allowsHitTesting(household.routine == r)
        .accessibilityHidden(household.routine != r)
    }

    @ViewBuilder
    private func column(_ r: Routine) -> some View {
        if let content = household.content {
            if !m.wide {
                ForEach(Array(blocks(r).filter { !$0.later }.enumerated()), id: \.element.id) { (i, block) in
                    Agenda(block: block, people: content.people,
                           shift: shift(r, slots(blocks(r).filter { !$0.later }.prefix(i))))
                }
            }

            ForEach(Array(groups(r).enumerated()), id: \.offset) { (gi, group) in
                let start = leadSlots(r, gi)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(group.name).textStyle(Fonts.group).foregroundStyle(palette.ink)
                    if !group.time.isEmpty {
                        Text(group.time).textStyle(Fonts.groupTime).foregroundStyle(palette.muted)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, m.indent)
                .padding(.bottom, 10)
                .shifted(shift(r, start))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: m.gridGap),
                                   count: m.perRow),
                    spacing: m.gridGap
                ) {
                    ForEach(Array(group.steps.enumerated()), id: \.element) { (si, step) in
                        Card(step: step, content: content, routine: r, visible: visible,
                             shift: shift(r, start + 1 + si))
                    }
                }
            }

            if !m.wide {
                ForEach(Array(blocks(r).filter { $0.later }.enumerated()), id: \.element.id) { (i, block) in
                    Agenda(block: block, people: content.people,
                           shift: shift(r, tailSlots(r) + slots(blocks(r).filter { $0.later }.prefix(i))))
                }
            }

            if !groups(r).isEmpty {
                ResetButton()
                    .shifted(shift(r, tailSlots(r) + slots(blocks(r).filter { $0.later }) + 1))
            }
        }
    }

    private func shift(_ r: Routine, _ slot: Int) -> Shift {
        let routineOffset: CGFloat = household.routine == r ? 0 : (r == .night ? 1 : -1)
        return Shift(slot: slot, steps: routineOffset + tabOffset, span: m.width + 60)
    }

    private func slots<S: Sequence>(_ blocks: S) -> Int where S.Element == Block {
        blocks.reduce(0) { $0 + 1 + $1.items.count }
    }

    private func leadSlots(_ r: Routine, _ gi: Int) -> Int {
        var n = m.wide ? 0 : slots(blocks(r).filter { !$0.later })
        for group in groups(r).prefix(gi) {
            n += 1 + group.steps.count
        }
        return n
    }

    private func tailSlots(_ r: Routine) -> Int {
        leadSlots(r, groups(r).count)
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

private struct Card: View {
    let step: Step
    let content: Content
    let routine: Routine
    let visible: Set<String>
    let shift: Shift

    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    private var taking: [Person] {
        participants(step, content.people).filter { visible.contains($0.id) }
    }

    private var allDone: Bool {
        let key = stepKey(step)
        guard !taking.isEmpty else { return false }
        return taking.allSatisfy {
            household.checks[checkKey(routine, key, $0.id)] == true
        }
    }

    var body: some View {
        let key = stepKey(step)

        Glass(radius: 22) {
            VStack(spacing: m.cardGap) {
                Spacer(minLength: 0)
                Text(step.icon)
                    .font(.system(size: m.iconSize))
                    .scaleEffect(allDone ? 1.12 : 1)
                    .accessibilityHidden(true)
                Text(step.label)
                    .textStyle(Fonts.taskName(m.nameSize))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Spacer(minLength: 0)
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
            }
            .padding(.horizontal, m.cardX)
            .padding(.vertical, m.cardY)
            .frame(maxWidth: .infinity, minHeight: m.cardHeight)
        }
        .scaleEffect(allDone ? 0.985 : 1)
        .animation(Motion.pop, value: allDone)
        .accessibilityIdentifier("card.\(stepKey(step))")
        .shifted(shift)
    }
}
