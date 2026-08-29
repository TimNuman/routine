// Naar links vegen om iets weg te halen, in plaats van een rood knopje voor elke
// regel. Die knopjes stonden er altijd, ook als je niets wilde weghalen, en ze
// namen de plek in waar de emoji hoort.
//
// Er is geen `List` in deze schermen — de kaarten zijn glas met een eigen randje
// — dus `.swipeActions` kan niet. Dit is de kleinste eigen versie: de regel
// schuift mee naar links, en precies de strook die daardoor vrijkomt wordt rood.
// Dat is wat het simpel houdt: er hoeft niets ondoorzichtigs achter de regel te
// liggen, want de twee overlappen elkaar nooit.
import SwiftUI

struct Veegweg<Inhoudje: View>: View {
    var titel: String = "Weg"
    /// Staat hier een reden in, dan mag er niets weg en zegt de strook waarom.
    var beletsel: String? = nil
    let opWeg: () -> Void
    @ViewBuilder var inhoud: () -> Inhoudje

    @Environment(\.palet) private var palet
    @State private var x: CGFloat = 0
    // Waar deze veeg begon. Zonder dit telde de verschuiving bij zichzelf op —
    // `translation` loopt vanaf het aanraakpunt, dus zodra x eenmaal voorbij de
    // knopbreedte was werd die er elke tel opnieuw bij opgeteld en schoot hij
    // vanzelf door tot verwijderen. Precies wat er gebeurde: één bescheiden veeg
    // haalde een kind weg.
    @State private var begin: CGFloat?

    // Zo breed blijft hij openstaan als je hem laat staan.
    private let knop: CGFloat = 96
    // Hier voorbij hoef je niet meer los te laten om het te menen.
    private let meteen: CGFloat = 168

    var body: some View {
        inhoud()
            .offset(x: x)
            .overlay(alignment: .trailing) { strook }
            .contentShape(Rectangle())
            // Voorrang boven de knop die in de regel zit. Zonder dit wint die
            // knop: een veeg over een regel opende het bewerkscherm in plaats
            // van de rode strook te laten zien. Pas vanaf 18 punten beweging
            // pakt hij het over, dus een gewone tik komt nog gewoon aan.
            .highPriorityGesture(gebaar)
            // Staat hij open, dan sluit een tik hem weer — en gaat die tik niet
            // per ongeluk ook nog het bewerkscherm in.
            .overlay {
                if x != 0 {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dicht() }
                }
            }
            .onDisappear { x = 0 }
    }

    // Precies zo breed als wat de regel vrijmaakt, dus nooit eronder of eroverheen.
    @ViewBuilder
    private var strook: some View {
        let breed = max(0, -x)
        if breed > 0 {
            Button { weg() } label: {
                ZStack {
                    beletsel == nil ? ROOD : palet.zacht.opacity(0.55)
                    Text(beletsel ?? titel)
                        .letter(L.veegweg)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 6)
                        // Pas laten lezen als er ruimte voor is; anders staat er
                        // een woord tegen de rand geperst.
                        .opacity(Double(min(1, breed / 70)))
                }
                .frame(width: breed)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(beletsel != nil)
            .accessibilityLabel(beletsel ?? titel)
        }
    }

    private var gebaar: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { g in
                // Alleen naar links, en alleen als het duidelijk opzij is: hier
                // omheen zit een rol die verticaal wil.
                guard abs(g.translation.width) > abs(g.translation.height) else { return }
                let vanaf = begin ?? x
                if begin == nil { begin = x }
                x = min(0, max(-meteen - 40, vanaf + g.translation.width))
            }
            .onEnded { g in
                begin = nil
                guard abs(g.translation.width) > abs(g.translation.height) else {
                    dicht(); return
                }
                if beletsel != nil { dicht(); return }
                if -x > meteen { weg() }
                else if -x > 40 { withAnimation(Beweging.veer) { x = -knop } }
                else { dicht() }
            }
    }

    private func dicht() { withAnimation(Beweging.veer) { x = 0 } }

    private func weg() {
        guard beletsel == nil else { dicht(); return }
        Trilling.af()
        withAnimation(Beweging.kort) { x = 0 }
        opWeg()
    }
}
