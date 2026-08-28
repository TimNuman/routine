// De kleuren, en het omslaan van ochtend naar avond.
//
// In de react native-versie hangt elke kleur aan één gedeelde waarde die van 0
// naar 1 loopt. SwiftUI kan dat zelf: kleuren zijn animeerbaar, dus één vlag in
// het palet en één `.animation(BEWEGING.nacht, value: donker)` bovenin laten het
// hele scherm in dezelfde beweging omgaan.
import SwiftUI

let ORANJE = Color(hex: "#F2994A")
let GROEN = Color(hex: "#34C759")
let ROOD = Color(hex: "#E5484D")
let INKT = Color(hex: "#2B2D42")
let ZACHTINKT = Color(hex: "#5C5F7A")

extension Color {
    init(hex: String) {
        let schoon = hex.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        let getal = UInt64(schoon, radix: 16) ?? 0x2B2D42
        self.init(
            .sRGB,
            red: Double((getal >> 16) & 255) / 255,
            green: Double((getal >> 8) & 255) / 255,
            blue: Double(getal & 255) / 255,
            opacity: 1
        )
    }
}

// De kleur van een kind, maar dan als vlak eronder: dezelfde kleur, doorzichtig.
func zacht(_ hex: String, _ deel: Double) -> Color {
    Color(hex: hex).opacity(deel)
}

struct Palet {
    var donker: Bool

    private func kies(_ licht: Color, _ nacht: Color) -> Color { donker ? nacht : licht }

    // tekst
    var inkt: Color { kies(INKT, .white) }
    var zacht: Color { kies(ZACHTINKT, .white.opacity(0.6)) }
    var onder: Color { kies(ZACHTINKT, .white.opacity(0.7)) }

    // het glas zelf
    var glas: Color { kies(.white.opacity(0.62), .white.opacity(0.09)) }
    var glasZwevend: Color { kies(.white.opacity(0.82), .white.opacity(0.13)) }
    var glasRand: Color { kies(.white.opacity(0.75), .white.opacity(0.14)) }
    var glansBoven: Color { kies(.white.opacity(0.9), .white.opacity(0.22)) }
    var glansOnder: Color { kies(.white.opacity(0.4), .white.opacity(0.06)) }
    var schaduw: Color {
        donker ? Color(.sRGB, red: 4 / 255, green: 6 / 255, blue: 26 / 255, opacity: 0.46)
               : Color(.sRGB, red: 126 / 255, green: 84 / 255, blue: 42 / 255, opacity: 0.16)
    }

    // lijnen en vlakken erin
    var streep: Color { kies(INKT.opacity(0.08), .white.opacity(0.10)) }
    var scheiding: Color { kies(.black.opacity(0.05), .white.opacity(0.10)) }
    var goot: Color { kies(INKT.opacity(0.10), .white.opacity(0.14)) }
    var veld: Color { kies(.white.opacity(0.85), .white.opacity(0.10)) }
    var veldRand: Color { kies(INKT.opacity(0.14), .white.opacity(0.16)) }
    var tegel: Color { kies(.white.opacity(0.72), .white.opacity(0.10)) }
    var tegelRand: Color { kies(.white.opacity(0.9), .white.opacity(0.16)) }
    var chip: Color { kies(.white.opacity(0.55), .white.opacity(0.08)) }
    var chipRand: Color { kies(.white.opacity(0.7), .white.opacity(0.14)) }
    var rustigTab: Color { kies(INKT.opacity(0.52), .white.opacity(0.55)) }
    var bijzonder: Color { kies(ORANJE.opacity(0.13), ORANJE.opacity(0.16)) }
}

private struct PaletSleutel: EnvironmentKey {
    static let defaultValue = Palet(donker: false)
}

extension EnvironmentValues {
    var palet: Palet {
        get { self[PaletSleutel.self] }
        set { self[PaletSleutel.self] = newValue }
    }
}

// Het behang: 's ochtends een zonsopgang, 's avonds dezelfde lucht in het donker.
// De twee verlopen vervagen over elkaar heen, want een verloop zelf laat zich
// niet netjes tussen twee standen in tekenen.
struct Lucht: View {
    var donker: Bool

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
            .opacity(donker ? 1 : 0)
        }
        .ignoresSafeArea()
    }
}
