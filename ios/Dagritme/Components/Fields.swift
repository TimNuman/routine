import SwiftUI

struct FormHead: View {
    let text: String
    var first: Bool = false

    @Environment(\.palette) private var palette

    init(_ text: String, first: Bool = false) {
        self.text = text
        self.first = first
    }

    var body: some View {
        Text(text.uppercased())
            .textStyle(Fonts.formHead)
            .foregroundStyle(palette.muted)
            .padding(.top, first ? 8 : 16)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Note: View {
    let text: String
    @Environment(\.palette) private var palette

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(Fonts.note)
            .foregroundStyle(palette.muted)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AlertBox: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(Fonts.alert)
            .foregroundStyle(Color(hex: "#B0272C"))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RED.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(RED.opacity(0.32), lineWidth: 1))
            .padding(.bottom, 14)
    }
}

enum FieldKind {
    case text
    case time
    case number
}

struct Field: View {
    @Binding var value: String
    var placeholder: String = ""
    var kind: FieldKind = .text

    @Environment(\.palette) private var palette

    var body: some View {
        TextField("", text: $value, prompt: Text(placeholder)
            .foregroundColor(SOFT_INK.opacity(0.7)))
            .textStyle(kind == .text ? TextStyle(font: Fonts.baloo(16))
                                     : TextStyle(font: Fonts.nunitoHeavy(13)))
            .multilineTextAlignment(kind == .text ? .leading : .center)
            .keyboardType(kind == .number ? .numberPad : .default)
            .foregroundStyle(palette.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, kind == .time ? 6 : 12)
            .frame(width: width)
            .frame(maxWidth: maxWidth)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(palette.field))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(palette.fieldEdge, lineWidth: 1))
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(kind != .text)
    }

    private var width: CGFloat? {
        switch kind {
        case .text: return nil
        case .time: return 126
        case .number: return 84
        }
    }

    private var maxWidth: CGFloat? {
        guard kind == .text else { return nil }
        return CGFloat.infinity
    }
}

struct Chips<Inner: View>: View {
    var equal: Bool = false
    @ViewBuilder var content: () -> Inner

    var body: some View {
        Glass(radius: 22) {
            Group {
                if equal {
                    HStack(spacing: 6) { content() }
                } else {
                    Flow(gap: 6, rowGap: 6) { content() }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct Chip: View {
    let label: String
    let on: Bool
    var color: Color? = nil
    var quiet: Bool = false
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .textStyle(Fonts.chip)
                .lineLimit(1)
                .foregroundStyle(textColor)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(edge, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private var fill: Color {
        guard on else { return palette.chip }
        if quiet { return INK.opacity(0.14) }
        return color ?? ORANGE
    }

    private var edge: Color {
        guard on else { return palette.chipEdge }
        if quiet { return .clear }
        return color ?? ORANGE
    }

    private var textColor: Color {
        guard on else { return palette.muted }
        return quiet ? palette.ink : .white
    }
}

struct EmojiButton: View {
    let value: String
    var size: CGFloat = 42
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: size / 2.9, style: .continuous)
                .fill(palette.tile)
                .overlay(RoundedRectangle(cornerRadius: size / 2.9, style: .continuous)
                    .strokeBorder(palette.tileEdge, lineWidth: 1))
                .overlay(Text(value).font(.system(size: size * 0.53)))
                .frame(width: size, height: size)
        }
        .buttonStyle(.press)
        .accessibilityLabel("Icoon")
    }
}

struct EditCard<Inner: View>: View {
    @ViewBuilder var content: () -> Inner

    var body: some View {
        Glass(radius: 26) {
            VStack(spacing: 0) { content() }
        }
        .padding(.top, 18)
    }
}

struct HairLine: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle().fill(palette.line).frame(height: 1)
    }
}

struct AddRow: View {
    let title: String
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    init(_ title: String, onTap: @escaping () -> Void) {
        self.title = title
        self.onTap = onTap
    }

    var body: some View {
        VStack(spacing: 0) {
            HairLine()
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Bullet()
                    Text(title).textStyle(Fonts.add).foregroundStyle(palette.muted)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
        }
    }
}

struct EditRow: View {
    let icon: String
    let label: String
    let empty: String
    var time: String = ""
    var days: String = ""
    var extra: String = ""
    var who: [Person] = []
    var color: String = ""
    var twoLines: Bool = false
    let onOpen: () -> Void

    @Environment(\.palette) private var palette

    private var meta: [String] { [time, days, extra].filter { !$0.isEmpty } }
    private var hasMeta: Bool { !meta.isEmpty || !who.isEmpty }

    var body: some View {
        Button(action: onOpen) {
            if twoLines {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 10) { iconAndName }
                    if hasMeta { metaLine.padding(.leading, 52) }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            } else {
                HStack(spacing: 10) {
                    iconAndName
                    if hasMeta { metaLine }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.press)
        .padding(.vertical, 8)
        .frame(minHeight: 58)
    }

    @ViewBuilder
    private var iconAndName: some View {
        EmojiButton(value: icon, onTap: onOpen)
        Text(label.isEmpty ? empty : label)
            .textStyle(Fonts.rowLabel)
            .foregroundStyle(label.isEmpty ? palette.muted : palette.ink)
            .lineLimit(1)
        if !color.isEmpty {
            Circle().fill(Color(hex: color)).frame(width: 16, height: 16)
        }
        Spacer(minLength: 0)
    }

    @ViewBuilder
    private var metaLine: some View {
        HStack(spacing: 8) {
            ForEach(meta, id: \.self) { t in
                Text(t).textStyle(Fonts.rowMeta).foregroundStyle(palette.muted).lineLimit(1)
            }
            if !who.isEmpty { Faces(people: who, size: 24) }
        }
    }
}
