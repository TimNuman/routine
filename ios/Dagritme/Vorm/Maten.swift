// Precies de drie grenzen uit de webversie: onder 360 wordt alles krapper,
// vanaf 700 past er een maatje groter bij, en vanaf 1000 komt het weekritme als
// kolom ernaast te staan — dat laatste is op een iPad in liggende stand.
import SwiftUI

struct Maten {
    let breedte: CGFloat

    private var krap: Bool { breedte <= 360 }
    private var ruim: Bool { breedte >= 700 }
    var breed: Bool { breedte >= 1000 }

    // De kolom ernaast, even breed als de menubalk op web, met dezelfde goot.
    var zijkolom: CGFloat { 372 }
    var naast: CGFloat { 26 }
    // Alles springt overal even ver in, zodat kopjes en de eerste emoji op één
    // lijn staan.
    var insprong: CGFloat { 16 }
    var gootje: CGFloat { krap ? 16 : breed ? 26 : 22 }
    var bovenaan: CGFloat { breed ? 22 : 26 }
    var onderaan: CGFloat { breed ? 40 : 120 }
    // Het kaartraster: drie op een rij op een telefoon, vijf zodra er ruimte is.
    var perRij: Int { ruim ? 5 : 3 }
    var tussen: CGFloat { ruim ? 14 : 10 }
    var kaartX: CGFloat { ruim ? 10 : 6 }
    var kaartY: CGFloat { ruim ? 10 : 8 }
    var kaartGat: CGFloat { ruim ? 6 : 5 }
    var hoog: CGFloat { ruim ? 172 : 142 }
    var icoon: CGFloat { ruim ? 46 : 36 }
    var naam: CGFloat { ruim ? 15 : 13 }
    var rondje: CGFloat { krap ? 34 : ruim ? 50 : 40 }
    var gezicht: CGFloat { krap ? 30 : ruim ? 44 : 34 }
    var teken: CGFloat { krap ? 19 : ruim ? 27 : 21 }
    // De webversie houdt de hele app op 1280 breed; daarboven wordt het geen
    // betere bladspiegel, alleen bredere kaartjes.
    var maxBreed: CGFloat { 1280 }
}

private struct MatenSleutel: EnvironmentKey {
    static let defaultValue = Maten(breedte: 390)
}

extension EnvironmentValues {
    var maten: Maten {
        get { self[MatenSleutel.self] }
        set { self[MatenSleutel.self] = newValue }
    }
}
