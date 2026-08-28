// Eén balkje per kind dat meeloopt met wat er af is. Vanaf drie kinderen naast
// elkaar wordt het te smal: dan twee per regel, net als op web.
import SwiftUI

struct Deel {
    var af: Int = 0
    var totaal: Int = 0
    var breuk: Double { totaal > 0 ? Double(af) / Double(totaal) : 0 }
}

struct Voortgang: View {
    let mensen: [Persoon]
    let deel: [String: Deel]
    var marge: CGFloat

    @Environment(\.palet) private var palet

    private var velen: Bool { mensen.count > 2 }

    var body: some View {
        Glas(radius: 26) {
            if velen {
                VStack(spacing: 0) {
                    ForEach(Array(rijen.enumerated()), id: \.offset) { (rij, paar) in
                        HStack(spacing: 0) {
                            ForEach(Array(paar.enumerated()), id: \.element.id) { (kolom, persoon) in
                                vak(persoon, links: kolom > 0, boven: rij > 0)
                                    .frame(maxWidth: .infinity)
                            }
                            if paar.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(mensen.enumerated()), id: \.element.id) { (i, persoon) in
                        vak(persoon, links: i > 0, boven: false)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.top, marge)
    }

    private var rijen: [[Persoon]] {
        stride(from: 0, to: mensen.count, by: 2).map {
            Array(mensen[$0..<min($0 + 2, mensen.count)])
        }
    }

    @ViewBuilder
    private func vak(_ persoon: Persoon, links: Bool, boven: Bool) -> some View {
        let mijn = deel[persoon.id] ?? Deel()
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(zacht(persoon.kleur, 0.18))
                Text(persoon.emoji).font(.system(size: 26))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(persoon.naam)
                        .letter(L.naam)
                        .foregroundStyle(palet.inkt)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(mijn.af)/\(mijn.totaal)")
                        .letter(L.telling)
                        .foregroundStyle(palet.zacht)
                }
                Goot(breuk: mijn.breuk, kleur: Color(hex: persoon.kleur))
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .overlay(alignment: .leading) {
            if links { Rectangle().fill(palet.scheiding).frame(width: 1) }
        }
        .overlay(alignment: .top) {
            if boven { Rectangle().fill(palet.scheiding).frame(height: 1) }
        }
    }
}

private struct Goot: View {
    let breuk: Double
    let kleur: Color
    @Environment(\.palet) private var palet

    var body: some View {
        GeometryReader { ruimte in
            ZStack(alignment: .leading) {
                Capsule().fill(palet.goot)
                // Een balk die naveert leest als 'bijna klaar, toch niet'; dus
                // gewoon lopen.
                Capsule()
                    .fill(kleur)
                    .frame(width: max(0, min(1, breuk)) * ruimte.size.width)
                    .animation(Beweging.rustig, value: breuk)
            }
        }
        .frame(height: 7)
    }
}
