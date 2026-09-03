import SwiftUI

private struct Plan {
    var blocks: [Block] = []
    var early: [Block] = []
    var later: [Block] = []
    var all: [StepGroup] = []
    var groups: [StepGroup] = []
    var sideStarts: [Int] = []
    var earlyStarts: [Int] = []
    var laterStarts: [Int] = []
    var groupStarts: [Int] = []
    var resetSlot: Int = 0
}

struct RoutineScreen: View {
    @Environment(Household.self) private var household
    /// De schuif tussen ochtend en avond; de schakelaar zet hem in gang.
    @State private var panes = Slide<Routine>(.day)
    @State private var live = false
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    @State private var heights: [Routine: CGFloat] = [:]

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

        out.blocks = routineBlocks(content, r, household.now)
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

        var side = 0
        for block in out.blocks {
            out.sideStarts.append(side)
            side += 1 + block.items.count
        }

        var lead = 0
        for block in out.early {
            out.earlyStarts.append(lead)
            lead += 1 + block.items.count
        }
        if m.wide { lead = 0 }

        for group in out.groups {
            out.groupStarts.append(lead)
            lead += 1 + group.steps.count
        }

        for block in out.later {
            out.laterStarts.append(lead)
            lead += 1 + block.items.count
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
        household.setRoutine(fresh)
    }

    @ViewBuilder
    private var pages: some View {
        let content = household.content
        let today = Today(household.now)
        let here = plan(household.routine, content, today)
        let withSide = m.wide && !here.blocks.isEmpty

        Group {
            if m.wide {
                HStack(alignment: .top, spacing: m.columnGap) {
                    VStack(alignment: .leading, spacing: 0) {
                        columns(content, here, today)
                    }
                    .padding(.top, withSide ? 31 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if withSide, let content {
                        SlideView(slide: panes, span: m.width + 60) { r in
                            sidePane(r, content, plan(r, content, today))
                        }
                        .frame(width: m.sideColumn)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    columns(content, here, today)
                }
            }
        }
        .onChange(of: household.routine, initial: true) { _, fresh in
            if live { panes.go(to: fresh) } else { panes.jump(to: fresh); live = true }
        }
    }

    @ViewBuilder
    private func columns(_ content: Content?, _ here: Plan, _ today: Today) -> some View {
        if let content {
            ProgressBars(people: content.people, tallies: tallies(content, here.all),
                         topPad: m.wide ? 0 : 14,
                         visible: visible, filtered: filtered, onSelect: toggleChild)
                .entrance(1)
        }

        SlideView(slide: panes, span: m.width + 60) { r in
            pane(r, content, r == household.routine ? here : plan(r, content, today))
        }
        // De hoogte loopt mee met het paneel dat eraan komt, op dezelfde veer.
        .frame(height: heights[panes.arriving], alignment: .top)
        .animation(Motion.glide, value: panes.arriving)
    }

    private func pane(_ r: Routine, _ content: Content?, _ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let content { column(r, content, plan) }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height },
                          action: { heights[r] = $0 })
    }

    private func sidePane(_ r: Routine, _ content: Content, _ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(plan.blocks.enumerated()), id: \.element.id) { (i, block) in
                Agenda(block: block, people: content.people, side: true, first: i == 0,
                       slot: plan.sideStarts[i])
            }
        }
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
                Text(group.name).textStyle(Fonts.group).foregroundStyle(palette.ink)
                if !group.time.isEmpty {
                    Text(group.time).textStyle(Fonts.groupTime).foregroundStyle(palette.muted)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, m.indent)
            .padding(.bottom, 10)
            .entrance(start)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: m.gridGap),
                               count: m.perRow),
                spacing: m.gridGap
            ) {
                ForEach(Array(group.steps.enumerated()), id: \.element) { (si, step) in
                    Card(step: step, content: content, routine: r, visible: visible,
                         slot: start + 1 + si)
                }
            }
        }

        if !m.wide {
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

private struct Card: View {
    let step: Step
    let content: Content
    let routine: Routine
    let visible: Set<String>
    let slot: Int

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
        .accessibilityIdentifier("card.\(key)")
        .entrance(slot)
    }
}
