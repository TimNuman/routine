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

struct Cross: View {
    var color: Color = SOFT_INK
    var size: CGFloat = 13

    var body: some View {
        let s = size / 13
        Path { path in
            path.move(to: CGPoint(x: 1 * s, y: 1 * s))
            path.addLine(to: CGPoint(x: 12 * s, y: 12 * s))
            path.move(to: CGPoint(x: 12 * s, y: 1 * s))
            path.addLine(to: CGPoint(x: 1 * s, y: 12 * s))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
        .frame(width: 13 * s, height: 13 * s)
        .accessibilityHidden(true)
    }
}
