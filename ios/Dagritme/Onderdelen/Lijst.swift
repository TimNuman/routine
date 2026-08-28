// De lijst met instellingen: een tegel met een emoji, een titel met uitleg
// eronder, en een pijltje rechts.
import SwiftUI

struct Lijst<Inhoudje: View>: View {
    @ViewBuilder var inhoud: () -> Inhoudje

    var body: some View {
        Glas(radius: 26) {
            VStack(spacing: 0) { inhoud() }
        }
        .padding(.top, 16)
    }
}

struct Lijstrij: View {
    let icoon: String
    let titel: String
    let uitleg: String
    var eerste: Bool = false
    var gezichten: [Persoon] = []
    let opTik: () -> Void

    @Environment(\.palet) private var palet

    var body: some View {
        VStack(spacing: 0) {
            if !eerste { Rectangle().fill(palet.streep).frame(height: 1) }
            Button(action: opTik) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palet.tegel)
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(palet.tegelRand, lineWidth: 1))
                        .overlay(Text(icoon).font(.system(size: 22)))
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(titel).letter(L.lijsttitel).foregroundStyle(palet.inkt).lineLimit(1)
                        Text(uitleg).letter(L.lijstuitleg).foregroundStyle(palet.zacht).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if !gezichten.isEmpty { Gezichten(mensen: gezichten) }
                    Pijltje().opacity(0.6)
                }
                .padding(14)
                .frame(minHeight: 62)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// De gezichtjes die bij Kinderen rechts meekijken, half over elkaar.
struct Gezichten: View {
    let mensen: [Persoon]
    var maat: CGFloat = 34

    var body: some View {
        HStack(spacing: -8) {
            ForEach(mensen.prefix(4)) { p in
                ZStack {
                    Circle().fill(zacht(p.kleur, 0.18))
                    Text(p.emoji).font(.system(size: maat * 0.56))
                }
                .frame(width: maat, height: maat)
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
            }
        }
    }
}
