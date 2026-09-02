import SwiftUI

struct EmojiPicker: View {
    let title: String
    let current: String
    let onCancel: () -> Void
    let onDone: (String) -> Void

    @Environment(\.palette) private var palette
    @State private var value: String
    @State private var group: String
    @State private var tone: SkinTone

    init(title: String, current: String, onCancel: @escaping () -> Void,
         onDone: @escaping (String) -> Void) {
        self.title = title
        self.current = current
        self.onCancel = onCancel
        self.onDone = onDone
        let glyph = current.isEmpty ? "⭐" : current
        let bare = SkinTone.bare(glyph)
        _value = State(initialValue: glyph)
        _group = State(initialValue: EMOJI_GROUPS.first { $0.glyphs.contains(bare) }?.name
            ?? EMOJI_GROUPS[0].name)
        // De kleur die er al in zit wint; anders wat je de vorige keer koos.
        _tone = State(initialValue: SkinTone.supportsTone(bare) && SkinTone.of(glyph) != .none
            ? SkinTone.of(glyph) : SkinTone.remembered)
    }

    private var glyphs: [String] {
        (EMOJI_GROUPS.first { $0.name == group }?.glyphs ?? []).map { tone.apply(to: $0) }
    }

    private var hasFaces: Bool {
        (EMOJI_GROUPS.first { $0.name == group }?.glyphs ?? []).contains { SkinTone.supportsTone($0) }
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

            if hasFaces {
                HStack(spacing: 8) {
                    ForEach(SkinTone.allCases, id: \.rawValue) { option in
                        Button { pick(option) } label: {
                            Circle()
                                .fill(palette.tile)
                                .overlay(Circle().strokeBorder(
                                    option == tone ? ORANGE : palette.tileEdge,
                                    lineWidth: option == tone ? 2.5 : 1))
                                .overlay(Text(option.sample).font(.system(size: 20)))
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.smallPress)
                        .accessibilityLabel(option.sample)
                    }
                    Spacer(minLength: 0)
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

    /// Een andere kleur kleurt de hele rij, en wat er al gekozen was mee.
    private func pick(_ option: SkinTone) {
        tone = option
        SkinTone.remembered = option
        if SkinTone.supportsTone(SkinTone.bare(value)) { value = option.apply(to: value) }
    }
}
