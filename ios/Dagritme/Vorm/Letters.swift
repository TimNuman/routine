// De letters, met dezelfde maten als de webversie. Baloo 2 voor alles wat een
// naam of een kop is, Nunito voor het kleine grut eromheen.
//
// De bestanden in Lettertypes/ zijn bijgeknipt tot Latijn (zie mobiel/README.md):
// Google levert Baloo 2 met het hele Devanagari-schrift erbij, en dat scheelt
// bijna een megabyte. De namen hieronder zijn de PostScript-namen uit die
// bestanden — niet de bestandsnamen.
import SwiftUI

struct Letter {
    var font: Font
    var tracking: CGFloat = 0
}

extension View {
    func letter(_ l: Letter) -> some View {
        font(l.font).tracking(l.tracking)
    }
}

enum L {
    // Vaste maten, net als in de webversie: de kaartjes zijn krap en een naam
    // die meegroeit met de systeeminstelling valt er zo uit.
    static func baloo(_ maat: CGFloat) -> Font { .custom("Baloo2-Bold", fixedSize: maat) }
    static func balooZwaar(_ maat: CGFloat) -> Font { .custom("Baloo2-ExtraBold", fixedSize: maat) }
    static func nunito(_ maat: CGFloat) -> Font { .custom("Nunito-Bold", fixedSize: maat) }
    static func nunitoZwaar(_ maat: CGFloat) -> Font { .custom("Nunito-ExtraBold", fixedSize: maat) }

    static let titel = Letter(font: balooZwaar(36), tracking: -0.5)
    static let onder = Letter(font: nunito(15))
    static let groep = Letter(font: balooZwaar(17))
    static let groeptijd = Letter(font: nunito(13))
    static func taaknaam(_ maat: CGFloat) -> Letter { Letter(font: baloo(maat)) }
    static let naam = Letter(font: balooZwaar(16))
    static let telling = Letter(font: nunitoZwaar(12.5))
    static let knop = Letter(font: balooZwaar(15))
    static let kindnaam = Letter(font: nunitoZwaar(11))
    static let blokkop = Letter(font: balooZwaar(16))
    static let agendanaam = Letter(font: baloo(15.5))
    static let agendatijd = Letter(font: nunitoZwaar(12.5))
    static let merk = Letter(font: balooZwaar(12.5))
    static let tab = Letter(font: nunitoZwaar(10.5))
    static let tabbreed = Letter(font: nunitoZwaar(13.5))
    static let wletter = Letter(font: balooZwaar(12))
    static let wdag = Letter(font: balooZwaar(17))
    static let kaartknop = Letter(font: balooZwaar(15.5))
    static let lijsttitel = Letter(font: balooZwaar(16))
    static let lijstuitleg = Letter(font: nunito(12.5))
    static let leeg = Letter(font: nunito(16))
    static let voetnoot = Letter(font: nunito(12))
    static let formkop = Letter(font: nunitoZwaar(11.5), tracking: 0.6)
    static let notitie = Letter(font: nunito(12.5))
    static let melding = Letter(font: nunito(13))
    static let chip = Letter(font: balooZwaar(14))
    static let toevoeg = Letter(font: balooZwaar(15.5))
    static let rijlabel = Letter(font: baloo(15.5))
    static let rijdagen = Letter(font: nunitoZwaar(11.5), tracking: 0.2)
    static let bladkop = Letter(font: balooZwaar(18))
    static let tekstknop = Letter(font: nunitoZwaar(16))
    static let grootknop = Letter(font: balooZwaar(16))
    static let opnieuw = Letter(font: nunitoZwaar(13))
    static let veegweg = Letter(font: nunitoZwaar(12.5))
    static let bezig = Letter(font: balooZwaar(16))
    static let vraagnaam = Letter(font: balooZwaar(15.5))
    static let vondstnaam = Letter(font: balooZwaar(15.5))
    static let vondstmeta = Letter(font: nunitoZwaar(12.5))
    static let vondstbron = Letter(font: nunito(12))
}
