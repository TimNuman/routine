// Het kader dat elke pagina deelt: de lucht erachter, de kopregel en het menu.
// De avondkleuren horen alleen bij het ritme, dus de andere pagina's blijven
// licht — net als op web, waar body.nacht alleen op die pagina staat.
//
// De maten en het palet komen van boven (zie Hoofdscherm), zodat een scherm ze
// zelf ook kan uitlezen: wie ze hier pas zou zetten, zou ze in het scherm
// eromheen nog niet hebben.
import SwiftUI

struct Scherm<Inhoudje: View>: View {
    let titel: String
    let onder: String
    var midden: AnyView? = nil
    var smal: Bool = false
    @ViewBuilder var inhoud: () -> Inhoudje

    @Environment(Gezin.self) private var gezin
    @Environment(\.maten) private var m
    @Environment(\.palet) private var palet

    var body: some View {
        ZStack(alignment: .bottom) {
            Lucht(donker: gezin.avond)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kopregel

                    if gezin.inhoud == nil && gezin.fout.isEmpty {
                        ProgressView()
                            .tint(ORANJE)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    }
                    if !gezin.fout.isEmpty {
                        Text("De inhoud laden lukte niet (\(gezin.fout)).")
                            .letter(Letter(font: L.nunitoZwaar(14)))
                            .foregroundStyle(ROOD)
                            .padding(.top, 32)
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

    // Is er ruimte, dan staan de schakelaar en het menu naast de titel.
    @ViewBuilder
    private var kopregel: some View {
        let namen = VStack(alignment: .leading, spacing: 3) {
            Text(titel).letter(L.titel).foregroundStyle(palet.inkt)
            Text(onder).letter(L.onder).foregroundStyle(palet.onder)
        }
        .padding(.leading, m.insprong)

        if m.breed {
            HStack(alignment: .center, spacing: 24) {
                namen.frame(maxWidth: .infinity, alignment: .leading)
                Tabbalk(breed: true).frame(width: m.zijkolom)
            }
            .overlay(alignment: .center) {
                if let midden { midden.frame(width: 250) }
            }
            .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                namen
                if let midden { midden }
            }
        }
    }
}

// Welk scherm er openstaat, met de maten en de kleuren eromheen. Alles wat
// daaronder hangt — ook de bladen die eroverheen komen — leest ze hier uit.
//
// Hier zit ook het vegen tussen de schermen. Het scherm volgt je vinger een
// stukje mee — genoeg om te voelen dat er iets achter zit — en laat aan het eind
// van de rij merken dat het ophoudt door nog maar een derde zo ver mee te geven.
// Loslaten doet hetzelfde als op de balk drukken.
struct Hoofdscherm: View {
    @Environment(Gezin.self) private var gezin

    @State private var veeg: CGFloat = 0

    var body: some View {
        GeometryReader { ruimte in
            let m = Maten(breedte: ruimte.size.width)

            ZStack(alignment: .bottom) {
                // De lucht van de app zelf, achter het scherm dat meeschuift.
                // Zonder deze zou je onder je vinger het kale venster zien: elk
                // scherm brengt zijn eigen lucht mee, en die schuift mee weg.
                Lucht(donker: gezin.avond)

                Group {
                    switch gezin.tab {
                    case .ritme: Ritmescherm()
                    case .week: Weekscherm()
                    case .instellingen: Instellingenscherm()
                    }
                }
                .id(gezin.tab)
                .wisseltMee(CGFloat(gezin.tabRichting))
                .offset(x: veeg)

                // De menubalk blijft staan terwijl het scherm eronder wisselt.
                // Dat is niet alleen rustiger — het is de voorwaarde voor het
                // oranje vlak dat van knop naar knop schuift: zou de balk per
                // scherm opnieuw gemaakt worden, dan is er niets om vandaan te
                // komen en verspringt hij toch.
                if !m.breed {
                    Tabbalk(breed: false)
                        .frame(maxWidth: 492)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
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
            // Naast de rol in plaats van eroverheen: een veeg omhoog blijft
            // scrollen, en pas als je duidelijk opzij gaat doen wij iets.
            .simultaneousGesture(veegbeweging)
        }
    }

    private var veegbeweging: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { g in
                guard mag(g.translation) else { return }
                veeg = rek(g.translation.width)
            }
            .onEnded(klaar)
    }

    // Alleen als het duidelijk opzij is, en niet terwijl er een blad overheen
    // staat — daar veeg je in het blad zelf.
    private func mag(_ verzet: CGSize) -> Bool {
        !gezin.bladOpen && abs(verzet.width) > abs(verzet.height)
    }

    // Meegeven met je vinger, maar niet één op één: dat leest als een pagina die
    // al om is terwijl je nog vasthoudt. Aan het eind van de rij is er niets om
    // heen te gaan, en dan voelt het als een muur.
    private func rek(_ dx: CGFloat) -> CGFloat {
        let kan = gezin.buur(dx < 0 ? 1 : -1) != nil
        return dx * (kan ? 0.42 : 0.12)
    }

    private func klaar(_ g: DragGesture.Value) {
        let dx = g.translation.width
        let doorschot = g.predictedEndTranslation.width
        // Een korte tik met vaart telt net zo goed als een lange trage haal.
        let genoeg = abs(dx) > 70 || abs(doorschot) > 190
        let heen = gezin.buur(doorschot < 0 ? 1 : -1)

        // Allebei met dezelfde beweging, zodat het teruggeven van de veeg en het
        // schuiven van het scherm één geheel zijn.
        withAnimation(Beweging.schuif) { veeg = 0 }
        guard mag(g.translation), genoeg, let heen else { return }
        gezin.gaNaar(heen)
    }
}

// Van tabblad wisselen — of je nu op de balk drukt of veegt. Op één plek, zodat
// de richting waarin het scherm vertrekt altijd klopt met de volgorde van de
// knoppen.
extension Gezin {
    func gaNaar(_ nieuw: Tab) {
        guard nieuw != tab else { return }
        let heen = Tab.allCases.firstIndex(of: nieuw) ?? 0
        let vandaan = Tab.allCases.firstIndex(of: tab) ?? 0
        tabRichting = heen > vandaan ? 1 : -1
        Trilling.keuze()
        withAnimation(Beweging.schuif) { tab = nieuw }
    }

    /// Het tabblad `stap` plekken verderop, of nil als je aan het eind zit.
    func buur(_ stap: Int) -> Tab? {
        guard let nu = Tab.allCases.firstIndex(of: tab) else { return nil }
        let i = nu + stap
        return Tab.allCases.indices.contains(i) ? Tab.allCases[i] : nil
    }
}
