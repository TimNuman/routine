// Het kader dat elke pagina deelt: de lucht erachter, de kopregel en het menu.
// De avondkleuren horen alleen bij het ritme, dus de andere pagina's blijven
// licht — net als op web, waar body.nacht alleen op die pagina staat.
//
// De maten en het palet komen van boven (zie Hoofdscherm), zodat een scherm ze
// zelf ook kan uitlezen: wie ze hier pas zou zetten, zou ze in het scherm
// eromheen nog niet hebben.
import SwiftUI

// Hoeveel schermen dit tabblad van het gekozen tabblad af staat: 0 is in
// beeld, -1 één naar links, 1 één naar rechts. Alle drie de schermen bestaan
// permanent (zie Tabinhoud); hieraan leest een scherm af waar zijn elementen
// heen willen.
private struct TabstandSleutel: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabstand: CGFloat {
        get { self[TabstandSleutel.self] }
        set { self[TabstandSleutel.self] = newValue }
    }
}

struct Scherm<Inhoudje: View>: View {
    let titel: String
    let onder: String
    var midden: AnyView? = nil
    /// Komt naast de datum te staan, op dezelfde regel.
    var naast: AnyView? = nil
    var smal: Bool = false
    @ViewBuilder var inhoud: () -> Inhoudje

    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet
    @Environment(\.tabstand) private var tabstand

    var body: some View {
        ZStack(alignment: .bottom) {
            // De lucht staat in Hoofdscherm en niet hier: zou elk scherm zijn
            // eigen achtergrond meebrengen, dan schuift die mee bij het wisselen.
            // De kaartjes bewegen, de lucht verschiet alleen van kleur.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kopregel

                    if gezin.inhoud == nil && gezin.fout.isEmpty {
                        ProgressView()
                            .tint(ORANJE)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                            .wisselplek(tabplek(1))
                    }
                    if !gezin.fout.isEmpty {
                        Text("De inhoud laden lukte niet (\(gezin.fout)).")
                            .letter(Letter(font: L.nunitoZwaar(14)))
                            .foregroundStyle(ROOD)
                            .padding(.top, 32)
                            .wisselplek(tabplek(1))
                    }

                    // De week en de instellingen lezen als een lijst; die blijven
                    // smal, ook al is het scherm breed.
                    inhoud()
                        .frame(maxWidth: smal && m.breed ? 640 : .infinity, alignment: .leading)
                }
                .padding(.horizontal, m.gootje)
                .padding(.top, m.bovenaan)
                .padding(.bottom, m.onderaan)
                .frame(maxWidth: m.maxBreed)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await gezin.herlaad() }

            // De zwevende menubalk staat niet hier maar in Hoofdscherm — zie
            // daar waarom. Op een breed scherm hoort hij wél bij de kopregel,
            // want daar is hij onderdeel van de bladspiegel en niet iets dat
            // erover zweeft.
        }
    }

    // Hoe de kopregel meedoet aan de tabwissel: als eerste, want hij staat
    // bovenaan het golfje.
    private func tabplek(_ plek: Int) -> Wissel {
        Wissel(plek: plek, stand: tabstand, uitwijk: m.breedte + 60)
    }

    // Is er ruimte, dan staan de schakelaar en het menu naast de titel.
    @ViewBuilder
    private var kopregel: some View {
        // Baloo heeft hoge stokken en diepe staarten, dus de regels staan al ver
        // uit elkaar voordat er ruimte tussen zit; vandaar de negatieve maat.
        let namen = VStack(alignment: .leading, spacing: -3) {
            Text(titel).letter(L.titel).foregroundStyle(palet.inkt)
            HStack(spacing: 10) {
                Text(onder).letter(L.onder).foregroundStyle(palet.onder)
                if let naast { naast }
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, m.insprong)

        if m.breed {
            HStack(alignment: .center, spacing: 24) {
                namen.frame(maxWidth: .infinity, alignment: .leading)
                    .wisselplek(tabplek(0))
                // De menubalk reist niet mee: dat is het ding waarop je tikt,
                // en elk scherm draagt hier zijn eigen exemplaar.
                Tabbalk(breed: true).frame(width: m.zijkolom)
            }
            .overlay(alignment: .center) {
                if let midden { midden.frame(width: 250).wisselplek(tabplek(0)) }
            }
            .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                namen
                if let midden { midden }
            }
            .wisselplek(tabplek(0))
        }
    }
}

// Welk scherm er openstaat, met de maten en de kleuren eromheen. Alles wat
// daaronder hangt — ook de bladen die eroverheen komen — leest ze hier uit.
struct Hoofdscherm: View {
    @Environment(Gezin.self) private var gezin

    var body: some View {
        GeometryReader { ruimte in
            let m = Maten(breedte: ruimte.size.width)

            ZStack(alignment: .bottom) {
                // De lucht van de app zelf. Elk scherm bracht er eerst een eigen
                // mee, en die schoof dan mee weg bij het wisselen.
                Lucht(donker: gezin.avond)

                Tabinhoud(tab: gezin.tab)

                // De menubalk blijft staan terwijl het scherm eronder wisselt.
                // Dat is de voorwaarde voor het oranje vlak dat van knop naar knop
                // schuift: zou de balk per scherm opnieuw gemaakt worden, dan is
                // er niets om vandaan te komen.
                if !m.breed {
                    Tabbalk(breed: false)
                        .frame(maxWidth: 492)
                        .padding(.horizontal, Tabbalk.rand)
                        // Negatief, want de ZStack zet hem boven de veilige zone
                        // neer en daar moet hij juist doorheen: 8 punten van de
                        // echte schermrand, net als links en rechts.
                        .padding(.bottom, Tabbalk.rand - Randen.onder)
                        .ignoresSafeArea(.container, edges: .bottom)
                        // Komt er een blad omhoog, dan gaat de balk mee naar
                        // beneden — hij hoort bij de schermen, niet bij wat
                        // eroverheen staat.
                        .opacity(gezin.bladOpen ? 0 : 1)
                        .offset(y: gezin.bladOpen ? 30 : 0)
                        .animation(Beweging.bladOp, value: gezin.bladOpen)
                        .allowsHitTesting(!gezin.bladOpen)
                }
            }
            .environment(\.maten, m)
            .environment(\.palet, Palet(donker: gezin.avond))
            .animation(Beweging.nacht, value: gezin.avond)
        }
    }
}

// Alle drie de schermen bestaan permanent, naast elkaar in de volgorde van het
// menu; alleen het gekozen scherm staat in beeld. Er wisselt dus geen tak om —
// elk scherm leest zijn `tabstand` en verlegt daarmee per element het doel,
// net als de ochtend/avond-wissel. Zo kan snel tussen tabbladen tikken niet
// stotteren, en onthoudt elk scherm ook gewoon waar je gescrold was.
private struct Tabinhoud: View {
    let tab: Tab

    var body: some View {
        ZStack {
            luik(.ritme) { Ritmescherm() }
            luik(.week) { Weekscherm() }
            luik(.instellingen) { Instellingenscherm() }
        }
    }

    private func luik(_ s: Tab, @ViewBuilder _ scherm: () -> some View) -> some View {
        let hier = tab == s
        return scherm()
            .environment(\.tabstand, CGFloat(nummer(s) - nummer(tab)))
            // Wat binnenkomt hoort óver wat vertrekt te reizen, niet eronder.
            .zIndex(hier ? 1 : 0)
            .allowsHitTesting(hier)
            .accessibilityHidden(!hier)
    }

    private func nummer(_ s: Tab) -> Int {
        Tab.allCases.firstIndex(of: s) ?? 0
    }
}

// Van tabblad wisselen — op één plek, zodat de menubalk en al het andere
// hetzelfde doen.
extension Gezin {
    func gaNaar(_ nieuw: Tab) {
        guard nieuw != tab else { return }
        Trilling.keuze()
        withAnimation(Beweging.kort) { tab = nieuw }
    }
}
