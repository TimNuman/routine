import SwiftUI

struct SwipeAway<Inner: View>: View {
    var title: String = "Weg"
    var blocked: String? = nil
    let onDelete: () -> Void
    @ViewBuilder var content: () -> Inner

    @Environment(\.palette) private var palette
    @State private var x: CGFloat = 0
    @State private var start: CGFloat?

    private let openWidth: CGFloat = 96
    private let instant: CGFloat = 168

    var body: some View {
        content()
            .offset(x: x)
            .overlay(alignment: .trailing) { strip }
            .contentShape(Rectangle())
            .highPriorityGesture(gesture)
            .overlay {
                if x != 0 {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                }
            }
            .onDisappear { x = 0 }
    }

    @ViewBuilder
    private var strip: some View {
        let width = max(0, -x)
        if width > 0 {
            Button { remove() } label: {
                ZStack {
                    blocked == nil ? RED : palette.muted.opacity(0.55)
                    Text(blocked ?? title)
                        .textStyle(Fonts.swipe)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 6)
                        .opacity(Double(min(1, width / 70)))
                }
                .frame(width: width)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(blocked != nil)
            .accessibilityLabel(blocked ?? title)
        }
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { g in
                guard abs(g.translation.width) > abs(g.translation.height) else { return }
                let from = start ?? x
                if start == nil { start = x }
                x = min(0, max(-instant - 40, from + g.translation.width))
            }
            .onEnded { g in
                start = nil
                guard abs(g.translation.width) > abs(g.translation.height) else {
                    close(); return
                }
                if blocked != nil { close(); return }
                if -x > instant { remove() }
                else if -x > 40 { withAnimation(Motion.spring) { x = -openWidth } }
                else { close() }
            }
    }

    private func close() { withAnimation(Motion.spring) { x = 0 } }

    private func remove() {
        guard blocked == nil else { close(); return }
        Haptics.on()
        withAnimation(Motion.short) { x = 0 }
        onDelete()
    }
}
