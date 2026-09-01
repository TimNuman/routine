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
        ZStack(alignment: .bottom) {
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
        }
    }

    @ViewBuilder
    private var header: some View {
        let names = VStack(alignment: .leading, spacing: -3) {
            Text(title).textStyle(Fonts.title).foregroundStyle(palette.ink)
            HStack(spacing: 10) {
                Text(subtitle).textStyle(Fonts.subtitle).foregroundStyle(palette.subtle)
                if let trailing { trailing }
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, m.indent)

        if m.wide {
            HStack(alignment: .center, spacing: 24) {
                names.frame(maxWidth: .infinity, alignment: .leading)
                    .entrance(0)
                TabBar(wide: true).frame(width: m.sideColumn)
            }
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

struct RootScreen: View {
    @Environment(Household.self) private var household

    var body: some View {
        GeometryReader { space in
            let m = Metrics(width: space.size.width)

            ZStack(alignment: .bottom) {
                Sky(dark: household.evening)

                TabPages()

                if !m.wide {
                    TabBar(wide: false)
                        .frame(maxWidth: 492)
                        .padding(.horizontal, TabBar.edge)
                        .padding(.bottom, TabBar.edge - SafeArea.bottom)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .opacity(household.sheetOpen ? 0 : 1)
                        .offset(y: household.sheetOpen ? 30 : 0)
                        .animation(Motion.sheetUp, value: household.sheetOpen)
                        .allowsHitTesting(!household.sheetOpen)
                }
            }
            .environment(\.metrics, m)
            .environment(\.palette, Palette(dark: household.evening))
            .animation(Motion.night, value: household.evening)
        }
    }
}

private struct TabPages: View {
    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @State private var launching = true

    var body: some View {
        ZStack {
            switch household.tab {
            case .routine: RoutineScreen().transition(slide)
            case .week: WeekScreen().transition(slide)
            case .settings: SettingsScreen().transition(slide)
            }
        }
        // De intrede-animatie is voor de start; wat daarna in beeld komt,
        // komt al van opzij.
        .environment(\.entranceOn, launching)
        .task(id: household.pending) {
            // Start pas na de opbouw waarin de richting is verwerkt.
            guard let move = household.pending else { return }
            withAnimation(Motion.glide) {
                household.tab = move.tab
                household.routine = move.routine
                household.pending = nil
            }
        }
        .task(id: household.content == nil) {
            guard household.content != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            launching = false
        }
    }

    /// De nieuwe bladzijde komt van de kant waar zijn tabblad zit, de oude
    /// gaat de andere kant op; één breedte plus wat lucht ertussen.
    private var slide: AnyTransition {
        let step = CGFloat(household.direction) * (m.width + 60)
        return .asymmetric(insertion: .offset(x: step), removal: .offset(x: -step))
    }
}

extension Household {
    func go(_ fresh: Tab) {
        let byClock: Routine = calendar.component(.hour, from: now) >= EVENING_FROM ? .night : .day
        guard fresh != tab || (fresh == .routine && routine != byClock) else { return }
        Haptics.select()
        let order = Tab.allCases
        // Eerst de richting, dan pas de wissel: een bladzijde die weggaat neemt
        // de overgang mee zoals die stond toen hij voor het laatst is opgebouwd,
        // dus die moet de nieuwe richting al gezien hebben. TabPages voert de
        // wissel uit zodra dat zo is.
        direction = order.firstIndex(of: fresh)! > order.firstIndex(of: tab)! ? 1 : -1
        pending = Move(tab: fresh, routine: fresh == .routine ? byClock : routine)
    }
}
