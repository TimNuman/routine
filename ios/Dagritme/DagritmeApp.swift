import SwiftUI

@main
struct DagritmeApp: App {
    @State private var household = Household()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootScreen()
                .environment(household)
                .task { await Script.run(household) }
                .preferredColorScheme(household.evening ? .dark : .light)
        }
        .onChange(of: phase) { _, fresh in
            switch fresh {
            case .active: household.wake()
            case .background: household.sleep()
            default: break
            }
        }
    }
}
