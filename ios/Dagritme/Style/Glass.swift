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
        content().glassEffect(in: shape)
    }
}
