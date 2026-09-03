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

/// Waar de gezichtjes liggen in één opstelling, gerekend vanaf het midden van
/// de tros, en hoe hoog die opstelling is.
private struct Spots {
    var places: [CGPoint]
    var height: CGFloat
}

/// Zoveel gezichtjes van deze maat in deze breedte: hoeveel er op een rij
/// passen, waar ze dan liggen, en hoe hoog dat wordt. Dezelfde indeling als
/// `Flow` maakt, maar uitgerekend in plaats van gelegd, zodat er tussen twee
/// van die uitkomsten in gerekend kan worden.
private func spots(_ count: Int, width: CGFloat, item: CGFloat,
                   itemHeight: CGFloat, gap: CGFloat, rowGap: CGFloat) -> Spots {
    guard count > 0 else { return Spots(places: [], height: 0) }
    let perRow = max(1, Int((width + gap) / (item + gap)))
    let rows = (count + perRow - 1) / perRow
    let height = CGFloat(rows) * itemHeight + CGFloat(rows - 1) * rowGap
    var places: [CGPoint] = []
    for i in 0..<count {
        let row = i / perRow
        let column = i % perRow
        let onRow = min(perRow, count - row * perRow)
        let rowWidth = CGFloat(onRow) * item + CGFloat(onRow - 1) * gap
        places.append(CGPoint(
            x: CGFloat(column) * (item + gap) - (rowWidth - item) / 2,
            y: CGFloat(row) * (itemHeight + rowGap) - (height - itemHeight) / 2
        ))
    }
    return Spots(places: places, height: height)
}

/// Waar het kaartje van deze stap in het raster ligt, gerekend vanaf het
/// midden van het scherm.
private struct Nest {
    var size: CGSize
    var shift: CGSize
}

/// De stap groot: over de volle breedte van het scherm, met een rand eromheen.
/// Hij komt omhoog uit zijn eigen kaartje in het raster en zakt daar ook weer
/// in terug. Vegen wisselt van stap: de ene gaat terug op zijn plek terwijl de
/// volgende van de zijne omhoog komt. Omlaag vegen of naast de kaart tikken
/// legt hem weg.
struct TaskFocus: View {
    let focus: Focus
    let people: [Person]
    let visible: Set<String>

    @Environment(\.metrics) private var m
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Staat de kaart groot in het midden? Zo niet, dan ligt hij als kaartje
    /// op zijn plek in het raster — dat is waar hij vandaan komt en waar hij
    /// heen gaat.
    @State private var shown = false
    @State private var drag = CGSize.zero
    @State private var axis: Axis?

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
                // liggen er als kaartje op hun plek in het raster bij, zodat
                // ze daarvandaan omhoog kunnen komen in plaats van uit het
                // niets te verschijnen.
                ForEach(Array(focus.tasks.enumerated()), id: \.offset) { (i, step) in
                    if abs(i - focus.index) <= 1 {
                        let home = nest(space, step)
                        // Opgetild is te zien: de kaart die er staat, en de
                        // kaart die onderweg is terug naar zijn plek.
                        let up = i == focus.index || i == focus.leaving
                        let held = i == (focus.leaving ?? focus.index)
                        let grown: CGFloat = (reduceMotion || home == nil)
                            ? 1 : (shown && i == focus.index ? 1 : 0)

                        // Het opdoemen zit binnen de kaart en niet hier: een
                        // `animation` om een `Animatable` view heen neemt ook
                        // de vervorming zelf over, en die hoort bij de veer
                        // van de veeg.
                        MorphCard(t: grown, seen: up, step: step, full: width, icon: icon,
                                  nest: home ?? Nest(size: .zero, shift: .zero),
                                  taking: taking(step), routine: focus.routine,
                                  current: i == focus.index)
                            .offset(x: held ? drag.width : 0, y: held ? drag.height : 0)
                            // Wie omhoog komt gaat over wie terugzakt, welke
                            // kant je ook op veegt.
                            .zIndex(i == focus.index ? 2 : (i == focus.leaving ? 1 : 0))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(swipe(width))
        }
        .onAppear {
            withAnimation(reduceMotion ? Motion.fade : Motion.lift) { shown = true }
        }
    }

    private func taking(_ step: Step) -> [Person] {
        participants(step, people).filter { visible.contains($0.id) }
    }

    /// Waar het kaartje van deze stap ligt. Weet niemand dat — het is uit
    /// beeld gescrold — dan is er niets om uit op te komen, en staat de kaart
    /// er meteen.
    private func nest(_ space: GeometryProxy, _ step: Step) -> Nest? {
        guard !reduceMotion, let spot = focus.spot(step.key), spot.width > 0 else { return nil }
        let mine = space.frame(in: .global)
        return Nest(
            size: spot.size,
            shift: CGSize(width: spot.midX - mine.minX - space.size.width / 2,
                          height: spot.midY - mine.minY - space.size.height / 2)
        )
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
                    // naar zijn eigen plek.
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
                    withAnimation(Motion.lift) { drag = .zero }
                }
            }
    }

    /// De ene kaart terug op zijn plek, de volgende van de zijne omhoog.
    private func go(to target: Int) {
        guard focus.tasks.indices.contains(target) else {
            withAnimation(Motion.lift) { drag = .zero }
            return
        }
        Haptics.select()
        let from = focus.index
        withAnimation(Motion.lift) {
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
        withAnimation(Motion.lift) {
            shown = false
            drag = .zero
        } completion: {
            withAnimation(Motion.quick) { focus.close() }
        }
    }
}

/// De kaart onderweg tussen twee vormen. Op `t = 0` is hij het kaartje in het
/// raster — even breed, even hoog, met dezelfde letters en dezelfde gezichtjes
/// — en op `t = 1` staat hij groot in het midden. Alles ertussenin loopt mee:
/// de plek, de maat, de ronding, de rand, het plaatje, de naam, de gezichtjes
/// en de namen eronder, die er op het kaartje niet zijn.
///
/// Daarom is dit een `Animatable` view: SwiftUI geeft hem elk beeld de
/// tussenstand van `t`, en dan is elke maat erin gewoon een getal tussen twee
/// getallen. Met alleen een `scaleEffect` zou de hele kaart als één plaatje
/// worden uitgerekt — een kaartje is hoger dan breed en de kaart is bijna
/// vierkant, dus dat trok alles scheef.
private struct MorphCard: View, Animatable {
    var t: CGFloat
    /// Is deze kaart opgetild? Alleen de kaart die er staat en de kaart die
    /// terugzakt zijn te zien; de rest wacht onzichtbaar op zijn plek.
    var seen: Bool
    var step: Step
    var full: CGFloat
    var icon: CGFloat
    var nest: Nest
    var taking: [Person]
    var routine: Routine
    var current: Bool

    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    /// De veer mag een tikje doorschieten, maar geen maat mag negatief worden.
    private var part: CGFloat { min(1.12, max(0, t)) }

    private func mix(_ small: CGFloat, _ big: CGFloat) -> CGFloat {
        small + (big - small) * part
    }

    private var allDone: Bool {
        guard !taking.isEmpty else { return false }
        return taking.allSatisfy {
            household.checks[checkKey(routine, step.key, $0.id)] == true
        }
    }

    var body: some View {
        Glass(radius: mix(22, full * 0.17), floating: true,
              lift: mix(0.25, 1.5), rim: mix(0, 5)) {
            VStack(spacing: mix(m.cardGap, 0)) {
                Text(step.icon)
                    .font(.system(size: mix(m.iconSize, icon)))
                    .scaleEffect(allDone ? 1.12 : 1)
                    .animation(Motion.pop, value: allDone)
                    .accessibilityHidden(true)
                Text(step.label)
                    .textStyle(Fonts.taskName(mix(m.nameSize, m.focusName)))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    // Een emoji laat zelf al een stuk wit onder zich; dat telt
                    // mee als ruimte, dus de naam schuift er weer in.
                    .padding(.top, mix(0, -8))

                faces
                    .padding(.top, mix(0, 18))
            }
            // De bocht van de squircle loopt ver door, dus de tekst begint
            // ruimer van de rand af dan op een gewoon kaartje.
            .padding(.horizontal, mix(m.cardX, 26))
            .padding(.top, mix(m.cardY, 20))
            .padding(.bottom, mix(m.cardY, 26))
            .frame(width: mix(nest.size.width, full))
            // Op zijn plek is de kaart precies zo hoog als het kaartje, en
            // groot is hij minstens zo hoog als breed: een vierkant. Staat er
            // meer op dan daarin past — een naam over twee regels, twee rijen
            // gezichtjes — dan rekt hij mee. Wat overblijft valt boven en
            // onder de inhoud, want die staat in het midden.
            //
            // Geen `Spacer` hierbinnen: die neemt alle hoogte die het scherm
            // aanbiedt, en dan wordt de kaart zo lang als de bladzijde.
            .frame(minHeight: mix(nest.size.height, full))
        }
        .opacity(seen ? 1 : 0)
        // Een kaart die onzichtbaar op zijn plek ligt te wachten mag geen tik
        // opvangen; daar hoort de achtergrond te sluiten.
        .allowsHitTesting(seen)
        .animation(Motion.quick, value: seen)
        .offset(x: mix(nest.shift.width, 0), y: mix(nest.shift.height, 0))
        .accessibilityIdentifier(current ? "focus.card" : "")
    }

    /// De gezichtjes staan niet in een laag die ze opnieuw indeelt, maar elk
    /// op een plek tussen twee plekken in. Op het kaartje passen er twee naast
    /// elkaar en valt de derde eronder; groot staan ze op één rij. Liet je een
    /// gewone laag dat halverwege omgooien, dan sprong de hele tros in één
    /// beeld van twee rijen naar één — en dat is de klik die je zag.
    private var faces: some View {
        let small = spots(taking.count, width: nest.size.width - m.cardX * 2,
                          item: m.ringSize, itemHeight: m.ringSize,
                          gap: 2, rowGap: 2)
        let big = spots(taking.count, width: full - 52,
                        item: m.focusRing, itemHeight: m.focusRing + 6 + 15,
                        gap: 12, rowGap: 10)

        return ZStack {
            ForEach(Array(taking.enumerated()), id: \.element.id) { (i, person) in
                face(person)
                    .offset(x: mix(small.places[i].x, big.places[i].x),
                            y: mix(small.places[i].y, big.places[i].y))
            }
        }
        .frame(height: mix(small.height, big.height))
    }

    private func face(_ person: Person) -> some View {
        let key = checkKey(routine, step.key, person.id)
        return VStack(spacing: mix(0, 6)) {
            Ring(
                person: person,
                stepName: step.label,
                stepId: "focus.\(step.key)",
                on: household.checks[key] == true,
                size: mix(m.ringSize, m.focusRing),
                faceSize: mix(m.faceSize, m.focusFace),
                glyphSize: mix(m.glyphSize, m.focusGlyph),
                stroke: mix(2.5, m.focusStroke),
                onTap: { household.toggle(key) }
            )
            // De naam staat niet op het kaartje; hij komt er in de tweede
            // helft van de beweging bij.
            Text(person.name)
                .textStyle(Fonts.childName)
                .foregroundStyle(palette.muted)
                .lineLimit(1)
                .opacity(Double(min(1, max(0, part * 1.6 - 0.6))))
                .frame(height: mix(0, 15))
                .accessibilityHidden(true)
        }
    }
}
