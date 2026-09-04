import Foundation
import Observation
import WatchConnectivity

/// De brug naar de telefoon. Het horloge praat zelf met het huis; het enige
/// wat het van de telefoon nodig heeft is waar dat huis staat en met welk
/// kopje het erbij mag (`Handover`).
///
/// Dat komt langs twee wegen binnen: de telefoon zet het klaar met een
/// *application context* — die bewaart het toestel, dus hij staat er ook nog
/// als de app opnieuw begint — en het horloge kan er zelf om vragen zodra de
/// sleutel van dit uur om is. Dat vragen wekt de app op de telefoon op, ook
/// als die in de zak zit.
@MainActor
@Observable
final class Link {
    private(set) var handover: Handover?
    /// Geroepen zodra er een ander adres of een andere sleutel is.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let bridge = Bridge()
    @ObservationIgnored private var asking: Task<Handover?, Never>?

    /// Een sleutel is een uur geldig; ruim daarvoor vragen we een verse.
    private static let stale: TimeInterval = 45 * 60

    var endpoint: Endpoint? {
        guard let handover, let store = URL(string: handover.store) else { return nil }
        return Endpoint(
            store: store,
            headers: handover.headers,
            refresh: { [weak self] in await self?.freshKey() }
        )
    }

    init() {
        bridge.onHandover = { [weak self] fresh in
            Task { @MainActor in self?.take(fresh) }
        }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = bridge
        WCSession.default.activate()
    }

    /// Bij het wakker worden: is er nog niets, of is de sleutel bijna om, dan
    /// de telefoon erom vragen.
    func wake() {
        let old = handover.map { Date().timeIntervalSince($0.at) > Self.stale } ?? true
        guard old else { return }
        Task { _ = await ask() }
    }

    /// Voor `Endpoint`: op een 401 één keer een verse sleutel halen.
    func freshKey() async -> String? {
        guard let fresh = await ask() else { return nil }
        guard let header = fresh.headers["Authorization"] else { return nil }
        return String(header.dropFirst("Bearer ".count))
    }

    /// Meerdere verzoeken die tegelijk om een sleutel vragen delen één poging.
    private func ask() async -> Handover? {
        if let asking { return await asking.value }
        let task = Task { [bridge] in await bridge.ask() }
        asking = task
        let out = await task.value
        asking = nil
        if let out { take(out) }
        return out
    }

    private func take(_ fresh: Handover) {
        guard !fresh.sameAs(handover) else {
            handover?.at = fresh.at
            return
        }
        handover = fresh
        onChange?()
    }
}

/// De kant die WatchConnectivity aanroept, buiten de hoofddraad om. Hij maakt
/// er meteen een `Handover` van en legt die op de hoofddraad neer.
private final class Bridge: NSObject, WCSessionDelegate {
    var onHandover: (@Sendable (Handover) -> Void)?

    func ask() async -> Handover? {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable
        else { return nil }
        return await withCheckedContinuation { (done: CheckedContinuation<Handover?, Never>) in
            WCSession.default.sendMessage(["kind": "handover"]) { reply in
                done.resume(returning: Handover(reply))
            } errorHandler: { _ in
                done.resume(returning: nil)
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        guard state == .activated, let fresh = Handover(session.receivedApplicationContext)
        else { return }
        onHandover?(fresh)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        guard let fresh = Handover(context) else { return }
        onHandover?(fresh)
    }
}
