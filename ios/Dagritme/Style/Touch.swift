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

struct Entrance: ViewModifier {
    var index: Int = 0
    var from: CGFloat = 0
    var distance: CGFloat = 22
    var animation: Animation = Motion.short

    @State private var shown = false

    func body(content: Self.Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.95, anchor: .top)
            .offset(x: shown ? 0 : distance * from,
                    y: shown ? 0 : (from == 0 ? 12 : 0))
            .onAppear {
                guard !shown else { return }
                withAnimation(animation.delay(Motion.stagger(index))) { shown = true }
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
}

extension View {
    @ViewBuilder
    func shifted(_ shift: Shift?, extra: Int = 0) -> some View {
        if let s = shift {
            entrance(s.slot + extra)
                .offset(x: s.steps * s.span)
                .animation(Motion.entrance.delay(Motion.stagger(s.slot + extra)),
                           value: s.steps)
        } else {
            self
        }
    }
}
