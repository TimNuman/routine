import SwiftUI

/// De maten van dít horloge. Een 41 mm is een flink stuk smaller dan een
/// 49 mm, en dat scheelt genoeg om het plaatje en de gezichtjes op mee te
/// laten groeien.
struct Sizes {
    let width: CGFloat

    private var small: Bool { width < 180 }

    var gutter: CGFloat { small ? 6 : 8 }
    var icon: CGFloat { small ? 44 : 52 }
    var name: CGFloat { small ? 15 : 16.5 }
    var face: CGFloat { small ? 32 : 36 }
    var glyph: CGFloat { small ? 19 : 22 }
    var tile: CGFloat { small ? 28 : 32 }
    var tileGlyph: CGFloat { small ? 16 : 18 }
}

private struct SizesKey: EnvironmentKey {
    static let defaultValue = Sizes(width: 184)
}

extension EnvironmentValues {
    var sizes: Sizes {
        get { self[SizesKey.self] }
        set { self[SizesKey.self] = newValue }
    }
}
