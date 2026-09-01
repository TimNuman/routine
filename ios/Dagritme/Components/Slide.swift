import SwiftUI

/// Twee bakjes: het toneel, met de bladzijde die er staat, en ernaast een
/// tweede voor wat eraan komt. Een bakje krijgt een vaste plek zolang er iets
/// in zit; alleen de rij eromheen schuift, op één veer, dus de bakjes blijven
/// precies één breedte uit elkaar. Wie tijdens de schuif nog eens tikt,
/// verandert alleen wat er in een bakje zit — dat vervaagt naar de nieuwe
/// bladzijde terwijl het bakje doorschuift — of keert de schuif om als het de
/// andere kant op moet. Er zijn nooit meer dan twee bladzijden, en er
/// verdwijnt onderweg niets.
@MainActor
@Observable
final class Slide<Key: CaseIterable & Hashable> {
    /// Wat er in de twee bakjes zit; in rust is er één leeg.
    private(set) var trays: [Key?]
    /// De vorige bladzijde van een bakje, die nog vervaagt over de nieuwe.
    /// Hij blijft in de boom, want wat SwiftUI weghaalt schuift niet meer mee.
    private(set) var ghosts: [Key?] = [nil, nil]
    private(set) var ghostAlpha: [Double] = [0, 0]
    /// De plek van elk bakje in de rij, in breedtes; telt alleen als het vol is.
    private(set) var lanes = [0, 1]
    /// Welk bakje het toneel is.
    private(set) var stageIndex = 0
    /// De plek die in beeld hoort; de rij veert erheen.
    private(set) var eye = 0
    /// Hoe ver een vinger de rij opzij heeft getrokken, in punten.
    private(set) var drag: CGFloat = 0

    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var fades = [0, 0]
    /// Aan welke kant de vinger een buur heeft opgehaald; 0 als er geen vinger is.
    @ObservationIgnored private var draggingSide = 0

    init(_ stage: Key) {
        trays = [stage, nil]
    }

    var stage: Key { trays[stageIndex]! }
    /// De bladzijde waar de rij naartoe onderweg is (in rust: het toneel).
    var arriving: Key { trays[lanes[0] == eye ? 0 : 1] ?? stage }

    /// Zonder schuif, voor de eerste keer.
    func jump(to key: Key) {
        generation += 1
        still {
            trays = [key, nil]
            ghosts = [nil, nil]
            lanes = [0, 1]
            stageIndex = 0
            eye = 0
            drag = 0
        }
        draggingSide = 0
    }

    func go(to target: Key) {
        let other = 1 - stageIndex
        guard trays[other] != nil else {
            guard target != stage else { return }
            still {
                lanes[other] = lanes[stageIndex] + side(target, of: stage)
                trays[other] = target
            }
            run(to: lanes[other])
            return
        }

        // Onderweg: één bakje komt aan, het andere gaat weg. Wat weggaat was
        // in beeld; dáár ligt de vraag naast: welke kant zit de nieuwe op?
        let arriving = lanes[stageIndex] == eye ? stageIndex : other
        let leaving = 1 - arriving
        guard target != trays[arriving] else { return }
        let arrivingSide = lanes[arriving] > lanes[leaving] ? 1 : -1

        if side(target, of: trays[leaving]!) == arrivingSide {
            // Dezelfde kant op: alleen de inhoud van het aankomende bakje wisselt.
            swap(arriving, to: target)
        } else {
            // De andere kant op: het bakje dat wegging keert om, met de
            // gevraagde bladzijde erop.
            if target != trays[leaving] { swap(leaving, to: target) }
            run(to: lanes[leaving])
        }
    }

    /// Meeschuiven met een vinger. `neighbour` zegt wat er aan een kant ligt
    /// (1 rechts, -1 links); ligt daar niets, dan geeft de rij een beetje mee
    /// en veert hij straks terug.
    func drag(to translation: CGFloat, neighbour: (Int) -> Key?) {
        let other = 1 - stageIndex
        let side = translation < 0 ? 1 : -1
        if draggingSide == 0 {
            guard trays[other] == nil else { return }
        }
        if side != draggingSide {
            draggingSide = side
            still {
                ghosts[other] = nil
                if let key = neighbour(side) {
                    lanes[other] = lanes[stageIndex] + side
                    trays[other] = key
                } else {
                    trays[other] = nil
                }
            }
        }
        still { drag = trays[other] == nil ? translation / 3 : translation }
    }

    /// De vinger gaat los: door naar de buur als hij ver of snel genoeg ging,
    /// anders terug. Geeft de buur terug als het doorgaat.
    @discardableResult
    func release(velocity: CGFloat, span: CGFloat) -> Key? {
        guard draggingSide != 0 else { return nil }
        let side = draggingSide
        draggingSide = 0
        let other = 1 - stageIndex
        let far = abs(drag) > span * 0.35
        let flick = abs(velocity) > 250 && (velocity < 0) == (side == 1)
        let goes = trays[other] != nil && (far || flick)
        run(to: goes ? lanes[other] : lanes[stageIndex])
        return goes ? trays[other] : nil
    }

    /// Wisselt de inhoud van een bakje: de oude bladzijde blijft er als
    /// geest overheen liggen en vervaagt.
    private func swap(_ i: Int, to target: Key) {
        fades[i] += 1
        let mine = fades[i]
        still {
            ghosts[i] = trays[i]
            ghostAlpha[i] = 1
            trays[i] = target
        }
        withAnimation(Motion.fade, completionCriteria: .removed) {
            ghostAlpha[i] = 0
        } completion: { [weak self] in
            guard let self, fades[i] == mine else { return }
            still { self.ghosts[i] = nil }
        }
    }

    private func run(to lane: Int) {
        generation += 1
        let mine = generation
        draggingSide = 0
        withAnimation(Motion.glide, completionCriteria: .removed) {
            eye = lane
            drag = 0
        } completion: { [weak self] in
            guard let self, generation == mine else { return }
            still {
                let arrived = self.lanes[0] == self.eye ? 0 : 1
                self.stageIndex = arrived
                self.trays[1 - arrived] = nil
            }
        }
    }

    /// Buiten elke animatie om, ook als we in een geanimeerde update zitten.
    private func still(_ change: () -> Void) {
        var plain = Transaction()
        plain.disablesAnimations = true
        withTransaction(plain, change)
    }

    private func side(_ a: Key, of b: Key) -> Int {
        let all = Array(Key.allCases)
        return (all.firstIndex(of: a) ?? 0) > (all.firstIndex(of: b) ?? 0) ? 1 : -1
    }
}

/// Schuift de rij naar het oog. Als Animatable krijgt hij elk beeld de
/// tussenwaarde van de veer en zet die als gewone offset; zo staat ook een
/// bladzijde die halverwege in een bakje wordt gezet meteen op de goede plek,
/// in plaats van dat SwiftUI haar apart laat aanschuiven.
private struct Sliding: ViewModifier, Animatable {
    var eye: CGFloat
    var drag: CGFloat
    let span: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(eye, drag) }
        set { eye = newValue.first; drag = newValue.second }
    }

    func body(content: Self.Content) -> some View {
        content.offset(x: -eye * span + drag)
    }
}

/// De rij met de twee bakjes; `span` is hoe ver ze uit elkaar staan.
struct SlideView<Key: CaseIterable & Hashable, Page: View>: View {
    let slide: Slide<Key>
    let span: CGFloat
    @ViewBuilder let page: (Key) -> Page

    var body: some View {
        // Bovenaan uitgelijnd: een korter paneel mag niet in het midden
        // hangen naast een langer, en dan verspringen als dat weg is.
        ZStack(alignment: .topLeading) {
            ForEach(0..<2, id: \.self) { i in
                if let key = slide.trays[i] {
                    ZStack(alignment: .topLeading) {
                        page(key).id(key).transition(.identity)
                        if let ghost = slide.ghosts[i] {
                            page(ghost).id(ghost)
                                .opacity(slide.ghostAlpha[i])
                                .allowsHitTesting(false)
                                .transition(.identity)
                        }
                    }
                    .offset(x: CGFloat(slide.lanes[i]) * span)
                    .transition(.identity)
                }
            }
        }
        .modifier(Sliding(eye: CGFloat(slide.eye), drag: slide.drag, span: span))
    }
}
