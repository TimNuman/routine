import SwiftUI

struct TraitPair: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}

struct ChildData {
    var id: String
    var name: String
    var emoji: String
    var color: String
    var pairs: [TraitPair]

    init(id: String, name: String, emoji: String, color: String, traits: [String: String]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.pairs = traits.sorted { $0.key < $1.key }
            .map { TraitPair(key: $0.key, value: $0.value) }
    }

    var traits: [String: String] {
        var out: [String: String] = [:]
        for pair in pairs {
            let key = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty && !value.isEmpty { out[key] = value }
        }
        return out
    }
}

struct ChildSheet: View {
    let title: String
    let onCancel: () -> Void
    let onSave: (ChildData) -> Void

    @State private var child: ChildData
    @State private var picker = false

    init(title: String, child: ChildData, onCancel: @escaping () -> Void,
         onSave: @escaping (ChildData) -> Void) {
        self.title = title
        self.onCancel = onCancel
        self.onSave = onSave
        _child = State(initialValue: child)
    }

    var body: some View {
        ZStack {
            Sheet(title: title, button: String(localized: "Bewaar"), onCancel: onCancel,
                  onButton: { onSave(child) }) {
                FormHead(String(localized: "Gezicht en naam"), first: true)
                HStack(spacing: 10) {
                    EmojiButton(value: child.emoji, size: 52) { picker = true }
                    Field(value: $child.name, placeholder: String(localized: "Naam"), id: "child.name")
                }

                FormHead(String(localized: "Kleur"))
                Chips {
                    ForEach(COLORS, id: \.self) { color in
                        Button { child.color = color } label: {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color(hex: color))
                                .frame(minHeight: 34)
                                .frame(maxWidth: .infinity)
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(INK, lineWidth: child.color == color ? 2.5 : 0))
                        }
                        .buttonStyle(.press)
                        .frame(width: 64, height: 34)
                        .accessibilityLabel(Spoken.color)
                    }
                }

                FormHead(String(localized: "Wat we verder weten"))
                EditCard {
                    ForEach(Array(child.pairs.enumerated()), id: \.element.id) { (i, _) in
                        if i > 0 { HairLine() }
                        SwipeAway(title: String(localized: "Weg"), onDelete: { child.pairs.remove(at: i) }) {
                            HStack(spacing: 10) {
                                Field(value: $child.pairs[i].key, placeholder: String(localized: "waarvan"))
                                Field(value: $child.pairs[i].value, placeholder: String(localized: "welke"))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 58)
                        }
                    }
                    AddRow(String(localized: "Kenmerk toevoegen")) { child.pairs.append(TraitPair()) }
                }
            }

            if picker {
                EmojiPicker(title: String(localized: "Kies een gezicht"), current: child.emoji,
                            onCancel: { picker = false },
                            onDone: { glyph in child.emoji = glyph; picker = false })
            }
        }
    }
}
