import SwiftUI
import UIKit

/// Waar een veeg niet van bladzijde mag wisselen, omdat er iets anders op
/// vegen luistert (de dagen van de weekstrook bladeren door de weken).
@MainActor
@Observable
final class SwipeZones {
    var blocked: [String: CGRect] = [:]
}

/// Een horizontale veeg over de bladzijden, als UIKit-herkenner. Die begint
/// pas als de vinger duidelijk opzij gaat, laat een verticale veeg aan de
/// ScrollView, en trekt — net als een ScrollView — de aanraking weg bij de
/// knop waar de vinger op begon, zodat die niet alsnog afgaat.
struct PageSwipe: UIViewRepresentable {
    var shouldBegin: (CGPoint) -> Bool
    var changed: (CGFloat) -> Void
    var ended: (CGFloat, CGFloat) -> Void

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.pan.addTarget(context.coordinator, action: #selector(Coordinator.panned(_:)))
        anchor.pan.delegate = context.coordinator
        return anchor
    }

    func updateUIView(_ anchor: Anchor, context: Context) {
        context.coordinator.swipe = self
        context.coordinator.anchor = anchor
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Onzichtbaar en niet aanraakbaar; het hangt de herkenner aan de
    /// bovenste view onder het venster, zodat elke aanraking op de
    /// bladzijden erlangs komt, ook die op SwiftUI-knoppen.
    final class Anchor: UIView {
        let pan = UIPanGestureRecognizer()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, pan.view == nil else { return }
            var host: UIView = self
            while let up = host.superview, up !== window { host = up }
            host.addGestureRecognizer(pan)
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil { pan.view?.removeGestureRecognizer(pan) }
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var swipe: PageSwipe
        weak var anchor: Anchor?

        init(_ swipe: PageSwipe) { self.swipe = swipe }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer,
                  let host = pan.view, let anchor else { return false }
            let shift = pan.translation(in: host)
            guard abs(shift.x) > abs(shift.y) else { return false }
            let place = pan.location(in: host)
            guard anchor.convert(anchor.bounds, to: host).contains(place) else { return false }
            return swipe.shouldBegin(host.convert(place, to: nil))
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }

        @objc func panned(_ pan: UIPanGestureRecognizer) {
            guard let host = pan.view else { return }
            switch pan.state {
            case .changed:
                swipe.changed(pan.translation(in: host).x)
            case .ended:
                swipe.ended(pan.translation(in: host).x, pan.velocity(in: host).x)
            case .cancelled, .failed:
                swipe.ended(pan.translation(in: host).x, 0)
            default:
                break
            }
        }
    }
}
