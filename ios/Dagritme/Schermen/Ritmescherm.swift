// Het ritme van vandaag: de stappen als kaartjes, per groep, met een rond
// gezichtje per kind dat meedoet.
import SwiftUI

struct Ritmescherm: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet

    private var blokken: [Blok] {
        guard let inhoud = gezin.inhoud else { return [] }
        return ritmeBlokken(inhoud, gezin.ritme, gezin.nu).filter { !$0.items.isEmpty }
    }

    private var groepen: [Groep] {
        guard let inhoud = gezin.inhoud else { return [] }
        return inhoud[gezin.ritme]
            .map { groep in
                var uit = groep
                uit.stappen = groep.stappen.filter { !$0.label.isEmpty && opDeze($0, gezin.nu) }
                return uit
            }
            .filter { !$0.stappen.isEmpty }
    }

    private var deel: [String: Deel] {
        guard let inhoud = gezin.inhoud else { return [:] }
        var uit: [String: Deel] = [:]
        for persoon in inhoud.mensen {
            var telling = Deel()
            for groep in groepen {
                for stap in groep.stappen {
                    guard wieDoetMee(stap, inhoud.mensen).contains(where: { $0.id == persoon.id })
                    else { continue }
                    telling.totaal += 1
                    if gezin.vinkjes[vinkSleutel(gezin.ritme, stapSleutel(stap), persoon.id)] == true {
                        telling.af += 1
                    }
                }
            }
            uit[persoon.id] = telling
        }
        return uit
    }

    var body: some View {
        Scherm(
            titel: gezin.ritme == .nacht ? "Avond" : "Ochtend",
            onder: datumTekst(gezin.nu),
            midden: AnyView(Segment(ritme: gezin.ritme, opKies: gezin.zetRitme,
                                    marge: m.breed ? 0 : 16))
        ) {
            inhoudje
        }
    }

    // Eén kolom op een telefoon — voortgang, Vandaag, de stappen, Morgen — en
    // twee zodra er ruimte is, met het weekritme ernaast.
    @ViewBuilder
    private var inhoudje: some View {
        // Staat er niets in de agenda, dan vervalt de kolom en krijgen de
        // kaartjes de volle breedte.
        let metZij = m.breed && !blokken.isEmpty

        if m.breed {
            HStack(alignment: .top, spacing: m.naast) {
                VStack(alignment: .leading, spacing: 0) {
                    kolom
                }
                .padding(.top, metZij ? 31 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                if metZij, let inhoud = gezin.inhoud {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(blokken.enumerated()), id: \.element.id) { (i, blok) in
                            Agenda(blok: blok, mensen: inhoud.mensen, zij: true, eerste: i == 0)
                        }
                    }
                    .frame(width: m.zijkolom)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) { kolom }
        }
    }

    @ViewBuilder
    private var kolom: some View {
        if let inhoud = gezin.inhoud {
            Voortgang(mensen: inhoud.mensen, deel: deel, marge: m.breed ? 0 : 14)

            if !m.breed {
                ForEach(blokken.filter { !$0.later }) { blok in
                    Agenda(blok: blok, mensen: inhoud.mensen)
                }
            }

            ForEach(Array(groepen.enumerated()), id: \.offset) { (gi, groep) in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(groep.groep).letter(L.groep).foregroundStyle(palet.inkt)
                    if !groep.tijd.isEmpty {
                        Text(groep.tijd).letter(L.groeptijd).foregroundStyle(palet.zacht)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, m.insprong)
                .padding(.bottom, 10)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: m.tussen),
                                   count: m.perRij),
                    spacing: m.tussen
                ) {
                    ForEach(Array(groep.stappen.enumerated()), id: \.offset) { (si, stap) in
                        Kaartje(stap: stap, inhoud: inhoud, ritme: gezin.ritme,
                                vertraag: Beweging.natikken(gi * 3 + si))
                    }
                }
            }

            if !m.breed {
                ForEach(blokken.filter { $0.later }) { blok in
                    Agenda(blok: blok, mensen: inhoud.mensen)
                }
            }

            if !groepen.isEmpty { Opnieuw() }
        }
    }
}

// Alle vinkjes van dit ritme in één keer weg, voor als je van voren af aan wilt.
private struct Opnieuw: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.palet) private var palet

    var body: some View {
        Button { gezin.wis() } label: {
            Text("opnieuw beginnen")
                .letter(L.opnieuw)
                .foregroundStyle(palet.zacht)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .overlay(Capsule().strokeBorder(INKT.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
    }
}

private struct Kaartje: View {
    let stap: Stap
    let inhoud: Inhoud
    let ritme: Ritme
    let vertraag: Double

    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet
    @State private var binnen = false

    var body: some View {
        let sleutel = stapSleutel(stap)
        let meedoen = wieDoetMee(stap, inhoud.mensen)

        Glas(radius: 22) {
            VStack(spacing: m.kaartGat) {
                Spacer(minLength: 0)
                // Emoji en naam staan samen midden in de kaart: de vrije ruimte
                // valt boven de emoji en onder de naam, want de rondjes staan vast.
                Text(stap.icoon).font(.system(size: m.icoon))
                Text(stap.label)
                    .letter(L.taaknaam(m.naam))
                    .foregroundStyle(palet.inkt)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Spacer(minLength: 0)
                // De rondjes zakken naar de onderkant, zodat elk kaartje er
                // hetzelfde uitziet ongeacht hoe lang de naam is.
                Vloeiend(gat: 2, rijgat: 2, midden: true) {
                    ForEach(meedoen) { persoon in
                        Rondje(
                            persoon: persoon,
                            aan: gezin.vinkjes[vinkSleutel(ritme, sleutel, persoon.id)] == true,
                            maat: m.rondje, gezicht: m.gezicht, teken: m.teken,
                            opTik: { gezin.tik(vinkSleutel(ritme, sleutel, persoon.id)) }
                        )
                    }
                }
            }
            .padding(.horizontal, m.kaartX)
            .padding(.vertical, m.kaartY)
            .frame(maxWidth: .infinity, minHeight: m.hoog)
        }
        .opacity(binnen ? 1 : 0)
        .offset(y: binnen ? 0 : 10)
        .onAppear {
            withAnimation(Beweging.kort.delay(vertraag)) { binnen = true }
        }
    }
}
