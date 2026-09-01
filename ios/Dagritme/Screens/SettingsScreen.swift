import SwiftUI

struct SettingsScreen: View {
    @Environment(Household.self) private var household
    @Environment(\.palette) private var palette
    @Environment(\.metrics) private var m
    @Environment(\.tabShift) private var tabShift

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
                    CardRow(icon: "☀️", title: String(localized: "Ochtendritme"),
                            note: String(localized: "\(stepCount(content.day)) stappen"),
                            id: "settings.day") { sheet = .day }
                        .shifted(shift(2))
                    CardRow(icon: "🌙", title: String(localized: "Avondritme"),
                            note: String(localized: "\(stepCount(content.night)) stappen"),
                            id: "settings.night") { sheet = .night }
                        .shifted(shift(3))
                    CardRow(icon: "📅", title: String(localized: "Weekritme"),
                            note: String(localized: "school, sport en wat er verder is"),
                            id: "settings.week") { sheet = .week }
                        .shifted(shift(4))
                    CardRow(icon: "📌", title: String(localized: "Eenmalig"),
                            note: oneOffText(content),
                            id: "settings.oneOff") { sheet = .oneOff }
                        .shifted(shift(5))
                    CardRow(icon: "⚙️", title: String(localized: "Naam"), note: content.title,
                            id: "settings.general") {
                        sheet = .general
                    }
                    .shifted(shift(6))
                }
                .shifted(shift(1))
            }

            Text("testversie")
                .textStyle(Fonts.footnote)
                .foregroundStyle(palette.muted)
                .opacity(0.75)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .shifted(shift(7))
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

    private func shift(_ slot: Int) -> Shift { tabShift.at(slot) }

    private func oneOffText(_ content: Content) -> String {
        let count = oneOffEntries(content).count
        if count == 0 { return String(localized: "niets op een datum") }
        return String(localized: "\(count) dingen op een datum")
    }
}
