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

            if !m.breed {
                Tabbalk(breed: false)
                    .frame(maxWidth: 492)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
            }
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
struct Hoofdscherm: View {
    @Environment(Gezin.self) private var gezin

    var body: some View {
        GeometryReader { ruimte in
            ZStack {
                switch gezin.tab {
                case .ritme: Ritmescherm()
                case .week: Weekscherm()
                case .instellingen: Instellingenscherm()
                }
            }
            .environment(\.maten, Maten(breedte: ruimte.size.width))
            .environment(\.palet, Palet(donker: gezin.avond))
            .animation(Beweging.nacht, value: gezin.avond)
        }
    }
}
