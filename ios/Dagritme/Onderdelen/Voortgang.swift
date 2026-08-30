// Eén balkje per kind dat meeloopt met wat er af is. Vanaf drie kinderen naast
// elkaar wordt het te smal: dan twee per regel, net als op web.
//
// Het afvinken van één kaartje is een klein feestje (zie Rondje); hier zit het
// grote. Wie zijn laatste stap afvinkt krijgt zijn gezichtje omhoog, een glans
// die één keer over de volle balk loopt, en de telling in het groen. Dat is het
// enige moment in de app dat iets echt áf is, dus het mag hier opvallen.
//
// De tegels zijn ook de schakelaars per kind. Dat hoort hier: het is de enige
// plek op het scherm waar de kinderen naast elkaar staan, dus het is ook de plek
// waar je aanwijst wie er meedoet. Wat een tik precies doet staat bij
// Gezin.wisselKind; hier gaat het alleen om hoe het eruitziet.
import SwiftUI

struct Deel {
    var af: Int = 0
    var totaal: Int = 0
    var breuk: Double { totaal > 0 ? Double(af) / Double(totaal) : 0 }
    var klaar: Bool { totaal > 0 && af >= totaal }
}

struct Voortgang: View {
    let mensen: [Persoon]
    let deel: [String: Deel]
    var marge: CGFloat
    /// Wie er meedoen. Zonder filter zijn dat ze allemaal.
    var zichtbaar: Set<String> = []
    /// Staat er iemand uit? Alleen dan mag het scherm dat laten zien.
    var gefilterd: Bool = false
    var opKies: ((String) -> Void)? = nil

    private var velen: Bool { mensen.count > 2 }

    var body: some View {
        Glas(radius: 26) {
            if velen {
                VStack(spacing: 0) {
                    ForEach(Array(rijen.enumerated()), id: \.offset) { (rij, paar) in
                        HStack(spacing: 0) {
                            ForEach(Array(paar.enumerated()), id: \.element.id) { (kolom, persoon) in
                                Vak(persoon: persoon, mijn: deel[persoon.id] ?? Deel(),
                                    links: kolom > 0, boven: rij > 0,
                                    aan: !gefilterd || zichtbaar.contains(persoon.id),
                                    gefilterd: gefilterd, opKies: opKies)
                                    .frame(maxWidth: .infinity)
                            }
                            if paar.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(mensen.enumerated()), id: \.element.id) { (i, persoon) in
                        Vak(persoon: persoon, mijn: deel[persoon.id] ?? Deel(),
                            links: i > 0, boven: false,
                            aan: !gefilterd || zichtbaar.contains(persoon.id),
                            gefilterd: gefilterd, opKies: opKies)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.top, marge)
    }

    private var rijen: [[Persoon]] {
        stride(from: 0, to: mensen.count, by: 2).map {
            Array(mensen[$0..<min($0 + 2, mensen.count)])
        }
    }
}

private struct Vak: View {
    let persoon: Persoon
    let mijn: Deel
    let links: Bool
    let boven: Bool
    var aan: Bool = true
    var gefilterd: Bool = false
    var opKies: ((String) -> Void)?

    @Environment(\.palet) private var palet
    @State private var pop: CGFloat = 1
    @State private var geweest = false

    // Aangewezen: er staat iemand uit en ik hoor bij wie er over is.
    private var uitgelicht: Bool { gefilterd && aan }
    // Uitgezet: ik sta er nog om op teruggetikt te kunnen worden.
    private var opzij: Bool { !aan }

    var body: some View {
        if let opKies {
            Button { opKies(persoon.id) } label: { vak }
                .buttonStyle(.druk(0.96))
                // Zeggen wat de tik gaat doen, niet wat er nu staat — want dat
                // verschilt: vanuit alles-aan is het een solo.
                .accessibilityLabel(etiket)
                .accessibilityAddTraits(aan ? [.isButton, .isSelected] : .isButton)
        } else {
            vak
        }
    }

    private var etiket: String {
        if !gefilterd { return "Alleen \(persoon.naam) tonen" }
        return aan ? "\(persoon.naam) verbergen" : "\(persoon.naam) er weer bij"
    }

    private var vak: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(zacht(persoon.kleur, mijn.klaar ? 0.30 : 0.18))
                Text(persoon.emoji).font(.system(size: 26))
            }
            .frame(width: 46, height: 46)
            .scaleEffect(pop)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(persoon.naam)
                        .letter(L.naam)
                        // Wie aan staat draagt zijn eigen kleur: dat zegt in één
                        // oogopslag waar de kaartjes eronder over gaan.
                        .foregroundStyle(uitgelicht ? Color(hex: persoon.kleur) : palet.inkt)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(mijn.af)/\(mijn.totaal)")
                        .letter(L.telling)
                        .foregroundStyle(mijn.klaar ? GROEN : palet.zacht)
                        // De cijfers rollen om in plaats van te verspringen —
                        // ook het totaal, want de tegel blijft staan als het
                        // ritme omgaat en de telling van de andere kant komt.
                        .contentTransition(.numericText(value: Double(mijn.af)))
                        .animation(Beweging.kort, value: mijn.af)
                        .animation(Beweging.kort, value: mijn.totaal)
                }
                Goot(breuk: mijn.breuk, klaar: mijn.klaar, kleur: Color(hex: persoon.kleur))
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .overlay(alignment: .leading) {
            if links { Rectangle().fill(palet.scheiding).frame(width: 1) }
        }
        .overlay(alignment: .top) {
            if boven { Rectangle().fill(palet.scheiding).frame(height: 1) }
        }
        // Wie niet meedoet zakt naar de achtergrond in plaats van te verdwijnen:
        // je moet hem kunnen aantikken om weer terug te komen.
        .opacity(opzij ? 0.42 : 1)
        .grayscale(opzij ? 0.85 : 0)
        .contentShape(Rectangle())
        .animation(Beweging.rustig, value: mijn.klaar)
        .animation(Beweging.kort, value: aan)
        .animation(Beweging.kort, value: gefilterd)
        .onChange(of: mijn.klaar) { _, nieuw in
            guard geweest, nieuw else { return }
            Trilling.klaar()
            withAnimation(Beweging.indeuk) { pop = 0.90 }
            withAnimation(Beweging.wip.delay(0.08)) { pop = 1.20 }
            withAnimation(Beweging.uitwip.delay(0.30)) { pop = 1 }
        }
        .onAppear { geweest = true }
    }
}

private struct Goot: View {
    let breuk: Double
    let klaar: Bool
    let kleur: Color
    @Environment(\.palet) private var palet

    @State private var glans = 0
    @State private var geweest = false

    var body: some View {
        GeometryReader { ruimte in
            let breedte = ruimte.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(palet.goot)
                // Een balk die naveert leest als 'bijna klaar, toch niet'; dus
                // gewoon lopen, maar wel met een veer eronder in plaats van een
                // rechte lijn — anders zet hij zich neer als een schuifdeur.
                Capsule()
                    .fill(klaar ? GROEN : kleur)
                    .frame(width: max(0, min(1, breuk)) * breedte)
                    .animation(Beweging.veer, value: breuk)
                    .animation(Beweging.rustig, value: klaar)

                if glans > 0 {
                    Glansje(breedte: breedte).id(glans)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 7)
        .onChange(of: klaar) { _, nieuw in
            // Pas nadat de balk zelf vol is; ervoor zou de glans over een balk
            // lopen die er nog niet staat.
            guard geweest, nieuw else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                glans &+= 1
            }
        }
        .onAppear { geweest = true }
    }
}

// Eén lichtstreep die over de volle balk loopt en er aan de andere kant weer af.
// Staat in een eigen view zodat de ouder hem met `.id(...)` opnieuw kan starten.
private struct Glansje: View {
    let breedte: CGFloat
    @State private var x: CGFloat = -0.35

    var body: some View {
        LinearGradient(
            colors: [.white.opacity(0), .white.opacity(0.75), .white.opacity(0)],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(width: max(24, breedte * 0.35))
        .offset(x: x * breedte)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.62)) { x = 1.05 }
        }
    }
}
