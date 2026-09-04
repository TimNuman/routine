import Foundation
import WatchConnectivity

/// De brug naar het horloge.
///
/// Het horloge praat zelf met het huis; het enige wat het van hier nodig
/// heeft is waar dat huis staat en met welk kopje het erbij mag. Dat gaat
/// twee kanten op: de telefoon zet het klaar zodra er iets verandert
/// (`push`), en het horloge kan er zelf om vragen als de sleutel van dat uur
/// om is — dat wekt deze app op, ook als hij in de zak zit.
///
/// De refresh-token gaat nooit mee. Het horloge krijgt de sleutel van dit
/// uur en verder niets.
@MainActor
final class PhoneLink {
    static let shared = PhoneLink()

    private let bridge = Bridge()
    private var session: Session?

    func start(_ session: Session) {
        guard WCSession.isSupported() else { return }
        self.session = session
        bridge.payload = { [weak session] in
            guard let session, let out = await session.handover() else { return [:] }
            return out.payload
        }
        WCSession.default.delegate = bridge
        WCSession.default.activate()
    }

    /// Zet het adres klaar. Het toestel bewaart het en geeft het door zodra
    /// het horloge er is, dus dit mag ook als er niemand kijkt.
    func push() {
        guard WCSession.isSupported(), let session else { return }
        Task {
            guard let out = await session.handover()?.payload else { return }
            let wc = WCSession.default
            guard wc.activationState == .activated, wc.isPaired, wc.isWatchAppInstalled
            else { return }
            try? wc.updateApplicationContext(out)
        }
    }
}

/// De kant die WatchConnectivity aanroept, buiten de hoofddraad om.
private final class Bridge: NSObject, WCSessionDelegate {
    /// Wat er teruggaat als het horloge om een adres vraagt.
    var payload: (() async -> [String: Any])?

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["kind"] as? String == "handover", let make = payload else {
            replyHandler([:])
            return
        }
        Task { replyHandler(await make()) }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Een ander horloge gekoppeld: opnieuw beginnen, anders komt er niets
    /// meer aan.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
