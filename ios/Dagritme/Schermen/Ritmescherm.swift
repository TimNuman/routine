// Het ritme van vandaag: de stappen als kaartjes, per groep, met een rond
// gezichtje per kind dat meedoet.
//
// Van ochtend naar avond vertrekt het oude blok opzij — vooruit naar links,
// terug naar rechts, want zo staat de schakelaar er ook bij. Wat binnenkomt
// schuift niet als blok mee maar komt er los van: elk element apart van
// dezelfde kant, met een wipje aan het eind en elk een tel na het vorige — de
// agendakop eerst, dan de regels, dan kopjes en kaartjes, kaartje voor kaartje.
// Dat golfje is wat het onderscheid maakt tussen "het scherm is veranderd" en
// "er komt iets aan".
//
// De balkjes bovenaan doen níet mee: die horen bij het scherm, niet bij het
// ritme, dus die blijven staan en alleen hun tellingen en kleuren draaien om.
// Het zijn ook de schakelaars per kind: wie uit staat verdwijnt van de
// kaartjes, en een agendaregel die alleen over hem gaat verdwijnt mee. Zie
// Gezin.wisselKind voor waarom de eerste tik iets anders doet dan de rest.
//
// De tellingen blijven wél over iedereen gaan — zou een uitgezet kind op 0/0
// springen, dan lijkt het alsof zijn ochtend weg is.
import SwiftUI

// Hoe ver alles opzij klaarstaat voor het binnenkomt. Het blok zelf schuift
// niet meer mee, dus dit is de hele reis; op de standaard 22 zou je de beweging
// nauwelijks zien aankomen.
private let AANLOOP: CGFloat = 56

struct Ritmescherm: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet

    // Welke kant het op ging bij de laatste wissel; leest de overgang uit.
    @State private var richting: CGFloat = 1

    private var allen: Set<String> {
        Set((gezin.inhoud?.mensen ?? []).map(\.id))
    }

    // Wie er meedoet. Kan nooit leeg worden: dat zou een scherm zonder kaartjes
    // opleveren, en dan is er ook niets meer om op terug te tikken.
    private var zichtbaar: Set<String> {
        let over = allen.subtracting(gezin.verborgen)
        return over.isEmpty ? allen : over
    }

    // Staat er iets uit? Dan mag het scherm laten merken dat je iets hebt gekozen.
    private var gefilterd: Bool { zichtbaar.count < allen.count }

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

    // Wat er in beeld komt: hetzelfde, maar dan zonder de kinderen die uit staan.
    private var groepen: [Groep] {
        guard let inhoud = gezin.inhoud, gefilterd else { return alleGroepen }
        return alleGroepen
            .map { groep in
                var uit = groep
                uit.stappen = groep.stappen.filter { stap in
                    wieDoetMee(stap, inhoud.mensen).contains { zichtbaar.contains($0.id) }
                }
                return uit
            }
            .filter { !$0.stappen.isEmpty }
    }

    // Een regel zonder namen gaat over iedereen, dus die blijft altijd staan.
    private func hoortErbij(_ item: Agendaitem) -> Bool {
        guard gefilterd else { return true }
        return item.wie.isEmpty || item.wie.contains { zichtbaar.contains($0) }
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
    private func wissel(_ id: String) {
        Trilling.keuze()
        withAnimation(Beweging.veer) { gezin.wisselKind(id) }
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
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(blokken.enumerated()), id: \.element.id) { (i, blok) in
                                Agenda(blok: blok, mensen: inhoud.mensen, zij: true, eerste: i == 0,
                                       vanaf: zijloop(i), richting: richting,
                                       afstand: AANLOOP, animatie: Beweging.entree)
                            }
                        }
                        .id(gezin.ritme)
                        .schuiftWeg(richting)
                    }
                    .frame(width: m.zijkolom)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) { wisselaar }
        }
    }

    // De balkjes staan boven de wissel en horen er niet bij: geen nieuwe
    // identiteit als het ritme omgaat, dus ze blijven staan terwijl hun
    // tellingen en kleuren ter plekke omrollen. De rest van de kolom is één
    // ding dat vervangen wordt. De ZStack is er omdat oud en nieuw elkaar even
    // overlappen: in een VStack zouden ze onder elkaar komen te staan en zou
    // het scherm tijdens de overgang twee keer zo lang worden.
    @ViewBuilder
    private var wisselaar: some View {
        if let inhoud = gezin.inhoud {
            Voortgang(mensen: inhoud.mensen, deel: deel, marge: m.breed ? 0 : 14,
                      zichtbaar: zichtbaar, gefilterd: gefilterd, opKies: wissel)
                .komtBinnen(0, vanaf: richting)
        }
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) { kolom }
                .id(gezin.ritme)
                .schuiftWeg(richting)
        }
    }

    @ViewBuilder
    private var kolom: some View {
        if let inhoud = gezin.inhoud {
            if !m.breed {
                ForEach(Array(blokken.filter { !$0.later }.enumerated()), id: \.element.id) { (i, blok) in
                    Agenda(blok: blok, mensen: inhoud.mensen,
                           vanaf: eerder(i), richting: richting,
                           afstand: AANLOOP, animatie: Beweging.entree)
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
                .komtBinnen(begin, vanaf: richting, afstand: AANLOOP, animatie: Beweging.entree)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: m.tussen),
                                   count: m.perRij),
                    spacing: m.tussen
                ) {
                    ForEach(Array(groep.stappen.enumerated()), id: \.element) { (si, stap) in
                        Kaartje(stap: stap, inhoud: inhoud, ritme: gezin.ritme, zichtbaar: zichtbaar,
                                // Elk kaartje zijn eigen tel, ook naast elkaar:
                                // binnen een rij loopt het golfje dan gewoon
                                // opzij door in plaats van per rij te ploffen.
                                volgorde: begin + 1 + si,
                                richting: richting)
                    }
                }
            }

            if !m.breed {
                ForEach(Array(blokken.filter { $0.later }.enumerated()), id: \.element.id) { (i, blok) in
                    Agenda(blok: blok, mensen: inhoud.mensen,
                           vanaf: naloop(i), richting: richting,
                           afstand: AANLOOP, animatie: Beweging.entree)
                }
            }

            if !groepen.isEmpty {
                Opnieuw().komtBinnen(naloop(blokken.filter { $0.later }.count) + 1,
                                     vanaf: richting, afstand: AANLOOP, animatie: Beweging.entree)
            }
        }
    }

    // De plekken in de volgorde, doorgeteld over alles heen: elke agendaregel,
    // elk kopje en elk kaartje is er één. Een blok in de agenda telt als zijn
    // kop plus zijn regels.
    private func plekken<S: Sequence>(_ blokken: S) -> Int where S.Element == Blok {
        blokken.reduce(0) { $0 + 1 + $1.items.count }
    }

    // Waar agendablok `i` bovenaan begint (alleen op een telefoon; breed staat
    // de agenda in de zijkolom en begint de kolom bij de eerste groep).
    private func eerder(_ i: Int) -> Int {
        plekken(blokken.filter { !$0.later }.prefix(i))
    }

    // Hoeveel plekken er vóór groep `gi` liggen: de agenda erboven, en per
    // eerdere groep een kopje plus zijn kaartjes.
    private func voorloop(_ gi: Int) -> Int {
        var n = m.breed ? 0 : plekken(blokken.filter { !$0.later })
        for groep in groepen.prefix(gi) {
            n += 1 + groep.stappen.count
        }
        return n
    }

    // Waar de staart na de groepen begint: het `i`-de latere agendablok.
    private func naloop(_ i: Int) -> Int {
        voorloop(groepen.count) + plekken(blokken.filter { $0.later }.prefix(i))
    }

    // Hetzelfde voor de zijkolom, die zijn eigen telling heeft: die golft naast
    // de kaartjes mee in plaats van erachteraan.
    private func zijloop(_ i: Int) -> Int {
        plekken(blokken.prefix(i))
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
    let zichtbaar: Set<String>
    let volgorde: Int
    let richting: CGFloat

    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet

    // Wie er op dit kaartje staan: alleen de kinderen die aan staan.
    private var meedoen: [Persoon] {
        wieDoetMee(stap, inhoud.mensen).filter { zichtbaar.contains($0.id) }
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
        .komtBinnen(volgorde, vanaf: richting, afstand: AANLOOP, animatie: Beweging.entree)
    }
}
