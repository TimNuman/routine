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
    // Welke kant het volgende scherm vandaan komt: 1 van rechts, -1 van links.
    // De menubalk zet hem voordat hij `tab` omzet, zodat het scherm dezelfde
    // kant op schuift als waar je in de balk heen gaat.
    var tabRichting: Int = 1
    // Staat er een blad overheen? De menubalk zweeft boven de schermen en zou
    // anders over dat blad heen komen te liggen.
    var bladOpen = false
    // Op welk kind het ritme gefilterd staat, of nil voor iedereen. Staat hier
    // en niet in het scherm zelf, zodat een blik op de week hem niet wist.
    var alleen: String?
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
                ritme = kalender.component(.hour, from: Date()) >= c.avondVanaf ? .nacht : .dag
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
