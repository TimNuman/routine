import SwiftUI

struct Glass<Inner: View>: View {
    var radius: CGFloat = 22
    var bottomRadius: CGFloat? = nil
    var floating: Bool = false
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
            shell.shadow(color: palette.shadow, radius: 19, x: 0, y: 16)
        } else {
            shell
        }
    }

    private var shell: some View {
        content()
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(floating ? palette.glassFloating : palette.glass)
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
                    lineWidth: 1
                )
            }
    }
}
