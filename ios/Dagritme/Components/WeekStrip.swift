import SwiftUI

struct WeekStrip: View {
    let now: Date
    let weekShift: Int
    let selected: Date
    var direction: CGFloat = 1
    let onSelect: (Date) -> Void
    let onShift: (Int) -> Void

    @Namespace private var space

    var body: some View {
        let days = weekOf(now, weekShift)
        let today = dateString(now)
        let current = dateString(selected)

        Glass(radius: 24) {
            HStack(spacing: 0) {
                arrow(-1, "Vorige week")

                ZStack {
                    HStack(spacing: 0) {
                        ForEach(days, id: \.self) { d in
                            day(d, selected: dateString(d) == current,
                                today: dateString(d) == today)
                        }
                    }
                    .id(weekShift)
                    .slides(direction)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                arrow(1, "Volgende week")
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func day(_ d: Date, selected on: Bool, today: Bool) -> some View {
        Button { onSelect(d) } label: {
            VStack(spacing: 8) {
                Text(DAY_LETTERS[DAYS[weekdayIndex(d)]] ?? "")
                    .textStyle(Fonts.weekLetter)
                    .foregroundStyle(SOFT_INK)
                ZStack {
                    if on {
                        Circle()
                            .fill(ORANGE)
                            .matchedGeometryEffect(id: "dot-\(weekShift)", in: space)
                    }
                    if !on && today {
                        Circle().strokeBorder(ORANGE.opacity(0.5), lineWidth: 2)
                    }
                    Text("\(calendar.component(.day, from: d))")
                        .textStyle(Fonts.weekDay)
                        .foregroundStyle(on ? .white : INK)
                        .animation(Motion.quick, value: on)
                }
                .frame(width: 38, height: 38)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press(0.92))
        .accessibilityLabel(dateText(d))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func arrow(_ step: Int, _ title: String) -> some View {
        Button { onShift(step) } label: {
            Chevron()
                .scaleEffect(x: step < 0 ? -1 : 1, y: 1)
                .opacity(0.65)
                .frame(width: 26)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.smallPress)
        .accessibilityLabel(title)
    }
}
