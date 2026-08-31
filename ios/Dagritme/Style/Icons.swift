import SwiftUI

struct MenuShape: Shape {
    enum Kind { case routine, week, gear }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()

        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            path.move(to: CGPoint(x: x1 * s, y: y1 * s))
            path.addLine(to: CGPoint(x: x2 * s, y: y2 * s))
        }

        switch kind {
        case .routine:
            for y in [6.0, 12.0, 18.0] as [CGFloat] {
                line(4, y, 6.5, y)
                line(10.5, y, 20, y)
            }
        case .week:
            path.addRoundedRect(
                in: CGRect(x: 3.5 * s, y: 5 * s, width: 17 * s, height: 15.5 * s),
                cornerSize: CGSize(width: 4 * s, height: 4 * s),
                style: .continuous
            )
            line(3.5, 10, 20.5, 10)
            line(8.5, 3.2, 8.5, 6.6)
            line(15.5, 3.2, 15.5, 6.6)
        case .gear:
            path.addEllipse(in: CGRect(x: 8.8 * s, y: 8.8 * s, width: 6.4 * s, height: 6.4 * s))
            line(12, 3.2, 12, 5.4)
            line(12, 18.6, 12, 20.8)
            line(20.8, 12, 18.6, 12)
            line(5.4, 12, 3.2, 12)
            line(17.3, 6.7, 15.8, 8.2)
            line(8.2, 15.8, 6.7, 17.3)
            line(17.3, 17.3, 15.8, 15.8)
            line(8.2, 8.2, 6.7, 6.7)
        }
        return path
    }
}

struct MenuIcon: View {
    let kind: MenuShape.Kind
    var color: Color
    var size: CGFloat

    var body: some View {
        MenuShape(kind: kind)
            .stroke(color, style: StrokeStyle(lineWidth: size / 24 * 1.9,
                                              lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

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
    }
}
