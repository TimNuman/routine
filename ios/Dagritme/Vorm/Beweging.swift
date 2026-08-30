// Alle timing op één plek, zodat het overal hetzelfde aanvoelt.
//
// De regel is bijgesteld. Eerst stond hier "nauwelijks doorschieten", en dat is
// precies waarom het houterig werd: een veer die helemaal niet doorschiet is
// niet rustig, die is dood — het oog ziet een vlak dat verspringt in plaats van
// iets dat beweegt. Een klein overschot (`extraBounce`) leest als levend,
// zolang het kort is. Dus: kort, en net genoeg tik.
//
// De tweede regel: hoe groter het ding, hoe langer het mag duren. Een rondje is
// in 0,3 s klaar, een half scherm mag er 0,4 over doen.
import SwiftUI

enum Beweging {
    // -------------------------------------------------------------- de basis ---
    static let snel = Animation.snappy(duration: 0.16, extraBounce: 0.05)
    static let kort = Animation.snappy(duration: 0.26, extraBounce: 0.10)
    static let veer = Animation.snappy(duration: 0.30, extraBounce: 0.16)
    // Waar niets mag wippen: een balk die vult, een kleur die verschiet.
    static let rustig = Animation.smooth(duration: 0.32)

    // ------------------------------------------------------------- aanraken ---
    // Indrukken gaat meteen en zonder veer; loslaten mag terugveren, want dát is
    // het moment waarop je voelt dat het knop is.
    static let druk = Animation.snappy(duration: 0.12, extraBounce: 0)
    static let los = Animation.snappy(duration: 0.30, extraBounce: 0.34)

    // ------------------------------------------------------------ afvinken ---
    // Het enige plekje waar het echt mag overdrijven.
    static let indeuk = Animation.snappy(duration: 0.10, extraBounce: 0)
    static let wip = Animation.bouncy(duration: 0.34, extraBounce: 0.30)
    static let uitwip = Animation.snappy(duration: 0.30, extraBounce: 0.22)
    static let vonk = Animation.easeOut(duration: 0.52)
    // Uitvinken is geen gebeurtenis, alleen een correctie: gewoon terug.
    static let terug = Animation.snappy(duration: 0.20, extraBounce: 0)

    // ------------------------------------------------------- hele schermen ---
    // Een week of een tabblad verder: langer, want er schuift een half scherm.
    static let schuif = Animation.snappy(duration: 0.42, extraBounce: 0.04)
    static let bladOp = Animation.snappy(duration: 0.38, extraBounce: 0.12)
    static let bladAf = Animation.snappy(duration: 0.20, extraBounce: 0)
    // Ochtend naar avond gaat in één beweging, en alles gaat tegelijk mee.
    static let nacht = Animation.easeInOut(duration: 0.42)

    // ------------------------------------------------------------ na elkaar ---
    // De wissel van ochtend naar avond: elk element komt los van opzij binnen.
    // De reis is langer dan bij het golfje van onderen, dus iets meer tijd, en
    // een wipje aan het eind — het moet aankomen, niet aanschuiven.
    static let entree = Animation.snappy(duration: 0.38, extraBounce: 0.18)

    // Kaartjes komen na elkaar binnen, bovenste eerst: vijftig milliseconden per
    // plek, elk element zijn eigen tel. Het plafond vangt alleen absurd lange
    // lijsten af; bij een gewoon ritme komt niets er tegenaan.
    static func natikken(_ i: Int, stap: Double = 0.05, hoogste: Double = 0.80) -> Double {
        min(Double(max(0, i)) * stap, hoogste)
    }
}
