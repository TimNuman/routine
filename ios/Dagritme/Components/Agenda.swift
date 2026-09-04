import SwiftUI

struct Agenda: View {
    let block: Block
    let people: [Person]
    var side: Bool = false
    var first: Bool = false
    var from: Int? = nil
    var direction: CGFloat = 0
    var slot: Int? = nil
    var onOpen: ((AgendaItem) -> Void)? = nil

    @Environment(\.palette) private var palette

    private var later: Bool { block.later && !side }

    var body: some View {
        if !block.items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if later {
                    DashLine()
                        .frame(height: 1)
                        .padding(.bottom, 22)
                        .entrance(at: slot)
                }
                BlockHead(block.heading, topPad: side ? 0 : 22)
                    .staggered(from, 0, direction)
                    .entrance(at: slot)
                Glass(radius: 26) {
                    VStack(spacing: 0) {
                        ForEach(Array(block.items.enumerated()), id: \.offset) { (i, item) in
                            if i > 0 {
                                Rectangle().fill(palette.line).frame(height: 1)
                                    .padding(.horizontal, 16)
                                    .entrance(at: slot, extra: 1 + i)
                            }
                            Row(item: item, people: people,
                                first: i == 0, last: i == block.items.count - 1,
                                onOpen: item.special ? onOpen : nil)
                                .staggered(from, i + 1, direction)
                                .entrance(at: i == 0 ? nil : slot, extra: 1 + i)
                        }
                    }
                }
                .entrance(at: slot, extra: 1)
            }
            .padding(.top, side ? (first ? 0 : 22) : (block.later ? 26 : 0))
        }
    }
}

private struct Row: View {
    let item: AgendaItem
    let people: [Person]
    var first: Bool = false
    var last: Bool = false
    var onOpen: ((AgendaItem) -> Void)?

    @Environment(\.palette) private var palette

    private var picked: [Person] {
        item.who.compactMap { id in people.first { $0.id == id } }
    }

    private var showNames: Bool { !picked.isEmpty && picked.count < people.count }

    var body: some View {
        let when = timeText(item)
        let box = HStack(alignment: .top, spacing: 12) {
            Text(item.icon)
                .font(.system(size: 24))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.text)
                    .textStyle(Fonts.agendaName)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if showNames || !when.isEmpty {
                    HStack(spacing: 7) {
                        if showNames {
                            ForEach(picked) { Tag(person: $0) }
                        }
                        if !when.isEmpty {
                            Text(when).textStyle(Fonts.agendaTime).foregroundStyle(palette.muted)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(minHeight: 54, alignment: .leading)
        .background(item.special ? palette.special : .clear)
        .overlay(alignment: .leading) {
            if item.special {
                EdgeMark(top: first ? 24.5 : 0, bottom: last ? 24.5 : 0)
                    .stroke(ORANGE, style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                    .padding(.leading, 1.5)
            }
        }
        .contentShape(Rectangle())

        if let onOpen {
            Button {
                Haptics.tap()
                onOpen(item)
            } label: { box }
            .buttonStyle(.press(0.975))
        } else {
            box
        }
    }
}

struct Tag: View {
    let person: Person

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle().fill(.white.opacity(0.28))
                Text(person.emoji).font(.system(size: 11))
            }
            .frame(width: 19, height: 19)
            Text(person.name).textStyle(Fonts.tag).foregroundStyle(.white)
        }
        .padding(.leading, 3)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color(hex: person.color)))
    }
}

struct BlockHead: View {
    let text: String
    var topPad: CGFloat = 22

    @Environment(\.palette) private var palette

    init(_ text: String, topPad: CGFloat = 22) {
        self.text = text
        self.topPad = topPad
    }

    @Environment(\.metrics) private var m

    var body: some View {
        Text(text)
            .textStyle(Fonts.blockHead(m.wide ? 20 : 16))
            .foregroundStyle(palette.ink)
            .padding(.top, topPad)
            .padding(.horizontal, 16)
            .padding(.bottom, 9)
    }
}

private struct DashLine: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle()
            .fill(.clear)
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0.5))
                    path.addLine(to: CGPoint(x: 4000, y: 0.5))
                }
                .stroke(palette.dark ? Color.white.opacity(0.14) : INK.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .clipped()
    }
}

private extension View {
    @ViewBuilder
    func staggered(_ base: Int?, _ own: Int, _ direction: CGFloat) -> some View {
        if let base {
            entrance(base + own, from: direction, distance: 18)
        } else {
            self
        }
    }
}

private struct EdgeMark: Shape {
    var top: CGFloat
    var bottom: CGFloat

    func path(in r: CGRect) -> Path {
        var path = Path()
        let t = min(top, r.height / 2)
        let b = min(bottom, r.height / 2)

        if t > 0 {
            path.move(to: CGPoint(x: r.minX + t, y: r.minY))
            path.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + t),
                              control: CGPoint(x: r.minX, y: r.minY))
        } else {
            path.move(to: CGPoint(x: r.minX, y: r.minY))
        }

        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - b))

        if b > 0 {
            path.addQuadCurve(to: CGPoint(x: r.minX + b, y: r.maxY),
                              control: CGPoint(x: r.minX, y: r.maxY))
        }
        return path
    }
}

/// Wat er vandaag verder nog is, als kaartjes in plaats van een lijst: op een
/// breed scherm staan ze onder het dagritme, met hetzelfde grote plaatje en
/// dezelfde squircle als een taak. Er valt niets af te vinken — school gaat
/// door of je het nu aanvinkt of niet — dus ze zijn wat lager.
struct AgendaCards: View {
    let block: Block
    let people: [Person]
    var slot: Int? = nil

    @Environment(\.metrics) private var m

    var body: some View {
        if !block.items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                BlockHead(block.heading, topPad: 26)
                    .entrance(at: slot)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: m.gridGap),
                                   count: m.perRow),
                    spacing: m.gridGap
                ) {
                    ForEach(Array(block.items.enumerated()), id: \.offset) { (i, item) in
                        TodayCard(item: item, people: people)
                            .entrance(at: slot, extra: 1 + i)
                    }
                }
            }
        }
    }
}

private struct TodayCard: View {
    let item: AgendaItem
    let people: [Person]

    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    private var picked: [Person] {
        item.who.compactMap { id in people.first { $0.id == id } }
    }

    private var showNames: Bool { !picked.isEmpty && picked.count < people.count }

    var body: some View {
        let when = timeText(item)

        Paper(radius: m.cardRadius) {
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Text(item.icon)
                    .font(.system(size: m.iconSize * 0.86))
                    .accessibilityHidden(true)
                Text(item.text)
                    .textStyle(Fonts.taskName(m.nameSize))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if !when.isEmpty {
                    Text(when)
                        .textStyle(Fonts.agendaTime)
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
                if showNames {
                    Flow(gap: 4, rowGap: 3, centered: true) {
                        ForEach(picked) { Tag(person: $0) }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, m.cardX)
            .padding(.vertical, m.cardY)
            .frame(maxWidth: .infinity, minHeight: m.todayHeight)
            // Wat er los vandaag bij komt — een feestje, een fysio — krijgt
            // hetzelfde tintje als in de lijst. Het glas snijdt zijn inhoud
            // niet bij, dus loopt het tintje zelf om de bocht.
            .background(
                RoundedRectangle(cornerRadius: m.cardRadius, style: .continuous)
                    .fill(item.special ? palette.special : .clear)
            )
        }
        .accessibilityElement(children: .combine)
    }
}
