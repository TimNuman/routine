import SwiftUI

struct Tally {
    var done: Int = 0
    var total: Int = 0
    var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    var complete: Bool { total > 0 && done >= total }
}

struct ProgressBars: View {
    let people: [Person]
    let tallies: [String: Tally]
    var topPad: CGFloat
    var visible: Set<String> = []
    var filtered: Bool = false
    var onSelect: ((String) -> Void)? = nil

    private var many: Bool { people.count > 2 }

    var body: some View {
        Glass(radius: 26) {
            if many {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { (row, pair) in
                        HStack(spacing: 0) {
                            ForEach(Array(pair.enumerated()), id: \.element.id) { (column, person) in
                                Tile(person: person, tally: tallies[person.id] ?? Tally(),
                                     left: column > 0, top: row > 0,
                                     on: !filtered || visible.contains(person.id),
                                     filtered: filtered, onSelect: onSelect)
                                    .frame(maxWidth: .infinity)
                            }
                            if pair.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { (i, person) in
                        Tile(person: person, tally: tallies[person.id] ?? Tally(),
                             left: i > 0, top: false,
                             on: !filtered || visible.contains(person.id),
                             filtered: filtered, onSelect: onSelect)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.top, topPad)
    }

    private var rows: [[Person]] {
        stride(from: 0, to: people.count, by: 2).map {
            Array(people[$0..<min($0 + 2, people.count)])
        }
    }
}

private struct Tile: View {
    let person: Person
    let tally: Tally
    let left: Bool
    let top: Bool
    var on: Bool = true
    var filtered: Bool = false
    var onSelect: ((String) -> Void)?

    @Environment(\.palette) private var palette
    @State private var pop: CGFloat = 1
    @State private var appeared = false

    private var highlighted: Bool { filtered && on }
    private var dimmed: Bool { !on }

    var body: some View {
        if let onSelect {
            Button { onSelect(person.id) } label: { tile }
                .buttonStyle(.press(0.96))
                .accessibilityLabel(label)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        } else {
            tile
        }
    }

    private var label: String {
        if !filtered { return "Alleen \(person.name) tonen" }
        return on ? "\(person.name) verbergen" : "\(person.name) er weer bij"
    }

    private var tile: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(tint(person.color, tally.complete ? 0.30 : 0.18))
                Text(person.emoji).font(.system(size: 26))
            }
            .frame(width: 46, height: 46)
            .scaleEffect(pop)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(person.name)
                        .textStyle(Fonts.name)
                        .foregroundStyle(highlighted ? Color(hex: person.color) : palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(tally.done)/\(tally.total)")
                        .textStyle(Fonts.tally)
                        .foregroundStyle(tally.complete ? GREEN : palette.muted)
                        .contentTransition(.numericText(value: Double(tally.done)))
                        .animation(Motion.short, value: tally.done)
                        .animation(Motion.short, value: tally.total)
                }
                Track(fraction: tally.fraction, complete: tally.complete,
                      color: Color(hex: person.color))
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .overlay(alignment: .leading) {
            if left { Rectangle().fill(palette.divider).frame(width: 1) }
        }
        .overlay(alignment: .top) {
            if top { Rectangle().fill(palette.divider).frame(height: 1) }
        }
        .opacity(dimmed ? 0.42 : 1)
        .grayscale(dimmed ? 0.85 : 0)
        .contentShape(Rectangle())
        .animation(Motion.calm, value: tally.complete)
        .animation(Motion.short, value: on)
        .animation(Motion.short, value: filtered)
        .onChange(of: tally.complete) { _, fresh in
            guard appeared, fresh else { return }
            Haptics.done()
            withAnimation(Motion.dent) { pop = 0.90 }
            withAnimation(Motion.pop.delay(0.08)) { pop = 1.20 }
            withAnimation(Motion.settle.delay(0.30)) { pop = 1 }
        }
        .onAppear { appeared = true }
    }
}

private struct Track: View {
    let fraction: Double
    let complete: Bool
    let color: Color
    @Environment(\.palette) private var palette

    @State private var sheen = 0
    @State private var appeared = false

    var body: some View {
        GeometryReader { space in
            let width = space.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule()
                    .fill(complete ? GREEN : color)
                    .frame(width: max(0, min(1, fraction)) * width)
                    .animation(Motion.spring, value: fraction)
                    .animation(Motion.calm, value: complete)

                if sheen > 0 {
                    Sheen(width: width).id(sheen)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 7)
        .onChange(of: complete) { _, fresh in
            guard appeared, fresh else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                sheen &+= 1
            }
        }
        .onAppear { appeared = true }
    }
}

private struct Sheen: View {
    let width: CGFloat
    @State private var x: CGFloat = -0.35

    var body: some View {
        LinearGradient(
            colors: [.white.opacity(0), .white.opacity(0.75), .white.opacity(0)],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(width: max(24, width * 0.35))
        .offset(x: x * width)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.62)) { x = 1.05 }
        }
    }
}
