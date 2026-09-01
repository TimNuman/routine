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
    // Vlak onder de statusbalk.
    var topPad: CGFloat { 2 }
    /// De kop begint op één lijn met de klok in de statusbalk (51 pt).
    var headIndent: CGFloat { 27 }
    var bottomPad: CGFloat { wide ? 40 : 120 }
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
