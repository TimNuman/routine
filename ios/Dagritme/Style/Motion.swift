import SwiftUI

enum Motion {
    static let quick = Animation.snappy(duration: 0.16, extraBounce: 0.05)
    static let short = Animation.snappy(duration: 0.26, extraBounce: 0.10)
    static let spring = Animation.snappy(duration: 0.30, extraBounce: 0.16)
    static let calm = Animation.smooth(duration: 0.32)

    static let press = Animation.snappy(duration: 0.12, extraBounce: 0)
    static let release = Animation.snappy(duration: 0.30, extraBounce: 0.34)

    static let dent = Animation.snappy(duration: 0.10, extraBounce: 0)
    static let pop = Animation.bouncy(duration: 0.34, extraBounce: 0.30)
    static let settle = Animation.snappy(duration: 0.30, extraBounce: 0.22)
    static let spark = Animation.easeOut(duration: 0.52)
    static let back = Animation.snappy(duration: 0.20, extraBounce: 0)

    static let slide = Animation.snappy(duration: 0.42, extraBounce: 0.04)
    static let sheetUp = Animation.snappy(duration: 0.38, extraBounce: 0.12)
    static let sheetDown = Animation.snappy(duration: 0.20, extraBounce: 0)
    static let night = Animation.easeInOut(duration: 0.42)

    static let entrance = Animation.snappy(duration: 0.6, extraBounce: 0)

    static func stagger(_ i: Int, step: Double = 0.01, cap: Double = 0.80) -> Double {
        min(Double(max(0, i)) * step, cap)
    }
}
