import SwiftUI

struct TextStyle {
    var font: Font
    var tracking: CGFloat = 0
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

enum Fonts {
    static func baloo(_ size: CGFloat) -> Font { .custom("Baloo2-Bold", fixedSize: size) }
    static func balooHeavy(_ size: CGFloat) -> Font { .custom("Baloo2-ExtraBold", fixedSize: size) }
    static func nunito(_ size: CGFloat) -> Font { .custom("Nunito-Bold", fixedSize: size) }
    static func nunitoHeavy(_ size: CGFloat) -> Font { .custom("Nunito-ExtraBold", fixedSize: size) }

    static func title(_ size: CGFloat = 36) -> TextStyle {
        TextStyle(font: balooHeavy(size), tracking: -0.5)
    }
    static func subtitle(_ size: CGFloat = 15) -> TextStyle { TextStyle(font: nunito(size)) }
    static func group(_ size: CGFloat = 17) -> TextStyle { TextStyle(font: balooHeavy(size)) }
    static func groupTime(_ size: CGFloat = 13) -> TextStyle { TextStyle(font: nunito(size)) }
    static func taskName(_ size: CGFloat) -> TextStyle { TextStyle(font: baloo(size)) }
    static let name = TextStyle(font: balooHeavy(16))
    static let tally = TextStyle(font: nunitoHeavy(12.5))
    static let button = TextStyle(font: balooHeavy(15))
    static let childName = TextStyle(font: nunitoHeavy(11))
    static func blockHead(_ size: CGFloat = 16) -> TextStyle {
        TextStyle(font: balooHeavy(size))
    }
    static let agendaName = TextStyle(font: baloo(15.5))
    static let agendaTime = TextStyle(font: nunitoHeavy(12.5))
    static let tag = TextStyle(font: balooHeavy(12.5))
    static let weekLetter = TextStyle(font: balooHeavy(12))
    static let weekDay = TextStyle(font: balooHeavy(17))
    static let cardButton = TextStyle(font: balooHeavy(15.5))
    static let listTitle = TextStyle(font: balooHeavy(16))
    static let listNote = TextStyle(font: nunito(12.5))
    static let empty = TextStyle(font: nunito(16))
    static let footnote = TextStyle(font: nunito(12))
    static let formHead = TextStyle(font: nunitoHeavy(11.5), tracking: 0.6)
    static let note = TextStyle(font: nunito(12.5))
    static let alert = TextStyle(font: nunito(13))
    static let chip = TextStyle(font: balooHeavy(14))
    static let add = TextStyle(font: balooHeavy(15.5))
    static let rowLabel = TextStyle(font: baloo(15.5))
    static let rowMeta = TextStyle(font: nunitoHeavy(11.5), tracking: 0.2)
    static let sheetHead = TextStyle(font: balooHeavy(18))
    static let textButton = TextStyle(font: nunitoHeavy(16))
    static let bigButton = TextStyle(font: balooHeavy(16))
    static let pill = TextStyle(font: nunitoHeavy(13))
    static let swipe = TextStyle(font: nunitoHeavy(12.5))
    static let busy = TextStyle(font: balooHeavy(16))
    static let askName = TextStyle(font: balooHeavy(15.5))
    static let findName = TextStyle(font: balooHeavy(15.5))
    static let findMeta = TextStyle(font: nunitoHeavy(12.5))
    static let findSource = TextStyle(font: nunito(12))
}
