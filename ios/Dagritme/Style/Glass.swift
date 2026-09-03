import SwiftUI

/// Het glas van de app.
///
/// Op iOS 26 en nieuwer is dit Apples eigen **Liquid Glass**: `.glassEffect`
/// zet het echte materiaal neer, dat wat eronder langs schuift buigt en
/// weerkaatst, zijn randen zelf oplicht en zijn contrast zelf bijstelt.
///
/// Daaronder — en in een Xcode die dat materiaal nog niet kent — blijft de
/// nagebouwde versie staan: een blur met een kleur eroverheen en een randje
/// met een verloop erin. Dat is wat deze app altijd had; het lijkt erop, maar
/// het buigt niets.
///
/// SwiftUI heeft zelf ook een type dat `Glass` heet (de soort glas: `.regular`,
/// `.clear`). Binnen deze app wint deze; het echte materiaal vragen we aan met
/// `.glassEffect(in:)`, dus die twee zitten elkaar niet in de weg.
struct Glass<Inner: View>: View {
    var radius: CGFloat = 22
    var bottomRadius: CGFloat? = nil
    var floating: Bool = false
    /// Hoe dik de rand is. Een haarlijn hoort bij een kaartje van een paar
    /// centimeter; op een grote kaart oogt hij dun en scherp, en daar mag de
    /// rand dus mee groeien — het verloop erin wordt dan een bolle rand.
    /// Alleen voor de nagebouwde versie: het echte materiaal doet zijn randen
    /// zelf.
    var line: CGFloat = 1
    /// Hoeveel de schaduw meegroeit met de kaart.
    var lift: CGFloat = 1
    /// Hoe bol het glas staat: een lichtrand net binnen de bovenkant en een
    /// schaduwtje binnen de onderkant, zodat de kaart dikte krijgt in plaats
    /// van een velletje met een randje eromheen te zijn. 0 is vlak. Ook dit
    /// is alleen voor de nagebouwde versie.
    var bulge: CGFloat = 0
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
            shell.shadow(color: palette.shadow, radius: 19 * lift, x: 0, y: 16 * lift)
        } else {
            shell
        }
    }

    @ViewBuilder
    private var shell: some View {
        // `compiler(>=6.2)` is Xcode 26: alleen die kent het materiaal, en
        // zonder deze vraag zou de app niet meer bouwen in een oudere.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content().glassEffect(in: shape)
        } else {
            handmade
        }
        #else
        handmade
        #endif
    }

    /// Het nagebouwde glas, voor alles vóór iOS 26.
    private var handmade: some View {
        content()
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(pane)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: palette.sheenTop, location: 0),
                            .init(color: palette.glassEdge, location: 0.35),
                            .init(color: palette.glassEdge, location: 0.72),
                            .init(color: palette.sheenBottom, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: line
                )
            }
    }

    /// De kleur van het glas, met de bolling erin als daarom gevraagd is.
    private var pane: AnyShapeStyle {
        let base = floating ? palette.glassFloating : palette.glass
        guard bulge > 0 else { return AnyShapeStyle(base) }
        return AnyShapeStyle(
            base
                .shadow(.inner(color: palette.sheenTop, radius: bulge, x: 0, y: bulge * 0.8))
                .shadow(.inner(color: palette.shadow, radius: bulge * 1.3, x: 0,
                               y: -bulge * 0.6))
        )
    }
}
