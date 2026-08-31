import SwiftUI

struct TabBar: View {
    var wide: Bool

    static let edge: CGFloat = 8
    private static let deviceCorner: CGFloat = 55

    @Environment(Household.self) private var household
    @Environment(\.palette) private var palette
    @Namespace private var space

    private struct Item {
        let tab: Tab
        let name: String
        let shape: MenuShape.Kind
    }

    private let items: [Item] = [
        Item(tab: .routine, name: "Ritme", shape: .routine),
        Item(tab: .week, name: "Deze week", shape: .week),
        Item(tab: .settings, name: "Instellingen", shape: .gear),
    ]

    var body: some View {
        Glass(radius: wide ? 26 : 30,
              bottomRadius: wide ? 26 : Self.deviceCorner - Self.edge,
              floating: true) {
            HStack(spacing: 4) {
                ForEach(items, id: \.tab) { item in
                    let on = household.tab == item.tab
                    Button { household.go(item.tab) } label: {
                        label(item, on: on)
                    }
                    .buttonStyle(.press(0.94))
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(wide ? 4 : 5)
            .padding(.bottom, wide ? 0 : max(0, SafeArea.bottom - Self.edge - 5))
        }
    }

    @ViewBuilder
    private func label(_ item: Item, on: Bool) -> some View {
        let color = on ? ORANGE : palette.idleTab
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Group {
            if wide {
                HStack(spacing: 7) {
                    MenuIcon(kind: item.shape, color: color, size: 19)
                    Text(item.name).textStyle(Fonts.tabWide)
                }
            } else {
                VStack(spacing: 2) {
                    MenuIcon(kind: item.shape, color: color, size: 23)
                    Text(item.name).textStyle(Fonts.tab)
                }
            }
        }
        .foregroundStyle(color)
        .scaleEffect(on ? 1.06 : 1)
        .animation(Motion.pop, value: on)
        .frame(maxWidth: .infinity)
        .padding(.vertical, wide ? 8 : 7)
        .background {
            if on {
                shape.fill(ORANGE.opacity(0.16))
                    .overlay(shape.strokeBorder(ORANGE.opacity(0.28), lineWidth: 1))
                    .matchedGeometryEffect(id: "pil", in: space)
            }
        }
        .contentShape(shape)
    }
}
