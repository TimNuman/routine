// Alle timing op één plek, zodat het overal hetzelfde aanvoelt.
//
// De regel: snel klaar en nauwelijks doorschieten. Een veer die naschommelt
// voelt traag, ook als hij kort is — het oog wacht tot hij stilstaat. Dus hoge
// stijfheid, veel demping, en alleen op het moment van aantikken een wipje.
import SwiftUI

enum Beweging {
    static let snel = Animation.easeInOut(duration: 0.11)
    static let kort = Animation.easeOut(duration: 0.16)
    static let rustig = Animation.easeOut(duration: 0.22)

    // Komt in ~150 ms tot stilstand zonder zichtbaar na te veren.
    static let veer = Animation.interpolatingSpring(mass: 0.5, stiffness: 420, damping: 26)

    // Het enige plekje waar het mag wippen: het pop-je bij het afvinken.
    static let wip = Animation.interpolatingSpring(mass: 0.4, stiffness: 700, damping: 11)

    // Ochtend naar avond gaat in één beweging, en alles gaat tegelijk mee.
    static let nacht = Animation.easeInOut(duration: 0.42)

    // Kaartjes komen na elkaar binnen, maar met een korte tik ertussen en een
    // plafond — anders zit je te wachten tot de onderste er is.
    static func natikken(_ i: Int, stap: Double = 0.022, hoogste: Double = 0.22) -> Double {
        min(Double(i) * stap, hoogste)
    }
}
