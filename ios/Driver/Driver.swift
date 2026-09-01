import XCTest

final class Driver: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    func testPlan() throws {
        let app = XCUIApplication()

        for step in try plan() {
            let action = step["do"] as? String ?? ""
            switch action {
            case "launch":
                app.launchEnvironment["SCRIPT"] = environment("DRIVER_SCRIPT") ?? ""
                app.launch()
            case "wait":
                Thread.sleep(forTimeInterval: number(step["s"]) ?? 1)
            case "tap":
                point(app, step["x"], step["y"]).tap()
            case "hold":
                point(app, step["x"], step["y"]).press(forDuration: number(step["s"]) ?? 0.5)
            case "swipe":
                let from = pair(step["from"])
                let to = pair(step["to"])
                point(app, from.0, from.1).press(
                    forDuration: number(step["s"]) ?? 0.05,
                    thenDragTo: point(app, to.0, to.1),
                    withVelocity: .init(number(step["speed"]) ?? 900),
                    thenHoldForDuration: number(step["hold"]) ?? 0
                )
            case "shot":
                save(step["name"] as? String ?? "shot")
            default:
                XCTFail("Onbekende stap: '\(action)'.")
            }
        }
    }

    private func plan() throws -> [[String: Any]] {
        let raw: Data
        if let own = environment("DRIVER_PLAN") {
            raw = try Data(contentsOf: URL(fileURLWithPath: own))
        } else {
            let bundle = Bundle(for: Self.self)
            guard let path = bundle.url(forResource: "plan", withExtension: "json") else {
                throw XCTSkip("Geen plan.json in de bundel en geen DRIVER_PLAN gezet.")
            }
            raw = try Data(contentsOf: path)
        }
        return try JSONSerialization.jsonObject(with: raw) as? [[String: Any]] ?? []
    }

    private func save(_ name: String) {
        let shot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let folder = environment("DRIVER_SHOTS") else { return }
        let out = URL(fileURLWithPath: folder).appendingPathComponent(name + ".png")
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: folder),
                                                 withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: out)
    }

    private func point(_ app: XCUIApplication, _ x: Any?, _ y: Any?) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: number(x) ?? 0.5,
                                                      dy: number(y) ?? 0.5))
    }

    private func pair(_ value: Any?) -> (Double, Double) {
        let list = value as? [Any] ?? []
        return (number(list.first) ?? 0.5, number(list.dropFirst().first) ?? 0.5)
    }

    private func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private func environment(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }
}
