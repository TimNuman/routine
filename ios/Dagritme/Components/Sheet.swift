import SwiftUI

struct Sheet<Inner: View>: View {
    let title: String
    var alert: String = ""
    var button: String? = nil
    var busy: Bool = false
    let onCancel: () -> Void
    var onButton: (() -> Void)? = nil
    @ViewBuilder var content: () -> Inner

    @Environment(\.palette) private var palette
    @State private var shown = false
    @State private var contentHeight: CGFloat = 0
    @State private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { space in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.34)
                    .opacity(shown ? 1 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close(onCancel) }
                    .accessibilityIdentifier("sheet.backdrop")
                    .accessibilityLabel(Spoken.close)
                    .accessibilityAddTraits(.isButton)

                card(space.size.height)
                    .frame(maxWidth: 520)
                    .frame(maxHeight: space.size.height * 0.86, alignment: .bottom)
                    .frame(maxWidth: .infinity)
                    .offset(y: (shown ? 0 : space.size.height) + drag)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            Haptics.tap()
            withAnimation(Motion.sheetUp) { shown = true }
        }
    }

    private func card(_ height: CGFloat) -> some View {
        Glass(radius: 30, floating: true) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(INK.opacity(0.22))
                        .frame(width: 44, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .accessibilityHidden(true)

                    HStack {
                        TextButton(String(localized: "Annuleer"), id: "sheet.cancel") { close(onCancel) }
                        Spacer(minLength: 0)
                    }
                    .overlay {
                        Text(title).textStyle(Fonts.sheetHead)
                            .foregroundStyle(palette.ink).lineLimit(1)
                            .accessibilityIdentifier("sheet.title")
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(height))

                if !alert.isEmpty {
                    AlertBox(alert).padding(.top, 12)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { content() }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            GeometryReader { g in
                                Color.clear.preference(key: HeightKey.self, value: g.size.height)
                            }
                        }
                }
                .frame(maxHeight: max(1, contentHeight))
                .onPreferenceChange(HeightKey.self) { contentHeight = $0 }
                .padding(.top, 4)

                if let button {
                    Button { onButton?() } label: {
                        Text(button)
                            .textStyle(TextStyle(font: Fonts.balooHeavy(17)))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(ORANGE))
                    }
                    .buttonStyle(.press)
                    .accessibilityIdentifier("sheet.submit")
                    .accessibilityLabel(button)
                    .disabled(busy)
                    .opacity(busy ? 0.45 : 1)
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, SafeArea.bottom + 18)
        }
    }

    private func dragGesture(_ height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { g in drag = max(0, g.translation.height) }
            .onEnded { g in
                let far = g.predictedEndTranslation.height
                if g.translation.height > 120 || far > 300 {
                    withAnimation(Motion.sheetDown) { drag = height }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: onCancel)
                } else {
                    withAnimation(Motion.spring) { drag = 0 }
                }
            }
    }

    private func close(_ then: @escaping () -> Void) {
        withAnimation(Motion.sheetDown) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: then)
    }
}

struct FullSheet<Inner: View>: View {
    let title: String
    var alert: String = ""
    var busy: Bool = false
    var ownScroll: Bool = false
    let onCancel: () -> Void
    let onDone: () -> Void
    @ViewBuilder var content: () -> Inner

    @State private var headHeight: CGFloat = 92

    var body: some View {
        ZStack(alignment: .top) {
            Sky(dark: false)

            // De inhoud scrolt achter de kop langs...
            Group {
                if ownScroll {
                    VStack(alignment: .leading, spacing: 0) {
                        if !alert.isEmpty {
                            AlertBox(alert).padding(.horizontal, 22)
                        }
                        content()
                    }
                    .frame(maxWidth: 520 + 44)
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !alert.isEmpty { AlertBox(alert) }
                            content()
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 30)
                        .frame(maxWidth: 520 + 44)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .contentMargins(.top, headHeight + 16)

            // ...met bij de klok dezelfde zachte overloop als op de
            // gewone schermen; de kop zelf zweeft erboven, en zijn glas
            // vervaagt wat eronderdoor schuift.
            EdgeFade(dark: false)
                .frame(height: 72)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            Glass(radius: 26, floating: true) {
                HStack(spacing: 10) {
                    TextButton(String(localized: "Annuleer"), id: "full.cancel") { onCancel() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(title).textStyle(Fonts.sheetHead).foregroundStyle(INK)
                        .lineLimit(1)
                        .layoutPriority(1)
                        .accessibilityIdentifier("full.title")
                        .accessibilityAddTraits(.isHeader)
                    TextButton(busy ? String(localized: "Bezig…") : String(localized: "Gereed"), bold: true,
                               id: "full.done") { onDone() }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .frame(maxWidth: 496 + 44)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height },
                              action: { headHeight = $0 })
        }
        .environment(\.palette, Palette(dark: false))
    }
}

struct TextButton: View {
    let title: String
    var bold: Bool = false
    var id: String? = nil
    let onTap: () -> Void

    init(_ title: String, bold: Bool = false, id: String? = nil,
         onTap: @escaping () -> Void) {
        self.title = title
        self.bold = bold
        self.id = id
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .textStyle(bold ? TextStyle(font: Fonts.balooHeavy(16)) : Fonts.textButton)
                .foregroundStyle(ORANGE)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityIdentifier(id ?? "")
    }
}

struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
