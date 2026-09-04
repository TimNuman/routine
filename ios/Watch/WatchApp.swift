import SwiftUI
import WatchKit

@main
struct WatchApp: App {
    @State private var household: WatchHousehold
    @Environment(\.scenePhase) private var phase

    init() {
        _household = State(initialValue: WatchHousehold())
    }

    var body: some Scene {
        WindowGroup {
            Pages()
                .environment(household)
                .environment(\.sizes,
                             Sizes(width: WKInterfaceDevice.current().screenBounds.width))
                .environment(\.palette, Palette(dark: household.evening))
                // Dezelfde overgang als op de telefoon: het licht gaat in
                // 420 ms uit, niet in één keer.
                .animation(Motion.night, value: household.evening)
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
