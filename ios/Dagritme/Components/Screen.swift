import SwiftUI

struct Screen<Inner: View>: View {
    let title: String
    let subtitle: String
    var center: AnyView? = nil
    var trailing: AnyView? = nil
    var narrow: Bool = false
    @ViewBuilder var content: () -> Inner

    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    var body: some View {
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
        // De hemel hoort bij de bladzijde: de menubalk is de balk van het
        // toestel, en die zet zijn eigen ondergrond onder de bladzijden.
        .background { Sky(dark: household.evening) }
        .overlay { fades }
        // Een blad legt zich over het hele scherm; de menubalk hoort daar
        // niet bovenop te blijven staan.
        .toolbar(household.sheetOpen ? .hidden : .visible, for: .tabBar)
    }

    /// Boven en onder zakt de hemel weg, zodat wat wegscrolt niet hard tegen
    /// de klok of de menubalk aan loopt.
    private var fades: some View {
        ZStack {
            EdgeFade(dark: household.evening)
                .frame(height: 72)
                .frame(maxHeight: .infinity, alignment: .top)

            EdgeFade(dark: household.evening, bottom: true)
                .frame(height: 130)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var header: some View {
        let names = VStack(alignment: .leading, spacing: -3) {
            Text(title).textStyle(Fonts.title).foregroundStyle(palette.ink)
            HStack(spacing: 10) {
                Text(subtitle).textStyle(Fonts.subtitle).foregroundStyle(palette.subtle)
                if let trailing { trailing.frame(height: 20) }
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, m.indent)

        if m.wide {
            names
                .frame(maxWidth: .infinity, alignment: .leading)
                .entrance(0)
                .overlay(alignment: .center) {
                    if let center { center.frame(width: 250).entrance(0) }
                }
                .padding(.bottom, 4)
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
/// wisselt; daarvóór de gewone balk. Wat de app zelf tekende — een eigen balk
/// en een veeg over de hele bladzijde — is daarmee weg.
struct RootScreen: View {
    @Environment(Household.self) private var household
    @State private var launching = true

    private var chosen: Binding<Tab> {
        Binding(get: { household.tab }, set: { household.go($0) })
    }

    var body: some View {
        GeometryReader { space in
            let m = Metrics(width: space.size.width)

            TabView(selection: chosen) {
                RoutineScreen()
                    .tabItem { Label("Ritme", systemImage: "checklist") }
                    .tag(Tab.routine)

                WeekScreen()
                    .tabItem { Label("Deze week", systemImage: "calendar") }
                    .tag(Tab.week)

                SettingsScreen()
                    .tabItem { Label("Instellingen", systemImage: "gearshape") }
                    .tag(Tab.settings)
            }
            .environment(\.metrics, m)
            .environment(\.palette, Palette(dark: household.evening))
            // De intrede-animatie is voor de start; wat daarna in beeld komt,
            // komt zonder.
            .environment(\.entranceOn, launching)
            .animation(Motion.night, value: household.evening)
            .task(id: household.content == nil) {
                guard household.content != nil else { return }
                try? await Task.sleep(for: .seconds(2))
                launching = false
            }
        }
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
