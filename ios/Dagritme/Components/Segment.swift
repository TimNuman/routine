import SwiftUI

struct Segment: View {
    var routine: Routine
    var onSelect: (Routine) -> Void
    var topPad: CGFloat = 16

    @Environment(\.palette) private var palette

    var body: some View {
        Glass(radius: 19) {
            GeometryReader { space in
                let width = space.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palette.dark ? Color.white.opacity(0.92) : .white)
                        .frame(width: width / 2, height: 42)
                        .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 3)
                        .offset(x: routine == .night ? width / 2 : 0)
                        .animation(Motion.spring, value: routine)

                    HStack(spacing: 0) {
                        option(String(localized: "ochtend"), .day, "segment.day")
                        option(String(localized: "avond"), .night, "segment.night")
                    }
                }
            }
            .frame(height: 42)
            .padding(4)
        }
        .padding(.top, topPad)
    }

    @ViewBuilder
    private func option(_ label: String, _ value: Routine, _ id: String) -> some View {
        let on = routine == value
        Button { onSelect(value) } label: {
            Text(label)
                .textStyle(Fonts.button)
                .foregroundStyle(on ? INK : palette.muted)
                .animation(Motion.short, value: on)
                .scaleEffect(on ? 1.04 : 1)
                .animation(Motion.spring, value: on)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
