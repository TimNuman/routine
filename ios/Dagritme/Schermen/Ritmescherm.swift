// Het ritme van vandaag: de stappen als kaartjes, per groep, met een rond
// gezichtje per kind dat meedoet.
//
// Ochtend en avond staan allebei permanent in het scherm: ochtend links, avond
// rechts — zo staat de schakelaar er ook bij — en alleen het gekozen ritme
// staat in beeld. De schakelaar breekt niets af en bouwt niets op; hij verlegt
// per element alleen het doel, met een wipje en elk element een tel na het
// vorige. Daardoor kan snel heen en weer tikken niet stotteren: wat halverwege
// hangt keert gewoon om vanaf waar het is. Zie Wissel in Vorm/Aanraken.swift.
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

struct Ritmescherm: View {
    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet

    // Hoe breed het blok is — dat is hoe ver "weg" opzij ligt — en hoe hoog
    // elk ritme uitpakt. Het scherm krijgt de hoogte van het gekozen ritme;
    // het andere hangt er onzichtbaar naast en mag daar niet aan meetrekken.
    @State private var breedte: CGFloat = 400
    @State private var hoogten: [Ritme: CGFloat] = [:]

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

    private func blokken(_ r: Ritme) -> [Blok] {
        guard let inhoud = gezin.inhoud else { return [] }
        return ritmeBlokken(inhoud, r, gezin.nu)
            .map { blok in
                var uit = blok
                uit.items = blok.items.filter(hoortErbij)
                return uit
            }
            .filter { !$0.items.isEmpty }
    }

    // Alles wat er hoort te staan, zonder filter — hier hangen de tellingen
    // aan, en die moeten over het hele ritme blijven gaan.
    private func alleGroepen(_ r: Ritme) -> [Groep] {
        guard let inhoud = gezin.inhoud else { return [] }
        return inhoud[r]
            .map { groep in
                var uit = groep
                uit.stappen = groep.stappen.filter { !$0.label.isEmpty && opDeze($0, gezin.nu) }
                return uit
            }
            .filter { !$0.stappen.isEmpty }
    }

    // Wat er in beeld komt: hetzelfde, maar dan zonder de kinderen die uit staan.
    private func groepen(_ r: Ritme) -> [Groep] {
        guard let inhoud = gezin.inhoud, gefilterd else { return alleGroepen(r) }
        return alleGroepen(r)
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
            for groep in alleGroepen(gezin.ritme) {
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

    private func wissel(_ id: String) {
        Trilling.keuze()
        withAnimation(Beweging.veer) { gezin.wisselKind(id) }
    }

    // De elementen regelen hun eigen reis (zie Wissel); deze animatie is voor
    // de rest — de titel, de tellingen, en de hoogte van het blok.
    private func kies(_ nieuw: Ritme) {
        guard nieuw != gezin.ritme else { return }
        Trilling.keuze()
        withAnimation(Beweging.schuif) { gezin.zetRitme(nieuw) }
    }

    // Eén kolom op een telefoon — voortgang, Vandaag, de stappen, Morgen — en
    // twee zodra er ruimte is, met het weekritme ernaast.
    @ViewBuilder
    private var inhoudje: some View {
        // Staat er niets in de agenda, dan vervalt de kolom en krijgen de
        // kaartjes de volle breedte.
        let metZij = m.breed && !blokken(gezin.ritme).isEmpty

        if m.breed {
            HStack(alignment: .top, spacing: m.naast) {
                VStack(alignment: .leading, spacing: 0) {
                    wisselaar
                }
                .padding(.top, metZij ? 31 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                if metZij, let inhoud = gezin.inhoud {
                    ZStack(alignment: .topLeading) {
                        zijluik(.dag, inhoud)
                        zijluik(.nacht, inhoud)
                    }
                    .frame(width: m.zijkolom)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) { wisselaar }
        }
    }

    // De balkjes horen bij het scherm, niet bij het ritme: ze blijven staan
    // terwijl hun tellingen en kleuren ter plekke omrollen.
    @ViewBuilder
    private var wisselaar: some View {
        if let inhoud = gezin.inhoud {
            Voortgang(mensen: inhoud.mensen, deel: deel, marge: m.breed ? 0 : 14,
                      zichtbaar: zichtbaar, gefilterd: gefilterd, opKies: wissel)
                .komtBinnen()
        }
        tweeluik
    }

    // Beide ritmes bestaan altijd. Het blok is zo hoog als het gekozen ritme;
    // het andere is even hoog als hijzelf maar telt niet mee, dus wat er onder
    // de rand uitsteekt hangt buiten beeld naast het scherm.
    private var tweeluik: some View {
        ZStack(alignment: .topLeading) {
            luik(.dag)
            luik(.nacht)
        }
        .frame(height: hoogten[gezin.ritme], alignment: .top)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width },
                          action: { breedte = $0 })
    }

    private func luik(_ r: Ritme) -> some View {
        let thuis = gezin.ritme == r
        return VStack(alignment: .leading, spacing: 0) { kolom(r) }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height },
                              action: { hoogten[r] = $0 })
            // Wat binnenkomt hoort óver wat vertrekt te reizen, niet eronder.
            .zIndex(thuis ? 1 : 0)
            .allowsHitTesting(thuis)
            .accessibilityHidden(!thuis)
    }

    private func zijluik(_ r: Ritme, _ inhoud: Inhoud) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blokken(r).enumerated()), id: \.element.id) { (i, blok) in
                Agenda(blok: blok, mensen: inhoud.mensen, zij: true, eerste: i == 0,
                       wissel: stand(r, i * 2))
            }
        }
        .zIndex(gezin.ritme == r ? 1 : 0)
        .allowsHitTesting(gezin.ritme == r)
        .accessibilityHidden(gezin.ritme != r)
    }

    @ViewBuilder
    private func kolom(_ r: Ritme) -> some View {
        if let inhoud = gezin.inhoud {
            if !m.breed {
                ForEach(Array(blokken(r).filter { !$0.later }.enumerated()), id: \.element.id) { (i, blok) in
                    Agenda(blok: blok, mensen: inhoud.mensen,
                           wissel: stand(r, i * 2))
                }
            }

            ForEach(Array(groepen(r).enumerated()), id: \.offset) { (gi, groep) in
                // Het kopje en de kaartjes eronder tellen door op één rij, zodat
                // het golfje van boven naar beneden loopt en niet per groep
                // opnieuw begint.
                let begin = voorloop(r, gi)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(groep.groep).letter(L.groep).foregroundStyle(palet.inkt)
                    if !groep.tijd.isEmpty {
                        Text(groep.tijd).letter(L.groeptijd).foregroundStyle(palet.zacht)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, m.insprong)
                .padding(.bottom, 10)
                .wisselplek(stand(r, begin))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: m.tussen),
                                   count: m.perRij),
                    spacing: m.tussen
                ) {
                    ForEach(Array(groep.stappen.enumerated()), id: \.element) { (si, stap) in
                        Kaartje(stap: stap, inhoud: inhoud, ritme: r, zichtbaar: zichtbaar,
                                // Elk kaartje zijn eigen tel, ook naast elkaar:
                                // binnen een rij loopt het golfje dan gewoon
                                // opzij door in plaats van per rij te ploffen.
                                wissel: stand(r, begin + 1 + si))
                    }
                }
            }

            if !m.breed {
                ForEach(Array(blokken(r).filter { $0.later }.enumerated()), id: \.element.id) { (i, blok) in
                    Agenda(blok: blok, mensen: inhoud.mensen,
                           wissel: stand(r, naloop(r) + i * 2))
                }
            }

            if !groepen(r).isEmpty {
                Opnieuw().wisselplek(stand(r, naloop(r) + blokken(r).filter { $0.later }.count * 2 + 1))
            }
        }
    }

    // Alles wat een element moet weten om mee te doen aan de wissel: waar het
    // thuishoort, of dat nu in beeld is, en hoe ver opzij "weg" ligt.
    private func stand(_ r: Ritme, _ plek: Int) -> Wissel {
        Wissel(plek: plek, kant: r == .nacht ? 1 : -1,
               thuis: gezin.ritme == r, uitwijk: breedte + 60)
    }

    // De plekken in het golfje, doorgeteld over alles heen. Een agendablok is
    // er twee (de kop en de kaart), een groep een kopje plus één per kaartje.
    private func voorloop(_ r: Ritme, _ gi: Int) -> Int {
        var n = m.breed ? 0 : blokken(r).filter { !$0.later }.count * 2
        for groep in groepen(r).prefix(gi) {
            n += 1 + groep.stappen.count
        }
        return n
    }

    // Waar de staart na de groepen begint.
    private func naloop(_ r: Ritme) -> Int {
        voorloop(r, groepen(r).count)
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
    let wissel: Wissel

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
        .wisselplek(wissel)
    }
}
