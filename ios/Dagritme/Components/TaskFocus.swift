import SwiftUI

/// Welke stap er boven op de stapel ligt, en waar de kaartjes in het raster
/// liggen.
///
/// Zolang er een stap groot staat is het raster leeg: de kaartjes liggen dan
/// als stapel in het midden van het scherm. De stap die je opende komt uit
/// zijn eigen kaartje omhoog en zakt daar ook weer in terug.
@MainActor
@Observable
final class Focus {
    private(set) var tasks: [Step] = []
    private(set) var routine: Routine = .day
    private(set) var index = 0
    /// Het kaartje waar de kaart net in terugzakte. Dat ene kaartje moet er
    /// meteen weer liggen — de kaart vervaagt eroverheen — terwijl de rest
    /// van het raster rustig terugkomt.
    private(set) var landing: String?

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
        landing = nil
    }

    /// Eén kaart verder op de stapel, of er eentje terug.
    func go(to target: Int) {
        guard tasks.indices.contains(target), target != index else { return }
        index = target
    }

    func close() {
        landing = step(index)?.key
        tasks = []
        index = 0
    }

    /// Ligt het raster van dit ritme even weg? De kaartjes en de kopjes zijn
    /// dan niet te zien: ze liggen op de stapel.
    func hides(_ routine: Routine) -> Bool { open && routine == self.routine }

    /// Is dit het kaartje van de kaart die boven op de stapel ligt, of dat
    /// waar hij net in terugzakte? Dat kaartje gaat ineens weg en komt ineens
    /// terug; de rest van het raster vervaagt.
    func swapped(_ routine: Routine, _ key: String) -> Bool {
        guard routine == self.routine else { return false }
        return key == step(index)?.key || key == landing
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
                   itemHeight: CGFloat, gap: CGFloat, rowGap: CGFloat,
                   perRow fixed: Int? = nil) -> Spots {
    guard count > 0 else { return Spots(places: [], height: 0) }
    let perRow = fixed ?? max(1, Int((width + gap) / (item + gap)))
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

/// De stapel: de stap die aan de beurt is ligt bovenop, de volgende liggen
/// eronder — elk een beetje scheef, maar altijd hetzelfde beetje. Naar links
/// vegen legt de bovenste weg en geeft de volgende, naar rechts vegen haalt de
/// vorige er weer bij. De kaart die je opende komt uit zijn kaartje in het
/// raster omhoog en zakt daar bij het sluiten weer in terug; omlaag vegen of
/// naast de stapel tikken doet dat ook.
struct TaskFocus: View {
    let focus: Focus
    let people: [Person]
    let visible: Set<String>

    @Environment(\.metrics) private var m
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ligt de stapel er? Zo niet, dan ligt de bovenste kaart nog als kaartje
    /// op zijn plek in het raster — dat is waar hij vandaan komt en waar hij
    /// heen gaat.
    @State private var shown = false
    @State private var drag = CGSize.zero
    @State private var axis: Axis?

    /// Wat er van de stapel te zien is: de kaart die net weggelegd is, de
    /// bovenste, en een paar die eronder liggen.
    private var deck: [Int] {
        let first = max(0, focus.index - 1)
        let last = min(focus.tasks.count - 1, focus.index + 3)
        return first <= last ? Array(first...last) : []
    }

    var body: some View {
        GeometryReader { space in
            let width = min(space.size.width - m.gutter * 2, m.focusWidth)
            // Het plaatje is zo groot als het mag, maar nooit zo groot dat de
            // kaart niet meer op een laag scherm past.
            let icon = min(m.focusIcon, space.size.height * 0.24)
            let away = space.size.width / 2 + width
            // Naar rechts vegen haalt de vorige kaart terug: die schuift met
            // de vinger mee terug op de stapel terwijl de bovenste blijft
            // liggen. Precies de weg terug van het weggeven, dus.
            let pulling = drag.width > 0 && focus.index > 0
            let pull = pulling ? min(1, drag.width / max(1, width * 0.5)) : 0

            ZStack {
                Color.black.opacity(0.34)
                    .opacity(shown ? 1 - Double(min(0.7, drag.height / 420)) : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .accessibilityIdentifier("focus.backdrop")
                    .accessibilityLabel(Spoken.close)
                    .accessibilityAddTraits(.isButton)

                ForEach(deck, id: \.self) { i in
                    let step = focus.tasks[i]
                    let depth = i - focus.index
                    let rest = depth == -1 && pulling
                        ? blend(lie(step.key, depth: -1, away: away),
                                lie(step.key, depth: 0, away: away), pull)
                        : lie(step.key, depth: depth, away: away)
                    let top = depth == 0
                    // De bovenste kaart loopt alleen met de vinger mee als je
                    // hem weggeeft, niet als je de vorige terughaalt.
                    let follows = top && !pulling
                    let home = nest(space, step)
                    // Alleen de bovenste kaart groeit uit zijn kaartje; de
                    // rest van de stapel ligt er meteen als kaart bij.
                    let grown: CGFloat = (reduceMotion || home == nil)
                        ? 1 : (shown && top ? 1 : 0)

                    MorphCard(t: top ? grown : 1, seen: true, step: step,
                              full: width, icon: icon,
                              nest: home ?? Nest(size: .zero, shift: .zero),
                              taking: taking(step), routine: focus.routine, current: top)
                        .scaleEffect(rest.scale)
                        // De kaart draait met de vinger mee, zoals een kaart
                        // die je van de stapel af schuift.
                        .rotationEffect(.degrees(rest.angle + (follows ? Double(drag.width) / 24 : 0)))
                        .offset(x: rest.x + (follows ? drag.width : 0),
                                y: rest.y + (top ? drag.height : 0))
                        // De kaarten onder de bovenste horen bij de stapel en
                        // niet bij het raster: ze komen erbij als de stapel
                        // er is, en gaan met de stapel weer weg.
                        .opacity(top ? 1 : (shown && depth <= 2 ? 1 : 0))
                        // Wie weggelegd wordt gaat over de stapel heen; de
                        // rest ligt op volgorde.
                        .zIndex(depth < 0 ? 9 : Double(3 - depth))
                        .allowsHitTesting(top)
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
                    // De kaart gaat mee met de vinger. Is er niets meer om
                    // weg te leggen of terug te halen, dan geeft hij alleen
                    // een beetje mee.
                    let sideways = move.translation.width
                    let edge = (sideways > 0 && focus.index == 0)
                        || (sideways < 0 && focus.index >= focus.tasks.count - 1)
                    drag = CGSize(width: edge ? sideways / 3.5 : sideways, height: 0)
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
                // Weggeven mag met een klein duwtje; terughalen pas als de
                // vorige kaart er half op ligt.
                let far = side == 1 ? drag.width < -width * 0.22 : drag.width > width * 0.25
                let flick = abs(move.predictedEndTranslation.width) > width * 0.8
                    && (move.predictedEndTranslation.width < 0) == (side == 1)
                if far || flick {
                    go(to: focus.index + side)
                } else {
                    withAnimation(Motion.lift) { drag = .zero }
                }
            }
    }

    /// De bovenste kaart gaat van de stapel af, of komt erop terug.
    private func go(to target: Int) {
        guard focus.tasks.indices.contains(target) else {
            withAnimation(Motion.lift) { drag = .zero }
            return
        }
        Haptics.select()
        withAnimation(Motion.deal) {
            focus.go(to: target)
            drag = .zero
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

/// Hoe een kaart op de stapel ligt: een beetje verschoven en een beetje
/// scheef, dieper in de stapel wat meer. Het hoort bij de kaart zelf — het
/// komt uit zijn naam — dus hij blijft liggen zoals hij ligt terwijl de
/// stapel onder hem slinkt.
private struct Lie {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Double = 0
    var scale: CGFloat = 1
}

private func scatter(_ key: String) -> (Double, Double, Double) {
    var seed: UInt64 = 5381
    for byte in key.utf8 { seed = seed &* 33 &+ UInt64(byte) }
    let spread = { (shift: UInt64) in Double((seed >> shift) % 997) / 498.5 - 1 }
    return (spread(3), spread(13), spread(23))
}

/// Half toeval, half zekerheid: de kaart wijkt altijd minstens een halve
/// slag uit, zodat er geen kaart precies recht onder de bovenste verdwijnt.
private func nudge(_ part: Double, _ span: Double) -> Double {
    (part * 0.5 + (part < 0 ? -0.5 : 0.5)) * span
}

/// Onderweg tussen twee plekken op de stapel: zo komt de vorige kaart met de
/// vinger mee terug.
private func blend(_ from: Lie, _ to: Lie, _ part: CGFloat) -> Lie {
    Lie(x: from.x + (to.x - from.x) * part,
        y: from.y + (to.y - from.y) * part,
        angle: from.angle + (to.angle - from.angle) * Double(part),
        scale: from.scale + (to.scale - from.scale) * part)
}

private func lie(_ key: String, depth: Int, away: CGFloat) -> Lie {
    let (x, y, angle) = scatter(key)
    // Van de stapel af: naar links het beeld uit, met een zwaai.
    guard depth >= 0 else {
        return Lie(x: -away, y: y * 12 + 24, angle: angle * 5 - 15)
    }
    let deep = Double(min(depth, 3))
    return Lie(x: CGFloat(nudge(Double(x), 7 + deep * 7)),
               y: CGFloat(nudge(Double(y), 5 + deep * 6)) + deep * 4,
               angle: nudge(angle, 2.6 + deep * 2))
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
        Paper(radius: mix(m.cardRadius, full * 0.17), floating: true,
              lift: mix(0.25, 1.5)) {
            // Precies de opbouw van het kaartje in het raster: het plaatje
            // en de naam tussen twee veren, en de gezichtjes daaronder. Dus
            // ook dezelfde verdeling van de ruimte die overblijft — die valt
            // boven het plaatje en tussen de naam en de gezichtjes, en niet
            // onder de gezichtjes.
            VStack(spacing: 0) {
                // Drie veren om dezelfde ruimte: boven het plaatje, tussen
                // het plaatje en de naam, en tussen de naam en de gezichtjes.
                // Wat er overblijft valt zo overal even ruim uit.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(step.icon)
                        .font(.system(size: mix(m.iconSize, icon)))
                        .scaleEffect(allDone ? 1.12 : 1)
                        .animation(Motion.pop, value: allDone)
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    Text(step.label)
                        .textStyle(Fonts.taskName(mix(m.nameSize, m.focusName)))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        // Een emoji laat zelf al een stuk wit onder zich; dat
                        // telt mee als ruimte, dus de naam schuift er weer in.
                        .padding(.top, mix(0, -10))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                faces
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
            // gezichtjes — dan rekt hij mee.
            .frame(minHeight: mix(nest.size.height, full))
        }
        // Een veer pakt alles wat er aan hoogte aangeboden wordt, en hier
        // biedt het scherm zijn volle hoogte aan. Op zijn eigen maat vastzetten
        // maakt ze weer wat ze op het kaartje zijn: verdelers van wat er
        // overblijft, niet van wat er is.
        .fixedSize(horizontal: false, vertical: true)
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
        let room = full - 52
        // Groot staan ze het liefst op één rij — op een iPad passen er vier —
        // en anders breken ze af zoals op het kaartje.
        let side = CGFloat(taking.count) * m.focusRing + CGFloat(taking.count - 1) * 12
        let small = spots(taking.count, width: nest.size.width - m.cardX * 2,
                          item: m.ringSize, itemHeight: m.ringSize,
                          gap: 2, rowGap: 2, perRow: childrenPerRow(taking.count))
        let big = spots(taking.count, width: room,
                        item: m.focusRing, itemHeight: m.focusRing + 6 + 15,
                        gap: 12, rowGap: 10,
                        perRow: side <= room ? taking.count : childrenPerRow(taking.count))

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
