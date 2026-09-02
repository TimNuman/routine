import SwiftUI

struct SettingsScreen: View {
    @Environment(Household.self) private var household
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette
    @Environment(\.metrics) private var m

    @State private var sheet: EditKind?

    var body: some View {
        Screen(title: String(localized: "Instellingen"), subtitle: household.content?.title ?? "", narrow: true) {
            if let content = household.content {
                CardList {
                    CardRow(icon: "🧒", title: String(localized: "Kinderen"),
                            note: content.people.isEmpty
                                ? String(localized: "nog niemand")
                                : content.people.map { $0.name }.joined(separator: ", "),
                            first: true,
                            faces: content.people,
                            id: "settings.children") { sheet = .children }
                    CardRow(icon: "☀️", title: String(localized: "Dagritme"),
                            note: String(localized: "\(stepCount(content.day) + stepCount(content.night)) stappen"),
                            id: "settings.day") { sheet = .day }
                        .entrance(2)
                    CardRow(icon: "📅", title: String(localized: "Weekritme"),
                            note: String(localized: "school, sport en wat er verder is"),
                            id: "settings.week") { sheet = .week }
                        .entrance(3)
                    CardRow(icon: "📌", title: String(localized: "Eenmalig"),
                            note: oneOffText(content),
                            id: "settings.oneOff") { sheet = .oneOff }
                        .entrance(4)
                    CardRow(icon: "⚙️", title: String(localized: "Naam"), note: content.title,
                            id: "settings.general") {
                        sheet = .general
                    }
                    .entrance(5)
                }
                .entrance(1)
            }

            CardList {
                if let account = session.account, let home = session.home {
                    CardRow(icon: "🏠", title: home.name,
                            note: String(localized: "ingelogd als \(account.label)"),
                            first: true, id: "settings.account") {
                        // Terug naar de keuze: een ander huis, of uitloggen.
                        session.homeId = nil
                    }
                } else {
                    CardRow(icon: "👤", title: String(localized: "Inloggen"),
                            note: String(localized: "nu zonder account"),
                            first: true, id: "settings.account") { session.showSignIn() }
                }
            }
            .entrance(6)

            Text("testversie")
                .textStyle(Fonts.footnote)
                .foregroundStyle(palette.muted)
                .opacity(0.75)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .entrance(7)
        }
        .fullScreenCover(item: $sheet) { kind in
            if let content = household.content {
                EditScreen(
                    kind: kind,
                    content: content,
                    onCancel: { sheet = nil },
                    onSave: { await household.save($0) }
                )
            }
        }
    }


    private func oneOffText(_ content: Content) -> String {
        let count = oneOffEntries(content).count
        if count == 0 { return String(localized: "niets op een datum") }
        return String(localized: "\(count) dingen op een datum")
    }
}
