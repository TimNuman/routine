import SwiftUI

/// Een kaartje van papier.
///
/// Het glas van de app is voor wat bij het scherm hoort: de balken, de
/// knoppen, de randen. Een kaart is iets anders — dat is het ding zelf, dat
/// je oppakt, omdraait en weglegt. Daar hoort geen doorkijk bij: je leest wat
/// erop staat, niet wat eronder ligt. En een stapel van doorzichtige kaarten
/// wordt één wolk in plaats van een stapel.
///
/// Dus: een vlak in de kleur van papier, een haarlijn eromheen en een schaduw
/// eronder die meegroeit als de kaart opgetild wordt.
struct Paper<Inner: View>: View {
    var radius: CGFloat = 22
    /// Zweeft hij boven de rest? Dan valt er een diepere schaduw onder.
    var floating: Bool = false
    /// Hoeveel die schaduw meegroeit met de kaart.
    var lift: CGFloat = 1
    @ViewBuilder var content: () -> Inner

    @Environment(\.palette) private var palette

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        content()
            .background { shape.fill(palette.paper) }
            .overlay { shape.strokeBorder(palette.paperEdge, lineWidth: 1) }
            .clipShape(shape)
            .shadow(color: palette.shadow,
                    radius: floating ? 19 * lift : 8,
                    x: 0,
                    y: floating ? 16 * lift : 5)
    }
}
