import SwiftUI

struct Chevron: View {
    var color: Color = SOFT_INK
    var height: CGFloat = 15

    var body: some View {
        let s = height / 15
        Path { path in
            path.move(to: CGPoint(x: 1.5 * s, y: 1.5 * s))
            path.addLine(to: CGPoint(x: 7 * s, y: 7.5 * s))
            path.addLine(to: CGPoint(x: 1.5 * s, y: 13.5 * s))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round, lineJoin: .round))
        .frame(width: 9 * s, height: height)
        .accessibilityHidden(true)
    }
}
