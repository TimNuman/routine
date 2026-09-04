import SwiftUI

/// Hoever ieder kind is: hetzelfde balkje als op de telefoon, onder elkaar.
struct ProgressPage: View {
    let plan: Plan
    let people: [Person]
    let first: Bool

    @Environment(WatchHousehold.self) private var household
    @Environment(\.palette) private var palette
    @Environment(\.sizes) private var m

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if first { Head(now: household.now) }

                if people.isEmpty {
                    Text("Er is nog niemand.")
                        .textStyle(Wrist.note)
                        .foregroundStyle(palette.muted)
                        .padding(.top, 10)
                } else {
                    Glass(radius: 18) {
                        VStack(spacing: 0) {
                            ForEach(Array(people.enumerated()), id: \.element.id) { (i, person) in
                                if i > 0 {
                                    Rectangle().fill(palette.divider)
                                        .frame(height: 1)
                                        .padding(.horizontal, 10)
                                }
                                Bar(person: person, tally: plan.tallies[person.id] ?? Tally())
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

private struct Bar: View {
    let person: Person
    let tally: Tally

    @Environment(\.palette) private var palette
    @Environment(\.sizes) private var m

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(soft(person.color, tally.complete ? 0.30 : 0.18))
                Text(person.emoji).font(.system(size: m.tileGlyph))
            }
            .frame(width: m.tile, height: m.tile)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(person.name)
                        .textStyle(Wrist.name)
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(tally.done)/\(tally.total)")
                        .textStyle(Wrist.tally)
                        .foregroundStyle(tally.complete ? GREEN : palette.muted)
                        .contentTransition(.numericText(value: Double(tally.done)))
                        .animation(Motion.short, value: tally.done)
                }
                Track(fraction: tally.fraction, complete: tally.complete,
                      color: Color(hex: person.color))
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .animation(Motion.calm, value: tally.complete)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(tally.done) van \(tally.total) af"))
    }
}

private struct Track: View {
    let fraction: Double
    let complete: Bool
    let color: Color

    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { space in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule()
                    .fill(complete ? GREEN : color)
                    .frame(width: max(0, min(1, fraction)) * space.size.width)
                    .animation(Motion.spring, value: fraction)
                    .animation(Motion.calm, value: complete)
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
