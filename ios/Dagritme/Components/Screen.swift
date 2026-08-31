import SwiftUI

private struct TabOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabOffset: CGFloat {
        get { self[TabOffsetKey.self] }
        set { self[TabOffsetKey.self] = newValue }
    }
}

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
    @Environment(\.tabOffset) private var tabOffset

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
                            .shifted(shift(1))
                    }
                    if !household.error.isEmpty {
                        Text("De inhoud laden lukte niet (\(household.error)).")
                            .textStyle(TextStyle(font: Fonts.nunitoHeavy(14)))
                            .foregroundStyle(RED)
                            .padding(.top, 32)
                            .shifted(shift(1))
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

    private func shift(_ slot: Int) -> Shift {
        Shift(slot: slot, steps: tabOffset, span: m.width + 60)
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
                    .shifted(shift(0))
                TabBar(wide: true).frame(width: m.sideColumn)
            }
            .overlay(alignment: .center) {
                if let center { center.frame(width: 250).shifted(shift(0)) }
            }
            .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                names
                if let center { center }
            }
            .shifted(shift(0))
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

                TabPages(tab: household.tab)

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
    let tab: Tab

    @Environment(Household.self) private var household

    var body: some View {
        ZStack {
            page(.routine) { RoutineScreen() }
            page(.week) { WeekScreen() }
            page(.settings) { SettingsScreen() }
        }
    }

    private func page(_ which: Tab, @ViewBuilder _ screen: () -> some View) -> some View {
        let here = tab == which
        return screen()
            .environment(\.tabOffset, column(which) - column(tab))
            .zIndex(here ? 1 : 0)
            .allowsHitTesting(here)
            .accessibilityHidden(!here)
    }

    private func column(_ which: Tab) -> CGFloat {
        switch which {
        case .routine: return household.routine == .night ? 1 : 0
        case .week: return 2
        case .settings: return 3
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
