import SwiftUI

struct EmojiPicker: View {
    let title: String
    let current: String
    let onCancel: () -> Void
    let onDone: (String) -> Void

    @Environment(\.palette) private var palette
    @State private var value: String
    @State private var group: String

    init(title: String, current: String, onCancel: @escaping () -> Void,
         onDone: @escaping (String) -> Void) {
        self.title = title
        self.current = current
        self.onCancel = onCancel
        self.onDone = onDone
        let glyph = current.isEmpty ? "⭐" : current
        _value = State(initialValue: glyph)
        _group = State(initialValue: EMOJI_GROUPS.first { $0.glyphs.contains(glyph) }?.name
            ?? EMOJI_GROUPS[0].name)
    }

    private var glyphs: [String] {
        EMOJI_GROUPS.first { $0.name == group }?.glyphs ?? []
    }

    var body: some View {
        Sheet(title: title, button: String(localized: "Gereed"), onCancel: onCancel,
              onButton: { onDone(value) }) {
            RoundedRectangle(cornerRadius: 39, style: .continuous)
                .fill(palette.tile)
                .overlay(RoundedRectangle(cornerRadius: 39, style: .continuous)
                    .strokeBorder(palette.tileEdge, lineWidth: 1))
                .overlay(Text(value).font(.system(size: 40)))
                .frame(width: 78, height: 78)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EMOJI_GROUPS, id: \.name) { g in
                        Chip(label: g.name, on: g.name == group) { group = g.name }
                            .fixedSize()
                    }
                }
                .padding(.bottom, 12)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(glyphs.enumerated()), id: \.offset) { (_, glyph) in
                    Button { value = glyph } label: {
                        Circle()
                            .fill(palette.tile)
                            .overlay(Circle().strokeBorder(
                                glyph == value ? ORANGE : palette.tileEdge,
                                lineWidth: glyph == value ? 2.5 : 1))
                            .overlay(Text(glyph).font(.system(size: 25)))
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.smallPress)
                    .accessibilityLabel(glyph)
                }
            }
        }
    }
}
