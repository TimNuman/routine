import SwiftUI

struct Metrics {
    let width: CGFloat

    private var tight: Bool { width <= 360 }
    private var roomy: Bool { width >= 700 }
    var wide: Bool { width >= 1000 }

    var sideColumn: CGFloat { 372 }
    var columnGap: CGFloat { 26 }
    var indent: CGFloat { 16 }
    var gutter: CGFloat { tight ? 16 : wide ? 26 : 22 }
    // Meteen onder de statusbalk.
    var topPad: CGFloat { 0 }
    // De menubalk van iOS houdt zelf ruimte vrij onderaan; dit is wat er
    // daarboven nog bij komt, zodat het laatste kaartje niet in de waas valt.
    var bottomPad: CGFloat { 40 }
    var perRow: Int { roomy ? 5 : 3 }
    var gridGap: CGFloat { roomy ? 14 : 10 }
    var cardX: CGFloat { roomy ? 10 : 6 }
    var cardY: CGFloat { roomy ? 10 : 8 }
    var cardGap: CGFloat { roomy ? 6 : 5 }
    var cardHeight: CGFloat { roomy ? 172 : 142 }
    var iconSize: CGFloat { roomy ? 46 : 36 }
    var nameSize: CGFloat { roomy ? 15 : 13 }
    var ringSize: CGFloat { tight ? 34 : roomy ? 50 : 40 }
    var faceSize: CGFloat { tight ? 30 : roomy ? 44 : 34 }
    var glyphSize: CGFloat { tight ? 19 : roomy ? 27 : 21 }
    var maxWidth: CGFloat { 1280 }

    // De stap groot in beeld: over de volle breedte, met de rand eromheen.
    var focusWidth: CGFloat { 520 }
    var focusHeight: CGFloat { 580 }
    var focusIcon: CGFloat { tight ? 96 : roomy ? 168 : 128 }
    var focusName: CGFloat { tight ? 24 : roomy ? 34 : 28 }
    var focusFace: CGFloat { tight ? 50 : roomy ? 74 : 62 }
    var focusRing: CGFloat { focusFace + 16 }
    var focusGlyph: CGFloat { tight ? 31 : roomy ? 46 : 38 }
    var focusStroke: CGFloat { tight ? 4 : roomy ? 6 : 5 }
}

private struct MetricsKey: EnvironmentKey {
    static let defaultValue = Metrics(width: 390)
}

extension EnvironmentValues {
    var metrics: Metrics {
        get { self[MetricsKey.self] }
        set { self[MetricsKey.self] = newValue }
    }
}
