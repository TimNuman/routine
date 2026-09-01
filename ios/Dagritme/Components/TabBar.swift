import SwiftUI

/// Dezelfde vorm als de ochtend/avond-schakelaar: glas, en een wit kussen dat
/// onder de gekozen knop door schuift — hier met de pictogrammen erbij.
struct TabBar: View {
    var wide: Bool

    static let edge: CGFloat = 10

    @Environment(Household.self) private var household
    @Environment(\.palette) private var palette

    private struct Item {
        let tab: Tab
        let name: String
        let shape: MenuShape.Kind
        let id: String
    }

    private let items: [Item] = [
        Item(tab: .routine, name: String(localized: "Ritme"), shape: .routine, id: "tab.routine"),
        Item(tab: .week, name: String(localized: "Deze week"), shape: .week, id: "tab.week"),
        Item(tab: .settings, name: String(localized: "Instellingen"), shape: .gear, id: "tab.settings"),
    ]

    private var row: CGFloat { wide ? 42 : 52 }
    /// Zo breed als een knop nodig heeft; de balk hangt dicht om de drie heen.
    private var width: CGFloat { wide ? 150 : 94 }

    var body: some View {
        let chosen = items.firstIndex { $0.tab == household.tab } ?? 0
        Glass(radius: (row + 8) / 2) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.dark ? Color.white.opacity(0.92) : .white)
                    .frame(width: width, height: row)
                    .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 3)
                    .offset(x: CGFloat(chosen) * width)
                    .animation(Motion.spring, value: household.tab)

                HStack(spacing: 0) {
                    ForEach(items, id: \.tab) { item in
                        option(item, on: household.tab == item.tab)
                    }
                }
            }
            .padding(4)
        }
        .fixedSize()
    }

    @ViewBuilder
    private func option(_ item: Item, on: Bool) -> some View {
        let color = on ? INK : palette.muted
        Button { household.go(item.tab) } label: {
            Group {
                if wide {
                    HStack(spacing: 7) {
                        MenuIcon(kind: item.shape, color: color, size: 19)
                        Text(item.name).textStyle(Fonts.tabWide)
                    }
                } else {
                    VStack(spacing: 3) {
                        MenuIcon(kind: item.shape, color: color, size: 22)
                        Text(item.name).textStyle(Fonts.tab)
                    }
                }
            }
            .foregroundStyle(color)
            .animation(Motion.short, value: on)
            .scaleEffect(on ? 1.04 : 1)
            .animation(Motion.spring, value: on)
            .frame(width: width, height: row)
            .contentShape(Capsule())
        }
        .buttonStyle(.press)
        .accessibilityIdentifier(item.id)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
