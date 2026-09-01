import SwiftUI

struct CardList<Inner: View>: View {
    @ViewBuilder var content: () -> Inner

    var body: some View {
        Glass(radius: 26) {
            VStack(spacing: 0) { content() }
        }
        .padding(.top, 16)
    }
}

struct CardRow: View {
    let icon: String
    let title: String
    let note: String
    var first: Bool = false
    var faces: [Person] = []
    var id: String? = nil
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            if !first { Rectangle().fill(palette.line).frame(height: 1) }
            Button(action: onTap) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palette.tile)
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(palette.tileEdge, lineWidth: 1))
                        .overlay(Text(icon).font(.system(size: 22)))
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).textStyle(Fonts.listTitle).foregroundStyle(palette.ink).lineLimit(1)
                        Text(note).textStyle(Fonts.listNote).foregroundStyle(palette.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if !faces.isEmpty { Faces(people: faces).accessibilityHidden(true) }
                    // Evenveel lucht rechts van het pijltje als links van het icoon.
                    Chevron().opacity(0.6).padding(.trailing, 6)
                }
                .padding(14)
                .frame(minHeight: 62)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(id ?? "")
        }
    }
}

struct Faces: View {
    let people: [Person]
    var size: CGFloat = 34

    var body: some View {
        HStack(spacing: -8) {
            ForEach(people.prefix(4)) { p in
                ZStack {
                    Circle().fill(soft(p.color, 0.18))
                    Text(p.emoji).font(.system(size: size * 0.56))
                }
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
            }
        }
    }
}
