import SwiftUI

/// Dezelfde letters als op de telefoon — Baloo voor de namen, Nunito voor de
/// tijden — een paar maten kleiner, want het scherm is dat ook.
enum Wrist {
    static let title = TextStyle(font: Fonts.balooHeavy(23), tracking: -0.3)
    static let date = TextStyle(font: Fonts.nunito(12.5))
    static let head = TextStyle(font: Fonts.balooHeavy(14.5))
    static let group = TextStyle(font: Fonts.nunitoHeavy(10.5), tracking: 0.5)
    static func task(_ size: CGFloat) -> TextStyle { TextStyle(font: Fonts.baloo(size)) }
    static let name = TextStyle(font: Fonts.balooHeavy(13.5))
    static let tally = TextStyle(font: Fonts.nunitoHeavy(11))
    static let item = TextStyle(font: Fonts.baloo(13.5))
    static let time = TextStyle(font: Fonts.nunitoHeavy(11))
    static let note = TextStyle(font: Fonts.nunito(13))
}
