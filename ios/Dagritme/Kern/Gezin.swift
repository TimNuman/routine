// Alles wat elk scherm nodig heeft staat hier één keer: de inhoud, de vinkjes
// van vandaag en of het ochtend of avond is. Zo blijft de kleurovergang
// doorlopen als je van tabblad wisselt, en wordt de inhoud niet per scherm
// opnieuw gehaald.
//
// De stroom blijft openstaan zolang de app open is: wat er op een andere
// telefoon gebeurt komt hier binnen en staat meteen in beeld.
import Foundation
import Observation

// De volgorde telt: hij bepaalt welke kant het scherm op schuift, of je nu op
// de balk drukt of veegt. `allCases` staat in deze volgorde, en dat is meteen de
// volgorde van links naar rechts in het menu.
enum Tab: Hashable, CaseIterable {
    case ritme
    case week
    case instellingen
}

@MainActor
@Observable
final class Gezin {
    var inhoud: Inhoud?
    var fout = ""
    var vinkjes: Vinkjes = [:]
    var ritme: Ritme = .dag
    var tab: Tab = .ritme
    // Staat er een blad overheen? De menubalk zweeft boven de schermen en zou
    // anders over dat blad heen komen te liggen.
    var bladOpen = false
    // Welke kinderen even niet meedoen op het ritmescherm. Leeg is iedereen, en
    // dat is ook de gewone stand. Staat hier en niet in het scherm zelf, zodat
    // een blik op de week hem niet wist.
    //
    // Bewust bijgehouden als wie er úít staat en niet wie er aan staat: dan is
    // 'iedereen' gewoon leeg, en hoeft dit niets te weten van wie er in het
    // gezin zitten of erbij komen.
    var verborgen: Set<String> = []
    var nu = Date()

    var datum: String { datumVan(nu) }

    // Of het scherm nú donker is. Dat is niet hetzelfde als het ritme: het
    // avondritme kleurt alleen die pagina, de week en de instellingen blijven
    // licht.
    var avond: Bool { ritme == .nacht && tab == .ritme }

    @ObservationIgnored private var stroom: Stroom?
    @ObservationIgnored private var klok: Task<Void, Never>?
    @ObservationIgnored private var gekozen = false   // heeft iemand zelf gekozen?

    init() {
        Task { await herlaad() }
        volgMee()
        loopMee()
    }

    // Eerst ophalen zodat er meteen iets staat, en daarna meeluisteren.
    func herlaad() async {
        do {
            async let verse = Opslag.haalInhoud()
            async let gezet = Opslag.haalVinkjes(datum)
            let (c, v) = try await (verse, gezet)
            inhoud = c
            vinkjes = v
            fout = ""
            if !gekozen {
                ritme = kalender.component(.hour, from: Date()) >= AVONDVANAF ? .nacht : .dag
            }
        } catch {
            fout = error.localizedDescription
        }
    }

    // Terug uit de slaap: de verbinding is dan weg zonder dat iemand het zei.
    func wakker() {
        Task { await herlaad() }
        stroom?.kijkNaar(datum)
    }

    // De schakelaars per kind, met één afwijking op de eerste tik.
    //
    // Staat alles aan, dan is dat geen keuze maar de ruststand — er valt niets
    // uit te zetten waar je wat aan hebt. Een tik betekent dan "even alleen dit
    // kind". Zodra er iemand uit staat is het een gewone schakelaar, en kun je er
    // eentje bij aanzetten of nog eentje uit.
    //
    // Dat betekent dat dezelfde knop twee dingen doet, afhankelijk van waar je
    // vandaan komt: vanuit alles-aan solo je ermee, vanaf daar schakel je. Dat is
    // precies de bedoeling — de laatste die je weer aanzet brengt je terug in de
    // ruststand, en de tik daarna is dus opnieuw een solo.
    func wisselKind(_ id: String) {
        let allen = Set((inhoud?.mensen ?? []).map(\.id))
        // Een kind dat uit het gezin is gehaald telt niet meer mee; anders zou
        // 'iedereen staat uit' nooit meer kloppen.
        verborgen.formIntersection(allen)

        if verborgen.isEmpty {
            verborgen = allen.subtracting([id])
        } else if verborgen.contains(id) {
            verborgen.remove(id)
        } else {
            verborgen.insert(id)
            // Niemand meer over is geen bruikbaar scherm; dan liever iedereen
            // terug dan een lege lijst.
            if verborgen == allen { verborgen.removeAll() }
        }
    }

    func zetRitme(_ nieuw: Ritme) {
        gekozen = true
        ritme = nieuw
    }

    // Meteen omzetten en pas daarna schrijven; mislukt dat, dan gaat hij terug.
    func tik(_ sleutel: String) {
        let aan = vinkjes[sleutel] != true
        zet(sleutel, aan)
        let dag = datum
        Task {
            do {
                try await Opslag.schrijfVink(datum: dag, sleutel: sleutel, aan: aan)
            } catch {
                zet(sleutel, !aan)
            }
        }
    }

    // Alle vinkjes van dit ritme weg — opnieuw beginnen.
    func wis() {
        let welk = ritme
        vinkjes = vinkjes.filter { !$0.key.hasPrefix(welk.rawValue + "/") }
        let dag = datum
        Task { try? await Opslag.wisRitme(datum: dag, ritme: welk) }
    }

    // Bewaart de hele inhoud; geeft een reden terug als het misging, anders nil.
    func bewaar(_ ruw: Ruw) async -> String? {
        let nieuw = opgeschoond(ruw)
        do {
            try await Opslag.bewaarConfig(nieuw)
        } catch {
            return "Opslaan lukte niet (\(error.localizedDescription))."
        }
        inhoud = normaliseer(Json(nieuw))
        return nil
    }

    // ------------------------------------------------------------ meekijken ---

    private func zet(_ sleutel: String, _ aan: Bool) {
        if aan { vinkjes[sleutel] = true } else { vinkjes.removeValue(forKey: sleutel) }
    }

    private func volgMee() {
        stroom = Stroom(datum: datum) { [weak self] bericht in
            guard let self else { return }
            switch bericht {
            case let .begin(_, verse, gezet):
                self.fout = ""
                if !verse.isNiets { self.inhoud = normaliseer(verse) }
                self.vinkjes = gezet
            case let .inhoud(verse):
                if !verse.isNiets { self.inhoud = normaliseer(verse) }
            case let .vink(_, sleutel, aan):
                self.zet(sleutel, aan)
            case let .ritme(_, welk):
                self.vinkjes = self.vinkjes.filter { !$0.key.hasPrefix(welk.rawValue + "/") }
            }
        }
    }

    // Blijft de app een nacht openstaan, dan hoort hij morgen de volgende dag te
    // laten zien. De datum is genoeg; op de minuut hoeft niets bij te werken.
    // De klok loopt elke halve minuut door. Dat is niet alleen voor middernacht:
    // de agenda laat weg wat geweest is, en dan moet 'nu' ook overdag opschuiven,
    // anders staat er tot de volgende ochtend nog iets van vanmiddag.
    private func loopMee() {
        klok = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self else { return }
                let straks = Date()
                let andereDag = datumVan(straks) != self.datum
                self.nu = straks
                if andereDag {
                    self.stroom?.kijkNaar(self.datum)
                    await self.herlaad()
                }
            }
        }
    }
}
