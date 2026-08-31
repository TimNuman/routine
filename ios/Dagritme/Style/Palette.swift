import SwiftUI

let ORANGE = Color(hex: "#F2994A")
let GREEN = Color(hex: "#34C759")
let RED = Color(hex: "#E5484D")
let INK = Color(hex: "#2B2D42")
let SOFT_INK = Color(hex: "#5C5F7A")

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        let value = UInt64(clean, radix: 16) ?? 0x2B2D42
        self.init(
            .sRGB,
            red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255,
            opacity: 1
        )
    }
}

func tint(_ hex: String, _ part: Double) -> Color {
    Color(hex: hex).opacity(part)
}

struct Palette {
    var dark: Bool

    private func pick(_ light: Color, _ night: Color) -> Color { dark ? night : light }

    var ink: Color { pick(INK, .white) }
    var muted: Color { pick(SOFT_INK, .white.opacity(0.6)) }
    var subtle: Color { pick(SOFT_INK, .white.opacity(0.7)) }

    var glass: Color { pick(.white.opacity(0.62), .white.opacity(0.09)) }
    var glassFloating: Color { pick(.white.opacity(0.82), .white.opacity(0.13)) }
    var glassEdge: Color { pick(.white.opacity(0.75), .white.opacity(0.14)) }
    var sheenTop: Color { pick(.white.opacity(0.9), .white.opacity(0.22)) }
    var sheenBottom: Color { pick(.white.opacity(0.4), .white.opacity(0.06)) }
    var shadow: Color {
        dark ? Color(.sRGB, red: 4 / 255, green: 6 / 255, blue: 26 / 255, opacity: 0.46)
             : Color(.sRGB, red: 126 / 255, green: 84 / 255, blue: 42 / 255, opacity: 0.16)
    }

    var line: Color { pick(INK.opacity(0.08), .white.opacity(0.10)) }
    var divider: Color { pick(.black.opacity(0.05), .white.opacity(0.10)) }
    var track: Color { pick(INK.opacity(0.10), .white.opacity(0.14)) }
    var field: Color { pick(.white.opacity(0.85), .white.opacity(0.10)) }
    var fieldEdge: Color { pick(INK.opacity(0.14), .white.opacity(0.16)) }
    var tile: Color { pick(.white.opacity(0.72), .white.opacity(0.10)) }
    var tileEdge: Color { pick(.white.opacity(0.9), .white.opacity(0.16)) }
    var chip: Color { pick(.white.opacity(0.55), .white.opacity(0.08)) }
    var chipEdge: Color { pick(.white.opacity(0.7), .white.opacity(0.14)) }
    var idleTab: Color { pick(INK.opacity(0.52), .white.opacity(0.55)) }
    var special: Color { pick(ORANGE.opacity(0.13), ORANGE.opacity(0.16)) }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(dark: false)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct Sky: View {
    var dark: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFE3B8"), Color(hex: "#FFD9CE"), Color(hex: "#D9E8F5")],
                startPoint: .top, endPoint: .bottom
            )
            LinearGradient(
                colors: [Color(hex: "#3B3F70"), Color(hex: "#232645"), Color(hex: "#171A33")],
                startPoint: .top, endPoint: .bottom
            )
            .opacity(dark ? 1 : 0)
        }
        .ignoresSafeArea()
    }
}
