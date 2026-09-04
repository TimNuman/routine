import SwiftUI

/// Het gezichtje van één kind bij één stap: tikken zet het vinkje om, hier
/// en binnen een seconde ook op de telefoon. Hetzelfde rondje als daar, met
/// de groene rand eromheen zodra het af is — alleen zonder de vonkjes, want
/// die zijn op dit scherm groter dan het gezichtje zelf.
struct Face: View {
    let person: Person
    let step: Step
    let on: Bool
    var size: CGFloat = 34
    var glyph: CGFloat = 20
    let onTap: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pop: CGFloat = 1
    @State private var appeared = false

    private let stroke: CGFloat = 2.5

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .strokeBorder(GREEN, lineWidth: stroke)
                    .frame(width: size + stroke * 2, height: size + stroke * 2)
                    .opacity(on ? 1 : 0)
                    .scaleEffect(on ? 1 : 1.3)

                Circle()
                    .fill(soft(person.color, 0.16))
                    .overlay(Circle().strokeBorder(edge, lineWidth: stroke * 0.6))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(person.emoji)
                            .font(.system(size: glyph))
                            .grayscale(on ? 0 : 1)
                    }
                    .opacity(on ? 1 : 0.4)
            }
            .frame(width: size + stroke * 2 + 3, height: size + stroke * 2 + 3)
            .scaleEffect(pop)
            .animation(on ? Motion.spring : Motion.back, value: on)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onChange(of: on) { _, fresh in
            guard appeared, !reduceMotion else { return }
            if fresh { celebrate() } else { withAnimation(Motion.back) { pop = 1 } }
        }
        .onAppear { appeared = true }
        .accessibilityLabel("\(step.label), \(person.name)")
        .accessibilityValue(on ? Text("afgevinkt") : Text("nog niet afgevinkt"))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func celebrate() {
        withAnimation(Motion.dent) { pop = 0.86 }
        withAnimation(Motion.pop.delay(0.10)) { pop = 1.20 }
        withAnimation(Motion.settle.delay(0.30)) { pop = 1 }
    }

    private var edge: Color {
        on ? .clear : (palette.dark ? .white.opacity(0.18) : INK.opacity(0.14))
    }
}
