import SwiftUI

/// Welke stap er groot staat, en waar de kaartjes in het raster liggen.
///
/// Een stap die groot staat is niet een kopie van het kaartje maar het
/// kaartje zelf: zolang hij boven het raster zweeft blijft zijn plek daar
/// leeg, en bij het sluiten zakt hij daar weer in terug. Bij het doorvegen
/// gebeuren die twee tegelijk — de een gaat terug op zijn plek, de ander komt
/// van de zijne omhoog.
@MainActor
@Observable
final class Focus {
    private(set) var tasks: [Step] = []
    private(set) var routine: Routine = .day
    private(set) var index = 0
    /// De stap die op dit moment terugzakt naar zijn plek in het raster.
    private(set) var leaving: Int?

    /// De plek van elk kaartje op het scherm. Die schuift bij elke scrolstap
    /// op, dus hij staat bewust buiten de tekentoestand: niemand hoeft
    /// daarvoor opnieuw getekend te worden, het wordt alleen gelezen als een
    /// kaart opstijgt of landt.
    @ObservationIgnored private var spots: [String: CGRect] = [:]

    var open: Bool { !tasks.isEmpty }

    func step(_ i: Int?) -> Step? {
        guard let i, tasks.indices.contains(i) else { return nil }
        return tasks[i]
    }

    func show(_ tasks: [Step], at index: Int, routine: Routine) {
        guard tasks.indices.contains(index) else { return }
        self.tasks = tasks
        self.index = index
        self.routine = routine
        leaving = nil
    }

    /// Naar de buurstap: deze vertrekt, die komt.
    func go(to target: Int) {
        guard tasks.indices.contains(target), target != index else { return }
        leaving = index
        index = target
    }

    /// De vertrokken kaart ligt weer op zijn plek. Is er ondertussen alweer
    /// een andere vertrokken, dan gaat dit bericht over een oudere wissel en
    /// laten we het liggen.
    func landed(_ from: Int) {
        guard leaving == from else { return }
        leaving = nil
    }

    func close() {
        tasks = []
        index = 0
        leaving = nil
    }

    /// Zweeft deze stap nu boven het raster? Dan blijft zijn plek daar leeg.
    func lifted(_ routine: Routine, _ key: String) -> Bool {
        guard open, routine == self.routine else { return false }
        return key == step(index)?.key || key == step(leaving)?.key
    }

    func place(_ routine: Routine, _ step: String, _ frame: CGRect?) {
        spots["\(routine.rawValue)/\(step)"] = frame
    }

    func spot(_ step: String) -> CGRect? { spots["\(routine.rawValue)/\(step)"] }
}

/// De stap groot: over de volle breedte van het scherm, met een rand eromheen.
/// Hij komt omhoog uit zijn eigen kaartje in het raster en zakt daar ook weer
/// in terug. Vegen wisselt van stap: de ene gaat terug op zijn plek terwijl de
/// volgende van de zijne omhoog komt. Omlaag vegen of naast de kaart tikken
/// legt hem weg. De gezichtjes werken hier net zo als op het kaartje, alleen
/// groter.
struct TaskFocus: View {
    let focus: Focus
    let people: [Person]
    let visible: Set<String>

    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Staat de kaart op het toneel? Zo niet, dan ligt hij op zijn plek in
    /// het raster — dat is waar hij vandaan komt en waar hij heen gaat.
    @State private var shown = false
    @State private var drag = CGSize.zero
    @State private var axis: Axis?
    /// Hoe hoog elke kaart van zichzelf is. De kaart is zo hoog als wat erop
    /// staat, dus dat weten we pas als hij er is — en zonder die maat kan hij
    /// niet precies op zijn kaartje in het raster passen.
    @State private var tall: [Int: CGFloat] = [:]

    var body: some View {
        GeometryReader { space in
            let width = min(space.size.width - m.gutter * 2, m.focusWidth)
            // Het plaatje is zo groot als het mag, maar nooit zo groot dat de
            // kaart niet meer op een laag scherm past.
            let icon = min(m.focusIcon, space.size.height * 0.24)

            ZStack {
                Color.black.opacity(0.34)
                    .opacity(shown ? 1 - Double(min(0.7, drag.height / 420)) : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .accessibilityIdentifier("focus.backdrop")
                    .accessibilityLabel(Spoken.close)
                    .accessibilityAddTraits(.isButton)

                // De kaart die er staat, en die net vertrokken is. De buren
                // staan er alvast op hun plek in het raster bij, zodat ze
                // daarvandaan omhoog kunnen komen in plaats van uit het niets
                // te verschijnen.
                ForEach(Array(focus.tasks.enumerated()), id: \.offset) { (i, step) in
                    if abs(i - focus.index) <= 1 {
                        // Opgetild is te zien: de kaart die er staat, en de
                        // kaart die onderweg is terug naar zijn plek. De rest
                        // wacht onzichtbaar op de zijne.
                        let up = i == focus.index || i == focus.leaving
                        let rest = nest(space, width, step, tall: tall[i],
                                        home: !(shown && i == focus.index))
                        let held = i == (focus.leaving ?? focus.index)

                        card(step, width: width, icon: icon, current: i == focus.index)
                            // De eigen hoogte, buiten alle vergroting om:
                            // `scaleEffect` verandert niets aan de opmaak.
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) {
                                tall[i] = $0
                            }
                            .opacity(up ? 1 : 0)
                            // Een kaart die onzichtbaar op zijn plek ligt te
                            // wachten mag geen tik opvangen; daar hoort de
                            // achtergrond te sluiten.
                            .allowsHitTesting(up)
                            .animation(Motion.quick, value: up)
                            .scaleEffect(x: rest.scale.width, y: rest.scale.height)
                            .offset(x: rest.offset.width + (held ? drag.width : 0),
                                    y: rest.offset.height + (held ? drag.height : 0))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(swipe(width))
        }
        .onAppear {
            // Eén tel wachten: de kaart moet eerst gemeten zijn, anders ligt
            // hij die ene tel te kort op zijn kaartje en begint het tillen
            // alsnog met een sprongetje.
            DispatchQueue.main.async {
                withAnimation(reduceMotion ? Motion.fade : Motion.spring) { shown = true }
            }
        }
    }

    /// Waar een kaart ligt als hij niet op het toneel staat: precies op zijn
    /// kaartje in het raster. Weet niemand waar dat ligt — het is uit beeld
    /// gescrold — dan doemt hij op zijn plek op.
    ///
    /// De breedte en de hoogte krimpen elk met hun eigen factor. Een kaartje
    /// in het raster is hoger dan breed en de grote kaart is bijna vierkant;
    /// met één factor voor allebei zou de kaart op het moment van overnemen
    /// een stuk korter zijn dan het kaartje eronder, en dat is precies de
    /// sprong die je ziet. Nu dekken ze elkaar, en trekt de kaart zich in de
    /// eerste tienden van een seconde recht.
    private func nest(_ space: GeometryProxy, _ width: CGFloat, _ step: Step,
                      tall: CGFloat?, home: Bool) -> (scale: CGSize, offset: CGSize) {
        guard home else { return (CGSize(width: 1, height: 1), .zero) }
        guard !reduceMotion, let spot = focus.spot(step.key), spot.width > 0 else {
            let same: CGFloat = reduceMotion ? 1 : 0.9
            return (CGSize(width: same, height: same), .zero)
        }
        let mine = space.frame(in: .global)
        let across = max(0.15, spot.width / width)
        // Zonder eigen maat: dezelfde factor als in de breedte.
        let down = tall.map { max(0.15, spot.height / $0) } ?? across
        return (
            CGSize(width: across, height: down),
            CGSize(width: spot.midX - mine.minX - space.size.width / 2,
                   height: spot.midY - mine.minY - space.size.height / 2)
        )
    }

    private func card(_ step: Step, width: CGFloat, icon: CGFloat,
                      current: Bool) -> some View {
        let taking = participants(step, people).filter { visible.contains($0.id) }

        return Glass(radius: corner(width), floating: true, lift: 1.5) {
            VStack(spacing: 0) {
                Text(step.icon)
                    .font(.system(size: icon))
                    .accessibilityHidden(true)
                Text(step.label)
                    .textStyle(Fonts.taskName(m.focusName))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    // Een emoji laat zelf al een stuk wit onder zich; dat telt
                    // mee als ruimte, dus de naam schuift er weer in.
                    .padding(.top, -8)

                Flow(gap: 12, rowGap: 10, centered: true) {
                    ForEach(taking) { person in
                        face(step, person)
                    }
                }
                .padding(.top, 18)
            }
            // De bocht van de squircle loopt ver door, dus de tekst begint
            // ruimer van de rand af dan op een gewoon kaartje.
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 26)
            .frame(width: width)
        }
        .accessibilityIdentifier(current ? "focus.card" : "")
    }

    /// De ronding van de kaart: groot genoeg om er een squircle van te maken,
    /// en hij groeit mee met de kaart.
    private func corner(_ width: CGFloat) -> CGFloat {
        width * 0.17
    }

    private func face(_ step: Step, _ person: Person) -> some View {
        let key = checkKey(focus.routine, step.key, person.id)
        return VStack(spacing: 6) {
            Ring(
                person: person,
                stepName: step.label,
                stepId: "focus.\(step.key)",
                on: household.checks[key] == true,
                size: m.focusRing, faceSize: m.focusFace, glyphSize: m.focusGlyph,
                stroke: m.focusStroke,
                onTap: { household.toggle(key) }
            )
            Text(person.name)
                .textStyle(Fonts.childName)
                .foregroundStyle(palette.muted)
                .lineLimit(1)
                .accessibilityHidden(true)
        }
    }

    private func swipe(_ width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { move in
                // De eerste beweging kiest de richting; daarna blijft die
                // gelden tot de vinger loslaat.
                let which = axis ?? (abs(move.translation.width) > abs(move.translation.height)
                    ? Axis.horizontal : Axis.vertical)
                axis = which
                if which == .horizontal {
                    // De kaart geeft mee, maar hij schuift niet met de vinger
                    // mee weg: er ligt geen rij naast, hij gaat straks terug
                    // op zijn eigen plek.
                    let sideways = move.translation.width * 0.55
                    let edge = (sideways > 0 && focus.index == 0)
                        || (sideways < 0 && focus.index >= focus.tasks.count - 1)
                    drag = CGSize(width: edge ? sideways / 3 : sideways, height: 0)
                } else {
                    drag = CGSize(width: 0, height: max(0, move.translation.height))
                }
            }
            .onEnded { move in
                let which = axis
                axis = nil
                if which == .vertical {
                    if drag.height > 110 || move.predictedEndTranslation.height > 320 {
                        close()
                    } else {
                        withAnimation(Motion.spring) { drag = .zero }
                    }
                    return
                }
                let side = drag.width < 0 ? 1 : -1
                let far = abs(drag.width) > width * 0.16
                let flick = abs(move.predictedEndTranslation.width) > width * 0.8
                    && (move.predictedEndTranslation.width < 0) == (side == 1)
                if far || flick {
                    go(to: focus.index + side)
                } else {
                    withAnimation(Motion.glide) { drag = .zero }
                }
            }
    }

    /// De ene kaart terug op zijn plek, de volgende van de zijne omhoog.
    private func go(to target: Int) {
        guard focus.tasks.indices.contains(target) else {
            withAnimation(Motion.glide) { drag = .zero }
            return
        }
        Haptics.select()
        let from = focus.index
        withAnimation(Motion.glide) {
            focus.go(to: target)
            drag = .zero
        } completion: {
            // Geland: het kaartje in het raster mag zijn plek weer innemen,
            // en de kaart erboven vervaagt er precies overheen.
            withAnimation(Motion.quick) { focus.landed(from) }
        }
    }

    private func close() {
        axis = nil
        withAnimation(Motion.short) {
            shown = false
            drag = .zero
        } completion: {
            withAnimation(Motion.quick) { focus.close() }
        }
    }
}
