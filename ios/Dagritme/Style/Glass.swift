import SwiftUI

struct Glass<Inner: View>: View {
    var radius: CGFloat = 22
    var bottomRadius: CGFloat? = nil
    var floating: Bool = false
    /// Hoe dik de rand is. Een haarlijn hoort bij een kaartje van een paar
    /// centimeter; op een grote kaart oogt hij dun en scherp, en daar mag de
    /// rand dus mee groeien — het verloop erin wordt dan een bolle rand.
    var line: CGFloat = 1
    /// Hoeveel de schaduw meegroeit met de kaart.
    var lift: CGFloat = 1
    /// Hoe bol het glas staat: een lichtrand net binnen de bovenkant en een
    /// schaduwtje binnen de onderkant, zodat de kaart dikte krijgt in plaats
    /// van een velletje met een randje eromheen te zijn. 0 is vlak.
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

    private var shell: some View {
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
}
