// Wat een tik oplevert: hij wordt kleiner onder je vinger, en je voelt hem.
//
// Dit was de grootste bron van houterigheid — bijna elke knop stond op
// `.buttonStyle(.plain)`, en dat is letterlijk "doe niets". Je tikt, en er
// gebeurt pas iets als het scherm al veranderd is. Eén stijl voor alles zorgt
// dat elke knop in de app zich hetzelfde gedraagt.
import SwiftUI
import UIKit

struct Druk: ButtonStyle {
    var schaal: CGFloat = 0.96
    var flauwte: Double = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? schaal : 1)
            .opacity(configuration.isPressed ? flauwte : 1)
            .animation(configuration.isPressed ? Beweging.druk : Beweging.los,
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == Druk {
    // Voor de brede dingen: een kaart, een rij, een knop over de volle breedte.
    static var druk: Druk { Druk() }
    // Kleine dingen moeten verder inzakken, anders zie je er niets van.
    static var drukje: Druk { Druk(schaal: 0.90, flauwte: 0.75) }
    static func druk(_ schaal: CGFloat, flauwte: Double = 1) -> Druk {
        Druk(schaal: schaal, flauwte: flauwte)
    }
}

// Wat je voelt. Kort en licht gehouden: dit is een afvinklijstje voor kinderen,
// geen spelcomputer. Alleen het afvinken zelf en het uitkomen van een rijtje
// krijgen echt iets; de rest is de zachtste tik die het toestel kan.
@MainActor
enum Trilling {
    private static let licht = UIImpactFeedbackGenerator(style: .light)
    private static let stevig = UIImpactFeedbackGenerator(style: .rigid)
    private static let zacht = UIImpactFeedbackGenerator(style: .soft)
    private static let keus = UISelectionFeedbackGenerator()
    private static let bericht = UINotificationFeedbackGenerator()

    // Vlak voor een tik aankondigen scheelt de vertraging van het opstarten.
    static func klaarzetten() {
        stevig.prepare()
        zacht.prepare()
    }

    /// Een vakje aangezet.
    static func af() { stevig.impactOccurred(intensity: 0.9) }
    /// Een vakje weer uitgezet: merkbaar minder feestelijk.
    static func uit() { zacht.impactOccurred(intensity: 0.45) }
    /// Iemand is helemaal klaar met het ritme.
    static func klaar() { bericht.notificationOccurred(.success) }
    /// Een andere dag, een ander tabblad, een andere kant van de schakelaar.
    static func keuze() { keus.selectionChanged() }
    /// Iets kleins bevestigd.
    static func tik() { licht.impactOccurred(intensity: 0.6) }
}

// Wordt er op dit moment tussen schermen geveegd? De rol eronder moet dan
// stilstaan: anders scrol je verticaal weg terwijl je al horizontaal onderweg
// bent, en komt het nieuwe scherm binnen op een plek waar je niet om vroeg.
private struct VeegtSleutel: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var veegt: Bool {
        get { self[VeegtSleutel.self] }
        set { self[VeegtSleutel.self] = newValue }
    }
}

// Binnenkomen: iets glijdt op zijn plek, met een vertraging naar zijn volgorde.
// Bovenste eerst, onderste laatst.
//
// Bewust één keer per identiteit: in een `LazyVGrid` komt `onAppear` opnieuw
// langs zodra je terugscrolt, en dan zou de halve lijst opnieuw naar binnen
// vliegen. Wie het wél opnieuw wil laten spelen — een andere week, een ander
// ritme — geeft dat blok een nieuwe `.id(...)`, dan is het een nieuw ding en
// begint dit vanzelf overnieuw.
struct Binnenkomst: ViewModifier {
    var index: Int = 0
    /// -1 komt van links, 1 van rechts, 0 recht van onderen.
    var vanaf: CGFloat = 0
    var afstand: CGFloat = 22
    var animatie: Animation = Beweging.kort

    @State private var binnen = false

    func body(content: Content) -> some View {
        content
            .opacity(binnen ? 1 : 0)
            .scaleEffect(binnen ? 1 : 0.95, anchor: .top)
            .offset(x: binnen ? 0 : afstand * vanaf,
                    y: binnen ? 0 : (vanaf == 0 ? 12 : 0))
            .onAppear {
                guard !binnen else { return }
                withAnimation(animatie.delay(Beweging.natikken(index))) { binnen = true }
            }
    }
}

extension View {
    func komtBinnen(_ index: Int = 0, vanaf: CGFloat = 0,
                    afstand: CGFloat = 22, animatie: Animation = Beweging.kort) -> some View {
        modifier(Binnenkomst(index: index, vanaf: vanaf, afstand: afstand, animatie: animatie))
    }

    /// Van tabblad wisselen. Bewust een klein zetje in plaats van een hele
    /// schuif: elk scherm brengt zijn eigen lucht en zijn eigen menubalk mee, en
    /// die staan tijdens de overgang even allebei in beeld. Een halve slag over
    /// het scherm zou dat laten zien; 34 punten en een overvloeier niet.
    func wisseltMee(_ richting: CGFloat) -> some View {
        transition(.asymmetric(
            insertion: .offset(x: 34 * richting).combined(with: .opacity),
            removal: .offset(x: -34 * richting).combined(with: .opacity)
        ))
    }

    /// Oud gaat de ene kant uit, nieuw komt van de andere. `richting` is 1 als je
    /// vooruit gaat (oud naar links) en -1 als je terug gaat.
    func schuiftMee(_ richting: CGFloat) -> some View {
        transition(.asymmetric(
            insertion: .move(edge: richting >= 0 ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: richting >= 0 ? .leading : .trailing)
                .combined(with: .opacity)
        ))
    }
}
