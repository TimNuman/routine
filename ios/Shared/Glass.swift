import SwiftUI

/// Het glas van de app: Apples **Liquid Glass**, in de vorm die erbij hoort.
///
/// `.glassEffect` zet het echte materiaal neer — het buigt en weerkaatst wat
/// eronder langs schuift, licht zijn eigen randen op en stelt zijn contrast
/// zelf bij. Er is hier dus niets meer na te bouwen: geen blur met een kleur
/// eroverheen, geen randje met een verloop erin. Dat is precies waarom de app
/// iOS 26 vraagt.
///
/// SwiftUI heeft zelf ook een type dat `Glass` heet (de soort glas: `.regular`,
/// `.clear`). Binnen deze app wint deze; het materiaal vragen we aan met
/// `.glassEffect(in:)`, dus die twee zitten elkaar niet in de weg.
struct Glass<Inner: View>: View {
    var radius: CGFloat = 22
    var bottomRadius: CGFloat? = nil
    /// Zweeft het boven de rest? Dan valt er een schaduw onder.
    var floating: Bool = false
    /// Hoeveel die schaduw meegroeit met de kaart.
    var lift: CGFloat = 1
    /// Een dikke glazen rand over het materiaal heen: een lichtstreep die
    /// bovenaan begint, in het midden wegvalt en onderaan terugkomt, zoals
    /// het licht op de rand van een dik stuk glas. 0 laat het materiaal zijn
    /// eigen dunne randje doen, en dat is overal goed genoeg behalve op een
    /// kaart die het halve scherm vult.
    var rim: CGFloat = 0
    @ViewBuilder var content: () -> Inner

    @Environment(\.palette) private var palette

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: bottomRadius ?? radius,
            bottomTrailingRadius: bottomRadius ?? radius,
            topTrailingRadius: radius,
            style: .continuous
        )
    }

    @ViewBuilder
    var body: some View {
        if floating {
            pane.shadow(color: palette.shadow, radius: 19 * lift, x: 0, y: 16 * lift)
        } else {
            pane
        }
    }

    private var pane: some View {
        content()
            .glassEffect(in: shape)
            .overlay { edge }
    }

    @ViewBuilder
    private var edge: some View {
        if rim > 0 {
            let dark = palette.dark
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(dark ? 0.55 : 0.92), location: 0),
                        .init(color: .white.opacity(dark ? 0.10 : 0.24), location: 0.4),
                        .init(color: .white.opacity(dark ? 0.06 : 0.16), location: 0.62),
                        .init(color: .white.opacity(dark ? 0.34 : 0.66), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: rim
            )
            // De binnenkant van die dikke rand, waar het licht weer opvangt.
            .overlay {
                shape.inset(by: rim)
                    .strokeBorder(.white.opacity(dark ? 0.12 : 0.3), lineWidth: 1)
            }
        }
    }
}
