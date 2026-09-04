import SwiftUI

struct Screen<Inner: View>: View {
    let title: String
    let subtitle: String
    var center: AnyView? = nil
    var trailing: AnyView? = nil
    /// Wat er op een breed scherm rechts in de kop staat: de kinderen met hun
    /// balkje, dat daar tegelijk de zeef is.
    var aside: AnyView? = nil
    var narrow: Bool = false
    @ViewBuilder var content: () -> Inner

    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    var body: some View {
        pages
            // De hemel hoort bij de bladzijde: de menubalk is de balk van het
            // toestel, en die zet zijn eigen ondergrond onder de bladzijden.
            .background { Sky(dark: household.evening) }
            .overlay { fades }
    }

    private var pages: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if household.content == nil && household.error.isEmpty {
                    ProgressView()
                        .tint(ORANGE)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity)
                        .entrance(1)
                }
                if !household.error.isEmpty {
                    Text("De inhoud laden lukte niet (\(household.error)).")
                        .textStyle(TextStyle(font: Fonts.nunitoHeavy(14)))
                        .foregroundStyle(RED)
                        .padding(.top, 32)
                        .entrance(1)
                }

                content()
                    .frame(maxWidth: narrow && m.wide ? 640 : .infinity, alignment: .leading)
            }
            .padding(.horizontal, m.gutter)
            .padding(.top, m.topPad)
            .padding(.bottom, m.bottomPad)
            .frame(maxWidth: m.maxWidth)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await household.reload() }
        // Onderaan doet iOS zelf een waas over wat er onder de menubalk door
        // schuift. Het glas van die balk kan dat zelf aan — het buigt wat
        // eronder ligt al — dus blijven de kaarten daar gewoon kaarten.
        .scrollEdgeEffectHidden(true, for: .bottom)
    }

    /// Boven zakt de hemel weg, zodat wat wegscrolt niet hard tegen de klok
    /// aan loopt. Onder doet de menubalk van iOS dat zelf.
    private var fades: some View {
        EdgeFade(dark: household.evening)
            .frame(height: 72)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: -3) {
            Text(title)
                .textStyle(Fonts.title(m.wide ? 46 : 36))
                .foregroundStyle(palette.ink)
            HStack(spacing: 10) {
                Text(subtitle)
                    .textStyle(Fonts.subtitle(m.wide ? 17 : 15))
                    .foregroundStyle(palette.subtle)
                if let trailing { trailing.frame(height: 20) }
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, m.indent)
    }

    /// De kop van een breed scherm: de dag met de schakelaar eronder links,
    /// de kinderen rechts. Hij scrolt gewoon mee — het is een bladzijde, geen
    /// balk.
    @ViewBuilder
    private var header: some View {
        if m.wide {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    names
                    if let center { center.frame(width: 280) }
                }
                Spacer(minLength: 0)
                if let aside { aside.frame(maxWidth: 440).padding(.top, 6) }
            }
            .entrance(0)
            .padding(.bottom, 6)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                names
                if let center { center }
            }
            .entrance(0)
        }
    }
}

/// De drie bladzijden onder de menubalk van iOS zelf: op iOS 26 is dat de
/// zwevende balk van vloeibaar glas, met de veeg erover die van tabblad
/// wisselt. Welke bladzijde erbij hoort schuift van opzij in beeld — zie
/// `Components/Tabs.swift`.
struct RootScreen: View {
    @Environment(Household.self) private var household
    @Environment(Session.self) private var session
    @State private var launching = true

    private var items: [TabItem] {
        [
            TabItem(tab: .routine, name: String(localized: "Dag"),
                    symbol: "sun.max", id: "tab.routine"),
            TabItem(tab: .week, name: String(localized: "Week"),
                    symbol: "calendar", id: "tab.week"),
            TabItem(tab: .settings, name: String(localized: "Instellingen"),
                    symbol: "gearshape", id: "tab.settings"),
        ]
    }

    var body: some View {
        GeometryReader { space in
            let m = Metrics(width: space.size.width)

            GlassTabs(chosen: household.tab, onPick: { household.go($0) },
                      items: items, barHidden: household.sheetOpen) { tab in
                TabPage(tab: tab)
                    .environment(household)
                    .environment(session)
                    .environment(\.metrics, m)
                    // De intrede-animatie is voor de start; wat daarna in
                    // beeld komt, komt al van opzij.
                    .environment(\.entranceOn, launching)
            }
            .ignoresSafeArea()
            .task(id: household.content == nil) {
                guard household.content != nil else { return }
                try? await Task.sleep(for: .seconds(2))
                launching = false
            }
        }
    }
}

/// Eén bladzijde in de balk. Het palet en de overgang van dag naar avond
/// zitten hierbinnen en niet erboven: een SwiftUI-animatie komt niet door
/// UIKit heen, dus moet hij aan deze kant van het hostingscherm staan.
private struct TabPage: View {
    let tab: Tab

    @Environment(Household.self) private var household

    var body: some View {
        Group {
            switch tab {
            case .routine: RoutineScreen()
            case .week: WeekScreen()
            case .settings: SettingsScreen()
            }
        }
        .environment(\.palette, Palette(dark: household.evening))
        .animation(Motion.night, value: household.evening)
    }
}

extension Household {
    func go(_ fresh: Tab) {
        let byClock: Routine = calendar.component(.hour, from: now) >= EVENING_FROM ? .night : .day
        guard fresh != tab || (fresh == .routine && routine != byClock) else { return }
        Haptics.select()
        withAnimation(Motion.short) {
            tab = fresh
            if fresh == .routine { routine = byClock }
        }
    }
}
