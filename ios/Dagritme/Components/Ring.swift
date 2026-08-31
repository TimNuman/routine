import SwiftUI

struct Ring: View {
    let person: Person
    let stepName: String
    let stepId: String
    let on: Bool
    var size: CGFloat = 40
    var faceSize: CGFloat = 34
    var glyphSize: CGFloat = 21
    let onTap: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pop: CGFloat = 1
    @State private var spin: Double = 0
    @State private var pressed = false
    @State private var appeared = false
    @State private var burst = 0
    @State private var byMe = false

    var body: some View {
        ZStack {
            if burst > 0 && !reduceMotion {
                Sparks(color: GREEN, from: faceSize * 0.66, to: faceSize * 1.15)
                    .id(burst)
            }

            Circle()
                .strokeBorder(GREEN, lineWidth: 2.5)
                .frame(width: faceSize + 5, height: faceSize + 5)
                .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 4)
                .opacity(on ? 1 : 0)
                .scaleEffect(on ? 1 : 1.35)

            Circle()
                .fill(soft(person.color, 0.16))
                .overlay(Circle().strokeBorder(edgeColor, lineWidth: 1.5))
                .frame(width: faceSize, height: faceSize)
                .overlay {
                    Text(person.emoji)
                        .font(.system(size: glyphSize))
                        .grayscale(on ? 0 : 1)
                        .accessibilityHidden(true)
                }
                .opacity(on ? 1 : 0.4)
        }
        .frame(width: size, height: size)
        .scaleEffect(pop * (pressed ? 0.88 : 1))
        .rotationEffect(.degrees(spin))
        .contentShape(Circle())
        .animation(on ? Motion.spring : Motion.back, value: on)
        .animation(pressed ? Motion.press : Motion.release, value: pressed)
        .onTapGesture {
            byMe = true
            onTap()
        }
        .onLongPressGesture(minimumDuration: 2, maximumDistance: 8) { } onPressingChanged: { busy in
            pressed = busy
            if busy { Haptics.prepare() }
        }
        .onChange(of: on) { _, fresh in
            guard appeared else { return }
            if fresh { celebrate() } else { revert() }
            byMe = false
        }
        .onAppear { appeared = true }
        .accessibilityElement()
        .accessibilityIdentifier("ring.\(stepId).\(person.id)")
        .accessibilityLabel(Spoken.step(stepName, person.name))
        .accessibilityValue(on ? Spoken.stepDone : Spoken.stepOpen)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func celebrate() {
        if byMe { Haptics.on() }
        guard !reduceMotion else { return }
        burst &+= 1
        withAnimation(Motion.dent) { pop = 0.86 }
        withAnimation(Motion.pop.delay(0.10)) { pop = 1.22; spin = -9 }
        withAnimation(Motion.settle.delay(0.30)) { pop = 1; spin = 0 }
    }

    private func revert() {
        if byMe { Haptics.off() }
        withAnimation(Motion.back) { pop = 1; spin = 0 }
    }

    private var edgeColor: Color {
        on ? .clear : (palette.dark ? .white.opacity(0.18) : INK.opacity(0.14))
    }
}

private struct Sparks: View {
    let color: Color
    let from: CGFloat
    let to: CGFloat

    private let count = 5

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                spark(i)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(Motion.spark) { progress = 1 }
            }
        }
    }

    private func spark(_ i: Int) -> some View {
        let part: Double = count > 1 ? Double(i) / Double(count - 1) : 0.5
        let angle: Double = -Double.pi * (0.19 + 0.62 * part)
        let distance: CGFloat = from + (to - from) * progress
        let x: CGFloat = CGFloat(cos(angle)) * distance
        let y: CGFloat = CGFloat(sin(angle)) * distance
        let strength: CGFloat = min(1.0, (1.0 - progress) * 1.8)
        return Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .scaleEffect(1.0 - progress * 0.45)
            .opacity(Double(strength))
            .offset(x: x, y: y)
    }
}
