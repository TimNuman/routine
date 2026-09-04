import SwiftUI

struct Metrics {
    let width: CGFloat

    private var tight: Bool { width <= 360 }
    private var roomy: Bool { width >= 700 }
    var wide: Bool { width >= 1000 }

    var columnGap: CGFloat { 26 }
    var indent: CGFloat { 16 }
    var gutter: CGFloat { tight ? 16 : wide ? 26 : 22 }
    // Meteen onder de statusbalk.
    var topPad: CGFloat { 0 }
    // De menubalk van iOS houdt zelf ruimte vrij onderaan; dit is wat er
    // daarboven nog bij komt, zodat het laatste kaartje niet in de waas valt.
    var bottomPad: CGFloat { 40 }
    var maxWidth: CGFloat { 1280 }

    /// Hoeveel er van links naar rechts naast elkaar past. Op de telefoon
    /// twee, zodat een kaart groot genoeg is om met een kinderduim te raken.
    var perRow: Int { wide ? 5 : roomy ? 4 : 2 }
    var gridGap: CGFloat { roomy ? 16 : 12 }

    /// De ruimte die het raster heeft: het scherm min de marges.
    var contentWidth: CGFloat { min(width, maxWidth) - gutter * 2 }

    /// Een kaart is vierkant, net als de kaart die groot in beeld komt: de
    /// breedte volgt uit het raster, de hoogte is dezelfde.
    var cardWidth: CGFloat {
        max(80, (contentWidth - gridGap * CGFloat(perRow - 1)) / CGFloat(perRow))
    }
    var cardHeight: CGFloat { cardWidth }
    /// De squircle van de grote kaart, op de maat van het kaartje.
    var cardRadius: CGFloat { cardWidth * 0.17 }

    var cardX: CGFloat { max(8, cardWidth * 0.08) }
    var cardY: CGFloat { max(8, cardWidth * 0.07) }
    var cardGap: CGFloat { roomy ? 6 : 5 }
    var iconSize: CGFloat { min(64, cardWidth * 0.30) }
    var nameSize: CGFloat { tight ? 14 : roomy ? 17 : 15 }
    var ringSize: CGFloat { tight ? 38 : roomy ? 50 : 44 }
    var faceSize: CGFloat { tight ? 33 : roomy ? 44 : 38 }
    var glyphSize: CGFloat { tight ? 21 : roomy ? 27 : 23 }

    /// De kaartjes van vandaag onderaan: even breed als een taakkaartje, maar
    /// lager — er hoeft niets afgevinkt te worden.
    var todayHeight: CGFloat { cardWidth * 0.72 }

    // De stap groot in beeld: over de volle breedte, met de rand eromheen.
    var focusWidth: CGFloat { 520 }
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
