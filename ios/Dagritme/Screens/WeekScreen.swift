import SwiftUI

struct WeekScreen: View {
    @Environment(Household.self) private var household
    @Environment(\.palette) private var palette
    @Environment(\.metrics) private var m

    @State private var weekShift = 0
    @State private var pickedDay: String?
    @State private var direction: CGFloat = 1
    @State private var sheet: SheetState?
    @State private var busy = false
    @State private var assistantOpen = false
    @State private var draft: Draft?

    private var weekTitle: String {
        switch weekShift {
        case 0: return String(localized: "Deze week")
        case 1: return String(localized: "Volgende week")
        case -1: return String(localized: "Vorige week")
        case let n where n > 1: return String(localized: "Over \(n) weken")
        default: return String(localized: "\(-weekShift) weken terug")
        }
    }

    private var onToday: Bool {
        weekShift == 0 && dateString(selected) == dateString(household.now)
    }

    private func goToToday() {
        direction = selected > household.now ? -1 : 1
        Haptics.select()
        withAnimation(Motion.slide) {
            weekShift = 0
            pickedDay = nil
        }
    }

    private var selected: Date {
        let week = weekOf(household.now, weekShift)
        if let pickedDay, let match = week.first(where: { dateString($0) == pickedDay }) {
            return match
        }
        return week.first { dateString($0) == dateString(household.now) } ?? week[0]
    }

    private var blocks: [Block] {
        guard let content = household.content else { return [] }
        let items = itemsOn(content, selected)
        let today = dateString(selected) == dateString(household.now)
        return [
            Block(heading: String(localized: "Overdag"),
                  items: byTime(items.filter { !isEvening($0, EVENING_FROM) }, past: nil)),
            Block(heading: today ? String(localized: "Vanavond") : String(localized: "'s Avonds"),
                  items: byTime(items.filter { isEvening($0, EVENING_FROM) }, past: nil)),
        ].filter { !$0.items.isEmpty }
    }

    var body: some View {
        ZStack {
            Screen(title: weekTitle, subtitle: dateText(selected),
                   trailing: onToday ? nil : AnyView(TodayButton(onTap: goToToday)),
                   narrow: true) {
                WeekStrip(
                    now: household.now,
                    weekShift: weekShift,
                    selected: selected,
                    direction: direction,
                    onSelect: pickDay,
                    onShift: shiftWeeks
                )
                .entrance(1)

                if let content = household.content {
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            dayContent(content)
                        }
                        .id(dateString(selected))
                        .slides(direction)
                    }
                    .entrance(2)

                    CardButton(String(localized: "Iets bijzonders toevoegen"), plus: true,
                               id: "week.addOneOff") { openEntry(nil) }
                        .entrance(3)
                    CardButton(String(localized: "Typ of plak iets"), glyph: "✨",
                               id: "week.assistant") { assistantOpen = true }
                        .entrance(4)
                }
            }

            if assistantOpen, let content = household.content {
                AssistantSheet(
                    content: content,
                    onCancel: { assistantOpen = false },
                    onSave: { await household.save($0) }
                )
            }

            if let state = sheet, let content = household.content {
                EntrySheet(
                    title: state.title,
                    entry: state.entry,
                    place: state.place,
                    source: { draft! },
                    people: content.people,
                    busy: busy,
                    onCancel: { sheet = nil },
                    onSave: { _ in saveSheet() },
                    onDelete: state.place == nil ? nil : deleteEntry
                )
            }
        }
        .onChange(of: sheet != nil || assistantOpen) { _, open in
            household.sheetOpen = open
        }
        .onDisappear { household.sheetOpen = false }
    }

    @ViewBuilder
    private func dayContent(_ content: Content) -> some View {
        if blocks.isEmpty {
            BlockHead(String(localized: "Niks bijzonders"))
                .entrance(0, from: direction)
            Glass(radius: 26) {
                Text("Deze dag staat er niets in de agenda.")
                    .textStyle(Fonts.empty)
                    .foregroundStyle(palette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
            }
            .entrance(1, from: direction)
        }

        ForEach(Array(blocks.enumerated()), id: \.element.id) { (i, block) in
            Agenda(block: block, people: content.people,
                   from: leadSlots(i), direction: direction,
                   onOpen: { openEntry($0) })
        }
    }

    private func leadSlots(_ i: Int) -> Int {
        blocks.prefix(i).reduce(0) { $0 + 1 + $1.items.count }
    }


    private func pickDay(_ d: Date) {
        guard dateString(d) != dateString(selected) else { return }
        direction = d > selected ? 1 : -1
        Haptics.select()
        withAnimation(Motion.slide) { pickedDay = dateString(d) }
    }

    private func shiftWeeks(_ weeks: Int) {
        let fresh = calendar.date(byAdding: .day, value: weeks * 7, to: selected) ?? selected
        direction = weeks >= 0 ? 1 : -1
        Haptics.select()
        withAnimation(Motion.slide) {
            weekShift += weeks
            pickedDay = dateString(fresh)
        }
    }

    private func openEntry(_ item: AgendaItem?) {
        guard let content = household.content else { return }
        let working = asDraft(content)
        draft = working
        var place: Place?
        if let id = item?.id, let match = working.events.first(where: { $0.id == id }) {
            place = .event(match)
        }
        var entry = entryFrom(working, place)
        if place == nil {
            entry.icon = "🎉"
            entry.weekly = false
            entry.task = false
            entry.date = dateString(selected)
        }
        let name = item?.text ?? ""
        sheet = SheetState(title: name.isEmpty ? String(localized: "Iets eenmaligs") : name, place: place, entry: entry)
    }

    private func saveSheet() {
        guard let working = draft else { return }
        busy = true
        Task {
            let problem = await household.save(working)
            busy = false
            if problem == nil { sheet = nil }
        }
    }

    private func deleteEntry() {
        guard let working = draft, let place = sheet?.place,
              case let .event(item) = place else { return }
        working.events.removeAll { $0.id == item.id }
        busy = true
        Task {
            let problem = await household.save(working)
            busy = false
            if problem == nil { sheet = nil }
        }
    }
}

private struct TodayButton: View {
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onTap) {
            Text("naar vandaag")
                .textStyle(Fonts.pill)
                .foregroundStyle(ORANGE)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(Capsule().fill(ORANGE.opacity(0.14)))
                .overlay(Capsule().strokeBorder(ORANGE.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.press(0.94))
        .accessibilityIdentifier("week.today")
        .transition(.scale.combined(with: .opacity))
    }
}
