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
        PhoneLink.shared.start(session)
    }

    var body: some Scene {
        WindowGroup {
            // Een echte container om de switch: een kale switch als body
            // wordt bij een @Observable-update soms niet opnieuw opgevraagd.
            ZStack {
                switch session.state {
                case .unknown:
                    Sky(dark: false)
                case .signedOut:
                    SignInScreen()
                case .signedIn where session.needsHome:
                    NoHomeScreen()
                case .legacy, .signedIn:
                    RootScreen()
                        .task { await Script.run(household) }
                }

                if let code = session.pendingInvite, session.state == .signedIn, !session.needsHome {
                    InviteSheet(code: code)
                        .environment(\.palette, Palette(dark: false))
                }
            }
            .onOpenURL { session.handle($0) }
            .environment(session)
            .environment(household)
            .preferredColorScheme(household.evening ? .dark : .light)
            .onChange(of: session.scope) {
                household.start()
                PhoneLink.shared.push()
            }
        }
        .onChange(of: phase) { _, fresh in
            switch fresh {
            case .active:
                household.wake()
                PhoneLink.shared.push()
            case .background: household.sleep()
            default: break
            }
        }
    }
}
