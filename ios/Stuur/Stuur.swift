// De app aansturen zonder handen: tikken, vegen en opnemen vanaf de opdrachtregel.
//
// Waarom dit bestaat: animaties bouwen die je niet kunt zien is gokken. Deze
// bundel bleek meteen zijn nut te hebben — de vonkjes bij het afvinken zaten
// verstopt achter het gezichtje, en dat komt uit geen enkele compiler of log.
//
// Het is geen gewone test met een verwachting erin. Hij voert een plan uit dat
// van buiten komt, en wat eruit komt zijn schermafdrukken. Zo hoeft er niets
// herbouwd te worden als je iets anders wilt proberen; je schrijft een ander plan.
//
//   xcodebuild test -project Dagritme.xcodeproj -scheme Dagritme \
//     -destination 'id=<simulator>'
//
// Zonder meer draait het plan hieronder in de bundel: opstarten, de drie
// schermen langs door te vegen, en van elk een afdruk. Wil je iets anders, wijs
// dan een eigen plan aan (het TEST_RUNNER_-voorvoegsel valt eraf onderweg):
//
//   TEST_RUNNER_STUUR_PLAN=/pad/naar/plan.json \
//   TEST_RUNNER_STUUR_KIEK=/pad/naar/map xcodebuild test ...
//
// Een plan is een lijst met stappen:
//
//   {"doe": "start"}                                   de app (opnieuw) starten
//   {"doe": "wacht", "s": 1.5}
//   {"doe": "tik",   "x": 0.25, "y": 0.79}
//   {"doe": "houd",  "x": 0.25, "y": 0.79, "s": 0.6}
//   {"doe": "veeg",  "van": [0.85, 0.5], "naar": [0.15, 0.5], "vaart": 900}
//   {"doe": "kiek",  "naam": "na-de-tik"}
//
// De plaatsen lopen van 0 tot 1 over de breedte en de hoogte. Dat is met opzet:
// zo reken je ze uit een schermafdruk zonder de puntmaten van dat ene toestel te
// kennen, en blijft een plan kloppen op een andere simulator.
import XCTest

final class Stuur: XCTestCase {

    override func setUp() {
        // Een plan is geen bewering: als stap drie niets raakt wil je stap vier
        // nog steeds zien.
        continueAfterFailure = true
    }

    func testPlan() throws {
        let app = XCUIApplication()

        for stap in try plan() {
            let doe = stap["doe"] as? String ?? ""
            switch doe {
            case "start":
                app.launch()
            case "wacht":
                Thread.sleep(forTimeInterval: getal(stap["s"]) ?? 1)
            case "tik":
                punt(app, stap["x"], stap["y"]).tap()
            case "houd":
                punt(app, stap["x"], stap["y"]).press(forDuration: getal(stap["s"]) ?? 0.5)
            case "veeg":
                let van = paar(stap["van"])
                let naar = paar(stap["naar"])
                punt(app, van.0, van.1).press(
                    forDuration: getal(stap["s"]) ?? 0.05,
                    thenDragTo: punt(app, naar.0, naar.1),
                    withVelocity: .init(getal(stap["vaart"]) ?? 900),
                    thenHoldForDuration: getal(stap["houd"]) ?? 0
                )
            case "kiek":
                bewaar(stap["naam"] as? String ?? "kiek")
            default:
                XCTFail("Onbekende stap: '\(doe)'.")
            }
        }
    }

    // ---------------------------------------------------------------- het plan ---

    private func plan() throws -> [[String: Any]] {
        let ruw: Data
        if let eigen = omgeving("STUUR_PLAN") {
            ruw = try Data(contentsOf: URL(fileURLWithPath: eigen))
        } else {
            let bundel = Bundle(for: Self.self)
            guard let pad = bundel.url(forResource: "plan", withExtension: "json") else {
                throw XCTSkip("Geen plan.json in de bundel en geen STUUR_PLAN gezet.")
            }
            ruw = try Data(contentsOf: pad)
        }
        return try JSONSerialization.jsonObject(with: ruw) as? [[String: Any]] ?? []
    }

    // ------------------------------------------------------------- afdrukken ---

    // Altijd aan de uitslag hangen, zodat ze in het resultaat te vinden zijn, en
    // daarnaast op schijf als er een map is aangewezen — dan kun je ze met
    // gewone gereedschappen vergelijken.
    private func bewaar(_ naam: String) {
        let plaat = XCUIScreen.main.screenshot()

        let bijlage = XCTAttachment(screenshot: plaat)
        bijlage.name = naam
        bijlage.lifetime = .keepAlways
        add(bijlage)

        guard let map = omgeving("STUUR_KIEK") else { return }
        let uit = URL(fileURLWithPath: map).appendingPathComponent(naam + ".png")
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: map),
                                                 withIntermediateDirectories: true)
        try? plaat.pngRepresentation.write(to: uit)
    }

    // ------------------------------------------------------------- rekenwerk ---

    private func punt(_ app: XCUIApplication, _ x: Any?, _ y: Any?) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: getal(x) ?? 0.5,
                                                      dy: getal(y) ?? 0.5))
    }

    private func paar(_ waarde: Any?) -> (Double, Double) {
        let lijst = waarde as? [Any] ?? []
        return (getal(lijst.first) ?? 0.5, getal(lijst.dropFirst().first) ?? 0.5)
    }

    private func getal(_ waarde: Any?) -> Double? {
        (waarde as? NSNumber)?.doubleValue
    }

    private func omgeving(_ sleutel: String) -> String? {
        let waarde = ProcessInfo.processInfo.environment[sleutel]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (waarde?.isEmpty ?? true) ? nil : waarde
    }
}
