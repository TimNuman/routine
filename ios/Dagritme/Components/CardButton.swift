import SwiftUI

struct CardButton: View {
    var glyph: String? = nil
    var plus: Bool = false
    let title: String
    let onTap: () -> Void

    @Environment(\.palette) private var palette

    init(_ title: String, glyph: String? = nil, plus: Bool = false,
         onTap: @escaping () -> Void) {
        self.title = title
        self.glyph = glyph
        self.plus = plus
        self.onTap = onTap
    }

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            Glass(radius: 22) {
                HStack(spacing: 10) {
                    if plus {
                        Bullet()
                    } else {
                        Text(glyph ?? "")
                            .font(.system(size: 20))
                            .frame(width: 28)
                    }
                    Text(title)
                        .textStyle(Fonts.cardButton)
                        .foregroundStyle(palette.muted)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.press)
        .padding(.top, 14)
    }
}

struct Bullet: View {
    var glyph: String = "+"
    var color: Color = GREEN

    var body: some View {
        ZStack {
            Circle().fill(color)
            Text(glyph)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }
}
