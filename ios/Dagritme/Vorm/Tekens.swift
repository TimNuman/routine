// De paar tekeningetjes die de app zelf tekent: de drie menu-iconen en het
// pijltje. Dezelfde lijnen en dikte als de svg's in de webversie — SF Symbols
// zouden hier net iets anders staan dan op web, en dat zie je meteen.
import SwiftUI

struct Menuteken: Shape {
    enum Soort { case ritme, week, tandwiel }
    let soort: Soort

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var pad = Path()

        func lijn(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            pad.move(to: CGPoint(x: x1 * s, y: y1 * s))
            pad.addLine(to: CGPoint(x: x2 * s, y: y2 * s))
        }

        switch soort {
        case .ritme:
            for y in [6.0, 12.0, 18.0] as [CGFloat] {
                lijn(4, y, 6.5, y)
                lijn(10.5, y, 20, y)
            }
        case .week:
            pad.addRoundedRect(
                in: CGRect(x: 3.5 * s, y: 5 * s, width: 17 * s, height: 15.5 * s),
                cornerSize: CGSize(width: 4 * s, height: 4 * s),
                style: .continuous
            )
            lijn(3.5, 10, 20.5, 10)
            lijn(8.5, 3.2, 8.5, 6.6)
            lijn(15.5, 3.2, 15.5, 6.6)
        case .tandwiel:
            pad.addEllipse(in: CGRect(x: 8.8 * s, y: 8.8 * s, width: 6.4 * s, height: 6.4 * s))
            lijn(12, 3.2, 12, 5.4)
            lijn(12, 18.6, 12, 20.8)
            lijn(20.8, 12, 18.6, 12)
            lijn(5.4, 12, 3.2, 12)
            lijn(17.3, 6.7, 15.8, 8.2)
            lijn(8.2, 15.8, 6.7, 17.3)
            lijn(17.3, 17.3, 15.8, 15.8)
            lijn(8.2, 8.2, 6.7, 6.7)
        }
        return pad
    }
}

struct Menuicoon: View {
    let soort: Menuteken.Soort
    var kleur: Color
    var maat: CGFloat

    var body: some View {
        Menuteken(soort: soort)
            .stroke(kleur, style: StrokeStyle(lineWidth: maat / 24 * 1.9,
                                              lineCap: .round, lineJoin: .round))
            .frame(width: maat, height: maat)
    }
}

// Het pijltje rechts van een regel, en de pijlen naast de weekstrip.
struct Pijltje: View {
    var kleur: Color = ZACHTINKT
    var hoogte: CGFloat = 15

    var body: some View {
        let s = hoogte / 15
        Path { pad in
            pad.move(to: CGPoint(x: 1.5 * s, y: 1.5 * s))
            pad.addLine(to: CGPoint(x: 7 * s, y: 7.5 * s))
            pad.addLine(to: CGPoint(x: 1.5 * s, y: 13.5 * s))
        }
        .stroke(kleur, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round, lineJoin: .round))
        .frame(width: 9 * s, height: hoogte)
    }
}
