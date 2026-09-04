import Foundation
import WatchKit

/// Wat je voelt in plaats van hoort. Het horloge kent geen intensiteit zoals
/// de telefoon; dit zijn de twee die er het dichtst bij komen.
@MainActor
enum Haptics {
    static func tick(_ on: Bool) {
        WKInterfaceDevice.current().play(on ? .click : .directionDown)
    }

    static func done() {
        WKInterfaceDevice.current().play(.success)
    }
}
