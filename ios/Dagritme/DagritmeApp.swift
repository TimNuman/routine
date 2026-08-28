// Ons dagritme, als app op de telefoon. Dezelfde achterkant als de webversie —
// één Worker met /api/opslag erachter — en dezelfde vormtaal.
import SwiftUI

@main
struct DagritmeApp: App {
    @State private var gezin = Gezin()
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        WindowGroup {
            Hoofdscherm()
                .environment(gezin)
                // De app kleurt zichzelf; dit zorgt dat het melkglas en het
                // toetsenbord meegaan in plaats van de stand van de telefoon
                // te volgen.
                .preferredColorScheme(gezin.avond ? .dark : .light)
        }
        .onChange(of: fase) { _, nieuw in
            // Terug uit de slaap: de verbinding is dan weg zonder dat iemand het
            // zei, en het kan ook een dag later zijn.
            if nieuw == .active { gezin.wakker() }
        }
    }
}
