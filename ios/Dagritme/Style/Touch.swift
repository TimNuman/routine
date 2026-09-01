import SwiftUI
import UIKit

struct Press: ButtonStyle {
    var scale: CGFloat = 0.96
    var fade: Double = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? fade : 1)
            .animation(configuration.isPressed ? Motion.press : Motion.release,
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == Press {
    static var press: Press { Press() }
    static var smallPress: Press { Press(scale: 0.90, fade: 0.75) }
    static func press(_ scale: CGFloat, fade: Double = 1) -> Press {
        Press(scale: scale, fade: fade)
    }
}

@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notice = UINotificationFeedbackGenerator()

    static func prepare() {
        rigid.prepare()
        soft.prepare()
    }

    static func on() { rigid.impactOccurred(intensity: 0.9) }
    static func off() { soft.impactOccurred(intensity: 0.45) }
    static func done() { notice.notificationOccurred(.success) }
    static func select() { selection.selectionChanged() }
    static func tap() { light.impactOccurred(intensity: 0.6) }
}

private struct EntranceOnKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Uit voor een kolom die net gebouwd is om naartoe te schuiven: die komt
    /// al van opzij en hoeft niet ook nog op te doemen.
    var entranceOn: Bool {
        get { self[EntranceOnKey.self] }
        set { self[EntranceOnKey.self] = newValue }
    }
}

struct Entrance: ViewModifier {
    var index: Int = 0
    var from: CGFloat = 0
    var distance: CGFloat = 22
    var animation: Animation = Motion.short

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.entranceOn) private var entranceOn
    @State private var shown = false

    func body(content: Self.Content) -> some View {
        let visible = shown || !entranceOn
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible || reduceMotion ? 1 : 0.95, anchor: .top)
            .offset(x: visible || reduceMotion ? 0 : distance * from,
                    y: visible || reduceMotion ? 0 : (from == 0 ? 12 : 0))
            .onAppear {
                guard !shown else { return }
                if entranceOn {
                    withAnimation(animation.delay(Motion.stagger(index))) { shown = true }
                } else {
                    shown = true
                }
            }
    }
}

extension View {
    func entrance(_ index: Int = 0, from: CGFloat = 0,
                  distance: CGFloat = 22, animation: Animation = Motion.short) -> some View {
        modifier(Entrance(index: index, from: from, distance: distance, animation: animation))
    }

    func slides(_ direction: CGFloat) -> some View {
        transition(.asymmetric(
            insertion: .move(edge: direction >= 0 ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: direction >= 0 ? .leading : .trailing)
                .combined(with: .opacity)
        ))
    }
}

struct Shift: Equatable {
    var slot: Int
    var steps: CGFloat
    var span: CGFloat
    var animated = true

    func at(_ slot: Int) -> Shift {
        var out = self
        out.slot = slot
        return out
    }
}

extension View {
    @ViewBuilder
    func shifted(_ shift: Shift?, extra: Int = 0) -> some View {
        if let s = shift {
            entrance(s.slot + extra)
                .offset(x: s.steps * s.span)
                .animation(s.animated ? Motion.glide(s.slot + extra) : nil, value: s.steps)
        } else {
            self
        }
    }
}
