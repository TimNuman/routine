import SwiftUI

/// Wat er op de agenda staat: overdag *Vandaag*, 's avonds *Vanavond* en
/// *Morgen*. Scrollen doe je met de kroon.
struct AgendaPage: View {
    let blocks: [Block]
    let people: [Person]
    let first: Bool

    @Environment(WatchHousehold.self) private var household
    @Environment(\.palette) private var palette
    @Environment(\.sizes) private var m

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if first { Head(now: household.now) }

                ForEach(Array(blocks.enumerated()), id: \.element.id) { (i, block) in
                    Text(block.heading)
                        .textStyle(Wrist.head)
                        .foregroundStyle(palette.ink)
                        .padding(.top, i == 0 ? 0 : 14)
                        .padding(.bottom, 6)
                        .padding(.horizontal, 4)

                    Glass(radius: 18) {
                        VStack(spacing: 0) {
                            ForEach(Array(block.items.enumerated()), id: \.offset) { (j, item) in
                                if j > 0 {
                                    Rectangle().fill(palette.line)
                                        .frame(height: 1)
                                        .padding(.leading, 10)
                                }
                                Row(item: item, people: people)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, m.gutter)
            .padding(.bottom, 12)
        }
    }
}

private struct Row: View {
    let item: AgendaItem
    let people: [Person]

    @Environment(\.palette) private var palette

    private var picked: [Person] {
        item.who.compactMap { id in people.first { $0.id == id } }
    }

    private var showFaces: Bool { !picked.isEmpty && picked.count < people.count }

    var body: some View {
        let when = timeText(item)
        HStack(alignment: .top, spacing: 8) {
            Text(item.icon)
                .font(.system(size: 17))
                .frame(width: 21)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .textStyle(Wrist.item)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if showFaces || !when.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(showFaces ? picked : []) { person in
                            ZStack {
                                Circle().fill(soft(person.color, 0.85))
                                Text(person.emoji).font(.system(size: 9))
                            }
                            .frame(width: 16, height: 16)
                        }
                        if !when.isEmpty {
                            Text(when)
                                .textStyle(Wrist.time)
                                .foregroundStyle(palette.muted)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Wat maar één keer voorkomt — een verjaardag, de tandarts — krijgt
        // hetzelfde oranje randje als op de telefoon.
        .background(item.special ? palette.special : .clear)
        .overlay(alignment: .leading) {
            if item.special { Rectangle().fill(ORANGE).frame(width: 3) }
        }
        .accessibilityElement(children: .combine)
    }
}
