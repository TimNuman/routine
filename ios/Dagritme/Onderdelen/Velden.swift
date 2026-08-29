// De onderdelen waar de bewerkschermen uit bestaan: een invoerveld, chips om te
// kiezen, kopjes, notities en de regels in een bewerkkaart.
import SwiftUI

struct Formkop: View {
    let tekst: String
    var eerste: Bool = false

    @Environment(\.palet) private var palet

    init(_ tekst: String, eerste: Bool = false) {
        self.tekst = tekst
        self.eerste = eerste
    }

    var body: some View {
        Text(tekst.uppercased())
            .letter(L.formkop)
            .foregroundStyle(palet.zacht)
            .padding(.top, eerste ? 8 : 16)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Notitie: View {
    let tekst: String
    @Environment(\.palet) private var palet

    init(_ tekst: String) { self.tekst = tekst }

    var body: some View {
        Text(tekst)
            .letter(L.notitie)
            .foregroundStyle(palet.zacht)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Melding: View {
    let tekst: String

    init(_ tekst: String) { self.tekst = tekst }

    var body: some View {
        Text(tekst)
            .letter(L.melding)
            .foregroundStyle(Color(hex: "#B0272C"))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ROOD.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ROOD.opacity(0.32), lineWidth: 1))
            .padding(.bottom, 14)
    }
}

enum Veldsoort {
    case tekst
    case tijd
    case getal
}

struct Veld: View {
    @Binding var waarde: String
    var plaatshouder: String = ""
    var soort: Veldsoort = .tekst

    @Environment(\.palet) private var palet

    var body: some View {
        TextField("", text: $waarde, prompt: Text(plaatshouder)
            .foregroundColor(ZACHTINKT.opacity(0.7)))
            .letter(soort == .tekst ? Letter(font: L.baloo(16)) : Letter(font: L.nunitoZwaar(13)))
            .multilineTextAlignment(soort == .tekst ? .leading : .center)
            .keyboardType(soort == .getal ? .numberPad : .default)
            .foregroundStyle(palet.inkt)
            .padding(.vertical, 9)
            .padding(.horizontal, soort == .tijd ? 6 : 12)
            .frame(width: breedte)
            .frame(maxWidth: maxBreedte)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(palet.veld))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(palet.veldRand, lineWidth: 1))
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(soort != .tekst)
    }

    // Een tijd en een getal staan vast; de rest neemt wat er over is.
    private var breedte: CGFloat? {
        switch soort {
        case .tekst: return nil
        case .tijd: return 126
        case .getal: return 84
        }
    }

    private var maxBreedte: CGFloat? {
        guard soort == .tekst else { return nil }
        return CGFloat.infinity
    }
}

struct Chips<Inhoudje: View>: View {
    // Dagletters willen even breed zijn; de rest schikt zich vloeiend.
    var gelijk: Bool = false
    @ViewBuilder var inhoud: () -> Inhoudje

    var body: some View {
        Glas(radius: 22) {
            Group {
                if gelijk {
                    HStack(spacing: 6) { inhoud() }
                } else {
                    Vloeiend(gat: 6, rijgat: 6) { inhoud() }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// 'stil' is voor een antwoord dat geen keuze is om naar toe te trekken, zoals
// 'geen van deze': wel gekozen, maar niet oranje.
struct Chip: View {
    let label: String
    let aan: Bool
    var kleur: Color? = nil
    var stil: Bool = false
    let opTik: () -> Void

    @Environment(\.palet) private var palet

    var body: some View {
        Button(action: opTik) {
            Text(label)
                .letter(L.chip)
                .lineLimit(1)
                .foregroundStyle(letterkleur)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(vlak))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(rand, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.druk)
        .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
    }

    private var vlak: Color {
        guard aan else { return palet.chip }
        if stil { return INKT.opacity(0.14) }
        return kleur ?? ORANJE
    }

    private var rand: Color {
        guard aan else { return palet.chipRand }
        if stil { return .clear }
        return kleur ?? ORANJE
    }

    private var letterkleur: Color {
        guard aan else { return palet.zacht }
        return stil ? palet.inkt : .white
    }
}

struct Emojiknop: View {
    let waarde: String
    var maat: CGFloat = 42
    let opTik: () -> Void

    @Environment(\.palet) private var palet

    var body: some View {
        Button(action: opTik) {
            RoundedRectangle(cornerRadius: maat / 2.9, style: .continuous)
                .fill(palet.tegel)
                .overlay(RoundedRectangle(cornerRadius: maat / 2.9, style: .continuous)
                    .strokeBorder(palet.tegelRand, lineWidth: 1))
                .overlay(Text(waarde).font(.system(size: maat * 0.53)))
                .frame(width: maat, height: maat)
        }
        .buttonStyle(.druk)
        .accessibilityLabel("Icoon")
    }
}

struct Bewerkkaart<Inhoudje: View>: View {
    @ViewBuilder var inhoud: () -> Inhoudje

    var body: some View {
        Glas(radius: 26) {
            VStack(spacing: 0) { inhoud() }
        }
        .padding(.top, 18)
    }
}

struct Streepje: View {
    @Environment(\.palet) private var palet

    var body: some View {
        Rectangle().fill(palet.streep).frame(height: 1)
    }
}

struct Toevoegrij: View {
    let opschrift: String
    let opTik: () -> Void

    @Environment(\.palet) private var palet

    init(_ opschrift: String, opTik: @escaping () -> Void) {
        self.opschrift = opschrift
        self.opTik = opTik
    }

    var body: some View {
        VStack(spacing: 0) {
            Streepje()
            Button(action: opTik) {
                HStack(spacing: 10) {
                    Rondbolletje()
                    Text(opschrift).letter(L.toevoeg).foregroundStyle(palet.zacht)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.druk)
        }
    }
}

// Eén regel in een bewerkkaart: weghalen links, de rest opent het formulier.
struct Bewerkrij: View {
    let icoon: String
    let label: String
    let leeg: String
    var tijd: String = ""
    var dagen: String = ""
    var extra: String = ""
    var wie: [Persoon] = []
    var kleur: String = ""
    // Een tijdvak, de dagen én wie het betreft passen niet naast de naam.
    var tweeregels: Bool = false
    let opOpenen: () -> Void

    @Environment(\.palet) private var palet

    private var meta: [String] { [tijd, dagen, extra].filter { !$0.isEmpty } }
    private var heeftMeta: Bool { !meta.isEmpty || !wie.isEmpty }

    var body: some View {
        // Geen scheidingslijn en geen weg-knop: in een List regelt de lijst dat.
        Button(action: opOpenen) {
                    if tweeregels {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 10) { icoonEnNaam }
                            if heeftMeta { metaregel.padding(.leading, 52) }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    } else {
                        HStack(spacing: 10) {
                            icoonEnNaam
                            if heeftMeta { metaregel }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }
        .buttonStyle(.druk)
        .padding(.vertical, 8)
        .frame(minHeight: 58)
    }

    @ViewBuilder
    private var icoonEnNaam: some View {
        Emojiknop(waarde: icoon, opTik: opOpenen)
        Text(label.isEmpty ? leeg : label)
            .letter(L.rijlabel)
            .foregroundStyle(label.isEmpty ? palet.zacht : palet.inkt)
            .lineLimit(1)
        // Het bolletje hoort bij de naam en niet bij de rand van de kaart: als
        // het helemaal rechts staat moet je twee keer kijken om te zien van wie
        // het is.
        if !kleur.isEmpty {
            Circle().fill(Color(hex: kleur)).frame(width: 16, height: 16)
        }
        Spacer(minLength: 0)
    }

    @ViewBuilder
    private var metaregel: some View {
        HStack(spacing: 8) {
            ForEach(meta, id: \.self) { t in
                Text(t).letter(L.rijdagen).foregroundStyle(palet.zacht).lineLimit(1)
            }
            if !wie.isEmpty { Gezichten(mensen: wie, maat: 24) }
        }
    }
}
