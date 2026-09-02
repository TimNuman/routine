import SwiftUI

@main
struct DagritmeApp: App {
    @State private var session: Session
    @State private var household: Household
    @Environment(\.scenePhase) private var phase

    init() {
        let session = Session()
        _session = State(initialValue: session)
        _household = State(initialValue: Household(session: session))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .unknown:
                    Sky(dark: false)
                case .signedOut:
                    SignInScreen()
                case .signedIn where session.needsHome:
                    HomeScreen()
                case .legacy, .signedIn:
                    RootScreen()
                        .task { await Script.run(household) }
                }
            }
            .environment(session)
            .environment(household)
            .preferredColorScheme(household.evening ? .dark : .light)
            .onChange(of: session.scope) { household.start() }
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
