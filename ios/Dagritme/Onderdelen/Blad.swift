// De twee soorten schermen die eroverheen komen: een blad dat vanaf de onderkant
// omhoog komt (het formulier, de assistent) en een vel dat het hele scherm vult
// (de bewerkschermen onder Instellingen).
//
// Het blad is met opzet geen `.sheet`: het is glas met een eigen randje, er komen
// er drie over elkaar heen (blad → formulier → emojikiezer), en dan is een eigen
// laag in de ZStack rustiger dan een stapel systeembladen.
import SwiftUI

struct Blad<Inhoudje: View>: View {
    let titel: String
    var melding: String = ""
    var knop: String? = nil
    var bezig: Bool = false
    let opAf: () -> Void
    var opKnop: (() -> Void)? = nil
    @ViewBuilder var inhoud: () -> Inhoudje

    @Environment(\.palet) private var palet
    @State private var zichtbaar = false
    @State private var inhoudHoogte: CGFloat = 0

    var body: some View {
        GeometryReader { ruimte in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.34)
                    .opacity(zichtbaar ? 1 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { sluit(opAf) }
                    .accessibilityLabel("Sluiten")

                kaart
                    .frame(maxWidth: 520)
                    .frame(maxHeight: ruimte.size.height * 0.86, alignment: .bottom)
                    .frame(maxWidth: .infinity)
                    .offset(y: zichtbaar ? 0 : ruimte.size.height)
            }
        }
        // Alleen de rand van het toestel negeren, niet die van het toetsenbord:
        // anders schuift het blad niet omhoog als er getypt wordt.
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear { withAnimation(.easeOut(duration: 0.22)) { zichtbaar = true } }
    }

    private var kaart: some View {
        Glas(radius: 30, zwevend: true) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(INKT.opacity(0.22))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                HStack(spacing: 10) {
                    Tekstknop("Annuleer") { sluit(opAf) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(titel).letter(L.bladkop).foregroundStyle(palet.inkt).lineLimit(1)
                    Color.clear.frame(maxWidth: .infinity)
                }

                if !melding.isEmpty {
                    Melding(melding).padding(.top, 12)
                }

                // De rol groeit mee met wat erin staat en houdt daar op; wat er
                // niet meer bij kan schuift. Zonder die maat rekt een ScrollView
                // zich altijd tot het plafond op, ook onder drie regels tekst.
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { inhoud() }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            GeometryReader { g in
                                Color.clear.preference(key: HoogteSleutel.self, value: g.size.height)
                            }
                        }
                }
                .frame(maxHeight: max(1, inhoudHoogte))
                .onPreferenceChange(HoogteSleutel.self) { inhoudHoogte = $0 }
                .padding(.top, 4)

                if let knop {
                    Button { opKnop?() } label: {
                        Text(knop)
                            .letter(Letter(font: L.balooZwaar(17)))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(ORANJE))
                    }
                    .buttonStyle(.plain)
                    .disabled(bezig)
                    .opacity(bezig ? 0.45 : 1)
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, Randen.onder + 18)
        }
    }

    private func sluit(_ daarna: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.16)) { zichtbaar = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: daarna)
    }
}

// Het hele scherm, voor de bewerkschermen onder Instellingen. Die worden met
// .fullScreenCover getoond, dus hier zit alleen wat erin staat.
struct Vel<Inhoudje: View>: View {
    let titel: String
    var melding: String = ""
    var bezig: Bool = false
    let opAf: () -> Void
    let opGereed: () -> Void
    @ViewBuilder var inhoud: () -> Inhoudje

    var body: some View {
        ZStack {
            // De bewerkschermen staan altijd in het licht: ze horen bij
            // Instellingen, en daar wordt het nooit avond.
            Lucht(donker: false)

            VStack(spacing: 0) {
                Glas(radius: 28, zwevend: true) {
                    HStack(spacing: 10) {
                        Tekstknop("Annuleer") { opAf() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(titel).letter(L.bladkop).foregroundStyle(INKT).lineLimit(1)
                        Tekstknop(bezig ? "Bezig…" : "Gereed", dik: true) { opGereed() }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: 496 + 44)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !melding.isEmpty { Melding(melding) }
                        inhoud()
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 520 + 44)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.palet, Palet(donker: false))
    }
}

struct Tekstknop: View {
    let opschrift: String
    var dik: Bool = false
    let opTik: () -> Void

    init(_ opschrift: String, dik: Bool = false, opTik: @escaping () -> Void) {
        self.opschrift = opschrift
        self.dik = dik
        self.opTik = opTik
    }

    var body: some View {
        Button(action: opTik) {
            Text(opschrift)
                .letter(dik ? Letter(font: L.balooZwaar(16)) : L.tekstknop)
                .foregroundStyle(ORANJE)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Hoe hoog wat er in een blad staat is; zie de rol hierboven.
struct HoogteSleutel: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
