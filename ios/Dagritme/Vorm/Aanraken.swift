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

// Wisselen zonder afbraak. Een overgang die het oude weggooit en het nieuwe
// opbouwt gaat stuk zodra je snel heen en weer tikt: half binnengekomen
// elementen bevriezen en vertrekken als blok, en de andere kant begint van
// voren af aan. Daarom bestaan alle kanten permanent en onthoudt elk element
// gewoon waar het is — een tik verlegt alleen waar het heen wil, elk element
// een tel na het vorige. Wie halverwege terugtikt ziet alles omkeren vanaf
// waar het nu hangt.
struct Wissel: Equatable {
    /// Waar dit element in het golfje staat; telt door in de vertraging.
    var plek: Int
    /// Hoeveel plekken dit element van huis is: 0 is in beeld, -1 één scherm
    /// naar links, 1 één naar rechts. Doen er twee wissels tegelijk mee — een
    /// ritme op een tabblad dat zelf ook opzij staat — dan telt het gewoon op.
    var stand: CGFloat
    /// Hoe ver één plek opzij is: net voorbij de rand van het scherm.
    var uitwijk: CGFloat
}

extension View {
    /// `extra` telt door op de plek, voor wie meer dan één element uit dezelfde
    /// Wissel bedient (de kop en de kaart van een agendablok). De komtBinnen
    /// eronder is voor de allereerste keer in beeld; daarna speelt alleen nog
    /// het verleggen van het doel.
    @ViewBuilder
    func wisselplek(_ wissel: Wissel?, extra: Int = 0) -> some View {
        if let w = wissel {
            komtBinnen(w.plek + extra)
                .offset(x: w.stand * w.uitwijk)
                .animation(Beweging.entree.delay(Beweging.natikken(w.plek + extra)),
                           value: w.stand)
        } else {
            self
        }
    }
}
