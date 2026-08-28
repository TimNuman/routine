// Precies zoals de webversie: het gezichtje staat er altijd, maar grijs en flauw
// zolang het niet af is. Afvinken geeft het zijn kleur terug en zet er een groene
// ring omheen. Geen vinkje dat het gezicht wegduwt.
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
    @State private var ingedrukt = false
    @State private var geweest = false

    var body: some View {
        ZStack {
            // De ring ligt eromheen en zet zich er in één beweging omheen.
            Circle()
                .strokeBorder(GROEN, lineWidth: 2.5)
                .frame(width: gezicht + 5, height: gezicht + 5)
                .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 4)
                .opacity(aan ? 1 : 0)
                .scaleEffect(aan ? 1 : 0.9)

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
        .scaleEffect(pop * (ingedrukt ? 0.9 : 1))
        .contentShape(Circle())
        .animation(Beweging.snel, value: aan)
        .animation(Beweging.veer, value: ingedrukt)
        .onTapGesture { opTik() }
        // Indrukken mag geen tik in de weg zitten: dit voelt alleen of er een
        // vinger op staat.
        .onLongPressGesture(minimumDuration: 2, maximumDistance: 8) { } onPressingChanged: { bezig in
            ingedrukt = bezig
        }
        .onChange(of: aan) { _, nieuw in
            // Alleen bij het aanzetten een wipje, en alleen als jij het aanzet —
            // niet bij het eerste tekenen van het scherm.
            guard nieuw, geweest else { return }
            withAnimation(Beweging.wip) { pop = 1.16 }
            withAnimation(Beweging.veer.delay(0.09)) { pop = 1 }
        }
        .onAppear { geweest = true }
        .accessibilityElement()
        .accessibilityLabel(persoon.naam)
        .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
    }

    // Het randje in de uit-stand verschiet mee met de avond, net als het glas;
    // aan is er geen randje nodig, want de ring doet het werk.
    private var randkleur: Color {
        aan ? .clear : (palet.donker ? .white.opacity(0.18) : INKT.opacity(0.14))
    }
}
