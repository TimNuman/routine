// Het ritme van vandaag: de stappen als kaartjes, per groep, met een rond
// gezichtje per kind dat meedoet.
//
// Van ochtend naar avond schuift het hele blok opzij — avond komt van rechts,
// ochtend van links, want zo staat de schakelaar er ook bij. Wat binnenkomt doet
// dat van boven naar beneden: eerst de balkjes, dan de agenda, dan de kaartjes
// per rij. Dat golfje is wat het onderscheid maakt tussen "het scherm is
// veranderd" en "er komt iets aan".
//
// Tikken op een kind in de balkjes bovenaan filtert het hele scherm op dat kind:
// de kaartjes waar hij niet in voorkomt vallen weg, net als het agendaregeltje
// dat over de ander gaat. De tellingen zelf blijven wél over iedereen gaan —
// zou het andere kind op 0/0 springen, dan lijkt het alsof zijn ochtend weg is.
import SwiftUI

struct Ritmescherm: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet

    // Welke kant het op ging bij de laatste wissel; leest de overgang uit.
    @State private var richting: CGFloat = 1

    // Waar het filter op staat, of nil. Uit Gezin, maar alleen als dat kind er
    // nog is: wie een kind weghaalt terwijl het filter erop stond zou anders naar
    // een leeg scherm kijken.
    private var alleen: String? {
        guard let id = gezin.alleen, let inhoud = gezin.inhoud,
              inhoud.mensen.contains(where: { $0.id == id })
        else { return nil }
        return id
    }

    private var blokken: [Blok] {
        guard let inhoud = gezin.inhoud else { return [] }
        return ritmeBlokken(inhoud, gezin.ritme, gezin.nu)
            .map { blok in
                var uit = blok
                uit.items = blok.items.filter(hoortErbij)
                return uit
            }
            .filter { !$0.items.isEmpty }
    }

    // Alles wat er vandaag hoort te staan, zonder filter — hier hangen de
    // tellingen aan, en die moeten over het hele ritme blijven gaan.
    private var alleGroepen: [Groep] {
        guard let inhoud = gezin.inhoud else { return [] }
        return inhoud[gezin.ritme]
            .map { groep in
                var uit = groep
                uit.stappen = groep.stappen.filter { !$0.label.isEmpty && opDeze($0, gezin.nu) }
                return uit
            }
            .filter { !$0.stappen.isEmpty }
    }

    // Wat er in beeld komt: hetzelfde, maar dan door het filter.
    private var groepen: [Groep] {
        guard let inhoud = gezin.inhoud, let alleen else { return alleGroepen }
        return alleGroepen
            .map { groep in
                var uit = groep
                uit.stappen = groep.stappen.filter { stap in
                    wieDoetMee(stap, inhoud.mensen).contains { $0.id == alleen }
                }
                return uit
            }
            .filter { !$0.stappen.isEmpty }
    }

    // Een regel zonder namen gaat over iedereen, dus die blijft altijd staan.
    private func hoortErbij(_ item: Agendaitem) -> Bool {
        guard let alleen else { return true }
        return item.wie.isEmpty || item.wie.contains(alleen)
    }

    private var deel: [String: Deel] {
        guard let inhoud = gezin.inhoud else { return [:] }
        var uit: [String: Deel] = [:]
        for persoon in inhoud.mensen {
            var telling = Deel()
            for groep in alleGroepen {
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
            midden: AnyView(Segment(ritme: gezin.ritme, opKies: kies,
                                    marge: m.breed ? 0 : 16))
        ) {
            inhoudje
        }
    }

    // De schakelaar zet niet alleen het ritme om, maar bepaalt ook welke kant het
    // op schuift. Allebei in dezelfde beweging, zodat de pil en het blok samen
    // vertrekken.
    // Nog een keer op hetzelfde kind tikken zet het filter weer uit.
    private func filter(_ id: String) {
        Trilling.keuze()
        withAnimation(Beweging.veer) {
            gezin.alleen = gezin.alleen == id ? nil : id
        }
    }

    private func kies(_ nieuw: Ritme) {
        guard nieuw != gezin.ritme else { return }
        richting = nieuw == .nacht ? 1 : -1
        Trilling.keuze()
        withAnimation(Beweging.schuif) { gezin.zetRitme(nieuw) }
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
                    wisselaar
                }
                .padding(.top, metZij ? 31 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                if metZij, let inhoud = gezin.inhoud {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(blokken.enumerated()), id: \.element.id) { (i, blok) in
                            Agenda(blok: blok, mensen: inhoud.mensen, zij: true, eerste: i == 0)
                                .komtBinnen(i + 2, vanaf: richting, afstand: 18)
                        }
                    }
                    .frame(width: m.zijkolom)
                    .id(gezin.ritme)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) { wisselaar }
        }
    }

    // De hele kolom is één ding dat vervangen wordt als het ritme omgaat. De
    // ZStack is er omdat oud en nieuw elkaar even overlappen: in een VStack
    // zouden ze onder elkaar komen te staan en zou het scherm tijdens de
    // overgang twee keer zo lang worden.
    @ViewBuilder
    private var wisselaar: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) { kolom }
                .id(gezin.ritme)
                .schuiftMee(richting)
        }
    }

    @ViewBuilder
    private var kolom: some View {
        if let inhoud = gezin.inhoud {
            Voortgang(mensen: inhoud.mensen, deel: deel, marge: m.breed ? 0 : 14,
                      alleen: alleen, opKies: filter)
                .komtBinnen(0, vanaf: richting)

            if !m.breed {
                ForEach(Array(blokken.filter { !$0.later }.enumerated()), id: \.element.id) { (i, blok) in
                    Agenda(blok: blok, mensen: inhoud.mensen)
                        .komtBinnen(i + 1, vanaf: richting)
                }
            }

            ForEach(Array(groepen.enumerated()), id: \.offset) { (gi, groep) in
                // Het kopje en de kaartjes eronder tellen door op één rij, zodat
                // het golfje van boven naar beneden loopt en niet per groep
                // opnieuw begint.
                let begin = voorloop(gi)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(groep.groep).letter(L.groep).foregroundStyle(palet.inkt)
                    if !groep.tijd.isEmpty {
                        Text(groep.tijd).letter(L.groeptijd).foregroundStyle(palet.zacht)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, m.insprong)
                .padding(.bottom, 10)
                .komtBinnen(begin, vanaf: richting)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: m.tussen),
                                   count: m.perRij),
                    spacing: m.tussen
                ) {
                    ForEach(Array(groep.stappen.enumerated()), id: \.element) { (si, stap) in
                        Kaartje(stap: stap, inhoud: inhoud, ritme: gezin.ritme, alleen: alleen,
                                // Per rij tegelijk, niet per kaartje: drie naast
                                // elkaar die na elkaar komen leest als haperen.
                                volgorde: begin + 1 + si / max(1, m.perRij),
                                richting: richting)
                    }
                }
            }

            if !m.breed {
                ForEach(Array(blokken.filter { $0.later }.enumerated()), id: \.element.id) { (i, blok) in
                    Agenda(blok: blok, mensen: inhoud.mensen)
                        .komtBinnen(voorloop(groepen.count) + i, vanaf: richting)
                }
            }

            if !groepen.isEmpty {
                Opnieuw().komtBinnen(voorloop(groepen.count) + 2, vanaf: richting)
            }
        }
    }

    // Hoeveel plekken in de volgorde er vóór groep `gi` liggen: de balkjes, de
    // agenda erboven, en per eerdere groep een kopje plus zijn rijen.
    private func voorloop(_ gi: Int) -> Int {
        var n = 1 + (m.breed ? 0 : blokken.filter { !$0.later }.count)
        for groep in groepen.prefix(gi) {
            n += 1 + Int(ceil(Double(groep.stappen.count) / Double(max(1, m.perRij))))
        }
        return n
    }
}

// Alle vinkjes van dit ritme in één keer weg, voor als je van voren af aan wilt.
private struct Opnieuw: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.palet) private var palet

    var body: some View {
        Button {
            Trilling.tik()
            withAnimation(Beweging.veer) { gezin.wis() }
        } label: {
            Text("opnieuw beginnen")
                .letter(L.opnieuw)
                .foregroundStyle(palet.zacht)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .overlay(Capsule().strokeBorder(INKT.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.druk(0.94, flauwte: 0.7))
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
    }
}

private struct Kaartje: View {
    let stap: Stap
    let inhoud: Inhoud
    let ritme: Ritme
    let alleen: String?
    let volgorde: Int
    let richting: CGFloat

    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet

    // Wie er op dit kaartje staan. Staat het scherm op één kind, dan staat dat
    // kind er alleen op — de ander hoort bij een kaartje dat je nu niet ziet.
    private var meedoen: [Persoon] {
        let allen = wieDoetMee(stap, inhoud.mensen)
        guard let alleen else { return allen }
        return allen.filter { $0.id == alleen }
    }

    // Alle gezichtjes op dit kaartje af: dan komt de kaart zelf ook even omhoog.
    private var helemaalAf: Bool {
        let sleutel = stapSleutel(stap)
        guard !meedoen.isEmpty else { return false }
        return meedoen.allSatisfy {
            gezin.vinkjes[vinkSleutel(ritme, sleutel, $0.id)] == true
        }
    }

    var body: some View {
        let sleutel = stapSleutel(stap)

        Glas(radius: 22) {
            VStack(spacing: m.kaartGat) {
                Spacer(minLength: 0)
                // Emoji en naam staan samen midden in de kaart: de vrije ruimte
                // valt boven de emoji en onder de naam, want de rondjes staan vast.
                Text(stap.icoon)
                    .font(.system(size: m.icoon))
                    // Als de kaart klaar is wipt de emoji één keer mee op.
                    .scaleEffect(helemaalAf ? 1.12 : 1)
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
        // Een afgeronde kaart zakt een tikje terug: klaar is klaar, en dan mag
        // hij naar de achtergrond. Subtiel — het moet geen tweede feestje worden.
        .scaleEffect(helemaalAf ? 0.985 : 1)
        .animation(Beweging.wip, value: helemaalAf)
        .komtBinnen(volgorde, vanaf: richting)
    }
}
