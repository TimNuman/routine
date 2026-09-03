import SwiftUI

/// Welke stap er groot staat, en waar de kaartjes in het raster liggen om
/// uit te groeien en weer in terug te zakken.
@MainActor
@Observable
final class Focus {
    private(set) var tasks: [Step] = []
    private(set) var routine: Routine = .day
    var index = 0

    /// De plek van elk kaartje op het scherm. Die schuift bij elke scrolstap
    /// op, dus hij staat bewust buiten de tekentoestand: niemand hoeft
    /// daarvoor opnieuw getekend te worden, het wordt alleen gelezen op het
    /// moment dat de grote kaart open- of dichtgaat.
    @ObservationIgnored private var spots: [String: CGRect] = [:]

    var open: Bool { !tasks.isEmpty }

    var task: Step? { tasks.indices.contains(index) ? tasks[index] : nil }

    func show(_ tasks: [Step], at index: Int, routine: Routine) {
        guard tasks.indices.contains(index) else { return }
        self.tasks = tasks
        self.index = index
        self.routine = routine
    }

    func close() {
        tasks = []
        index = 0
    }

    func place(_ routine: Routine, _ step: String, _ frame: CGRect?) {
        spots["\(routine.rawValue)/\(step)"] = frame
    }

    func spot(_ step: String) -> CGRect? { spots["\(routine.rawValue)/\(step)"] }
}

/// De stap groot: over de volle breedte van het scherm, met een rand eromheen.
/// Hij groeit uit het kaartje waar de vinger op stond en zakt daar ook weer in
/// terug. Vegen gaat naar de vorige of de volgende stap, omlaag vegen of naast
/// de kaart tikken legt hem weg. De gezichtjes werken hier net zo als op het
/// kaartje, alleen groter.
struct TaskFocus: View {
    let focus: Focus
    let people: [Person]
    let visible: Set<String>

    @Environment(Household.self) private var household
    @Environment(\.metrics) private var m
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    /// De buren doen pas mee als de kaart er helemaal is. Tijdens het groeien
    /// staat de hele rij klein op de plek van één kaartje, en dan zouden ze
    /// ernaast in beeld staan mee te groeien.
    @State private var ready = false
    @State private var drag = CGSize.zero
    @State private var axis: Axis?

    var body: some View {
        GeometryReader { space in
            let width = min(space.size.width - m.gutter * 2, m.focusWidth)
            // Het plaatje is zo groot als het mag, maar nooit zo groot dat de
            // kaart niet meer op een laag scherm past.
            let icon = min(m.focusIcon, space.size.height * 0.24)
            // De kaarten liggen precies een schermbreedte uit elkaar, dus de
            // buren staan in rust net buiten beeld.
            let span = width + m.gutter
            let from = start(space, width)

            ZStack {
                Color.black.opacity(0.34)
                    .opacity(shown ? 1 - Double(min(0.7, drag.height / 420)) : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .accessibilityIdentifier("focus.backdrop")
                    .accessibilityLabel(Spoken.close)
                    .accessibilityAddTraits(.isButton)

                row(width: width, icon: icon, span: span)
                    .frame(width: space.size.width)
                    .scaleEffect(shown ? 1 : from.scale)
                    .offset(x: shown ? 0 : from.offset.width,
                            y: shown ? 0 : from.offset.height)
                    .opacity(shown ? 1 : 0)
            }
            .contentShape(Rectangle())
            .gesture(swipe(width))
        }
        .onAppear {
            withAnimation(reduceMotion ? Motion.fade : Motion.spring) {
                shown = true
            } completion: {
                // Op een breed scherm staat een buur nog net in beeld; daar
                // komt hij zacht op, in plaats van er ineens te staan.
                withAnimation(Motion.fade) { ready = true }
            }
        }
    }

    /// De kaarten naast elkaar; alleen die in beeld kan komen wordt echt
    /// getekend, de rest houdt zijn plek vrij.
    private func row(width: CGFloat, icon: CGFloat, span: CGFloat) -> some View {
        HStack(spacing: m.gutter) {
            ForEach(Array(focus.tasks.enumerated()), id: \.offset) { (i, step) in
                if abs(i - focus.index) <= 1 {
                    card(step, width: width, icon: icon, current: i == focus.index)
                        .opacity(i == focus.index || ready ? 1 : 0)
                } else {
                    Color.clear.frame(width: width)
                }
            }
        }
        .offset(x: lane(span), y: drag.height)
    }

    /// Hoe ver de rij opzij staat: de kaart waar je bent in het midden, plus
    /// wat de vinger er nu bij trekt.
    private func lane(_ span: CGFloat) -> CGFloat {
        let middle = CGFloat(focus.tasks.count - 1) / 2
        return (middle - CGFloat(focus.index)) * span + drag.width
    }

    private func card(_ step: Step, width: CGFloat, icon: CGFloat,
                      current: Bool) -> some View {
        let taking = participants(step, people).filter { visible.contains($0.id) }

        // Een dikkere rand en een diepere schaduw: op dit formaat mag de
        // kaart bol staan in plaats van als een velletje glas.
        return Glass(radius: corner(width), floating: true,
                     line: 3, lift: 1.5, bulge: 9) {
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

    /// Waar de kaart uit groeit: het kaartje in het raster, als dat nog in
    /// beeld staat. Weet niemand waar het ligt, dan doemt hij op zijn plek op.
    private func start(_ space: GeometryProxy, _ width: CGFloat)
        -> (scale: CGFloat, offset: CGSize) {
        guard !reduceMotion else { return (1, .zero) }
        guard let key = focus.task?.key, let spot = focus.spot(key), spot.width > 0 else {
            return (0.9, .zero)
        }
        let mine = space.frame(in: .global)
        return (
            max(0.15, spot.width / width),
            CGSize(width: spot.midX - mine.minX - space.size.width / 2,
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
                    let sideways = move.translation.width
                    // Aan het begin en het eind is er geen buur: dan geeft de
                    // rij een beetje mee en veert hij zo terug.
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
                let far = abs(drag.width) > width * 0.3
                let flick = abs(move.predictedEndTranslation.width) > width * 0.8
                    && (move.predictedEndTranslation.width < 0) == (side == 1)
                if far || flick {
                    go(to: focus.index + side)
                } else {
                    withAnimation(Motion.glide) { drag = .zero }
                }
            }
    }

    private func go(to target: Int) {
        guard focus.tasks.indices.contains(target) else {
            withAnimation(Motion.glide) { drag = .zero }
            return
        }
        Haptics.select()
        withAnimation(Motion.glide) {
            focus.index = target
            drag = .zero
        }
    }

    private func close() {
        // Eerst de buren weg, dan pas krimpen: anders zakken ze mee.
        ready = false
        withAnimation(Motion.short) {
            shown = false
            drag = .zero
        }
        axis = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { focus.close() }
    }
}
