// Precies zoals de webversie: het gezichtje staat er altijd, maar grijs en flauw
// zolang het niet af is. Afvinken geeft het zijn kleur terug en zet er een groene
// ring omheen. Geen vinkje dat het gezicht wegduwt.
//
// Dit is het enige moment in de app waarop iemand iets bereikt, dus hier mag het
// wat kosten. Vier dingen tegelijk, allemaal binnen een halve seconde:
//
//   indeuken   0,10 s   het rondje zakt in onder je vinger — dat is de aanloop
//   opwippen   0,34 s   hij schiet door tot 122% en veert terug, met een scheve tik
//   ring       0,30 s   de groene ring valt van 135% strak om het gezichtje heen
//   vonken     0,52 s   zes stipjes vliegen weg en doven onderweg
//
// De volgorde is wat het gevoel maakt: eerst kleiner, dán groot. Zonder die
// indeuk is een pop alleen maar groot worden, en dat leest als opzwellen in
// plaats van als springen.
import SwiftUI

struct Rondje: View {
    let persoon: Persoon
    let aan: Bool
    var maat: CGFloat = 40
    var gezicht: CGFloat = 34
    var teken: CGFloat = 21
    let opTik: () -> Void

    @Environment(\.palet) private var palet
    @State private var pop: CGFloat = 1
    @State private var draai: Double = 0
    @State private var ingedrukt = false
    @State private var geweest = false
    @State private var feest = 0
    // Of ík het aanzette, of dat het van een andere telefoon binnenkwam. Het
    // beeld doet in allebei de gevallen hetzelfde — leuk om te zien dat er
    // iemand anders bezig is — maar trillen doet alleen het toestel in je hand.
    @State private var zelf = false

    var body: some View {
        ZStack {
            if feest > 0 {
                Vonken(kleur: GROEN, straal: gezicht * 0.78)
                    .id(feest)
            }

            // De ring ligt eromheen en valt er in één beweging strak omheen.
            Circle()
                .strokeBorder(GROEN, lineWidth: 2.5)
                .frame(width: gezicht + 5, height: gezicht + 5)
                .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 4)
                .opacity(aan ? 1 : 0)
                .scaleEffect(aan ? 1 : 1.35)

            Circle()
                .fill(zacht(persoon.kleur, 0.16))
                .overlay(Circle().strokeBorder(randkleur, lineWidth: 1.5))
                .frame(width: gezicht, height: gezicht)
                .overlay {
                    Text(persoon.emoji)
                        .font(.system(size: teken))
                        .grayscale(aan ? 0 : 1)
                }
                .opacity(aan ? 1 : 0.4)
        }
        .frame(width: maat, height: maat)
        .scaleEffect(pop * (ingedrukt ? 0.88 : 1))
        .rotationEffect(.degrees(draai))
        .contentShape(Circle())
        .animation(aan ? Beweging.veer : Beweging.terug, value: aan)
        .animation(ingedrukt ? Beweging.druk : Beweging.los, value: ingedrukt)
        .onTapGesture {
            zelf = true
            opTik()
        }
        // Indrukken mag een tik niet in de weg zitten: dit voelt alleen of er een
        // vinger op staat.
        .onLongPressGesture(minimumDuration: 2, maximumDistance: 8) { } onPressingChanged: { bezig in
            ingedrukt = bezig
            if bezig { Trilling.klaarzetten() }
        }
        .onChange(of: aan) { _, nieuw in
            // Niet bij het eerste tekenen van het scherm: dan zou de hele lijst
            // bij het opstarten staan te knallen.
            guard geweest else { return }
            if nieuw { vier() } else { draaiTerug() }
            zelf = false
        }
        .onAppear { geweest = true }
        .accessibilityElement()
        .accessibilityLabel(persoon.naam)
        .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
    }

    private func vier() {
        if zelf { Trilling.af() }
        feest &+= 1
        withAnimation(Beweging.indeuk) { pop = 0.86 }
        withAnimation(Beweging.wip.delay(0.10)) { pop = 1.22; draai = -9 }
        withAnimation(Beweging.uitwip.delay(0.30)) { pop = 1; draai = 0 }
    }

    private func draaiTerug() {
        if zelf { Trilling.uit() }
        withAnimation(Beweging.terug) { pop = 1; draai = 0 }
    }

    // Het randje in de uit-stand verschiet mee met de avond, net als het glas;
    // aan is er geen randje nodig, want de ring doet het werk.
    private var randkleur: Color {
        aan ? .clear : (palet.donker ? .white.opacity(0.18) : INKT.opacity(0.14))
    }
}

// Zes stipjes die uit het midden wegvliegen en onderweg doven. Ze zitten in een
// eigen view met een eigen `onAppear`, zodat de ouder hem met `.id(...)` opnieuw
// kan laten spelen; anders zou een tweede tik binnen een halve seconde niets
// doen, omdat de waarde dan al op zijn eindstand staat.
private struct Vonken: View {
    let kleur: Color
    let straal: CGFloat

    @State private var uit: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let hoek = Double(i) / 6 * 2 * .pi - .pi / 2
                Circle()
                    .fill(kleur)
                    .frame(width: 5, height: 5)
                    .scaleEffect(1 - uit * 0.65)
                    // In het eerste stukje opkomen en daarna uitdoven, zodat er
                    // in de ruststand niets te zien is.
                    .opacity(Double(min(1, uit * 7) * (1 - uit)))
                    .offset(x: CGFloat(cos(hoek)) * straal * uit,
                            y: CGFloat(sin(hoek)) * straal * uit)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(Beweging.vonk) { uit = 1 } }
    }
}
