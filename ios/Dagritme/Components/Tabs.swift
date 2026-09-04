import SwiftUI
import UIKit

/// Wat er op één knop van de menubalk staat.
struct TabItem {
    let tab: Tab
    let name: String
    let symbol: String
    let id: String
}

/// De menubalk van iOS, met de bladzijden die er van opzij in schuiven.
///
/// SwiftUI's eigen `TabView` wisselt zonder beweging, en er is geen knop om
/// dat om te zetten. `UITabBarController` heeft daar wél een haakje voor —
/// `animationControllerForTransitionFrom` — en krijgt op iOS 26 precies
/// dezelfde balk van vloeibaar glas, met de veeg erover die van tabblad
/// wisselt. Dus staat de balk hier in UIKit, met elk scherm in zijn eigen
/// `UIHostingController`.
struct GlassTabs<Page: View>: UIViewControllerRepresentable {
    /// Welk tabblad er open staat. Een gewone waarde en geen binding: zo
    /// leest het scherm hem in zijn body, en komt een wissel van buitenaf —
    /// de Driver bijvoorbeeld — hier ook langs.
    let chosen: Tab
    let onPick: (Tab) -> Void
    let items: [TabItem]
    /// Een blad legt zich over het hele scherm; dan gaat de balk weg.
    let barHidden: Bool
    @ViewBuilder var page: (Tab) -> Page

    func makeUIViewController(context: Context) -> UITabBarController {
        let bars = UITabBarController()
        bars.delegate = context.coordinator
        // Op de iPad hangt de balk van iOS 26 bovenaan, naast de titel. Hier
        // is hij geen bladwijzer maar een knop voor kinderduimen, dus vragen
        // we de balk die de iPhone krijgt: zwevend, met de knoppen midden
        // onderaan. Dat is dezelfde balk, alleen op de smalle maat gezet.
        bars.traitOverrides.horizontalSizeClass = .compact
        // Overdag inkt op het lichte glas: het oranje van de app loopt daar
        // weg tegen het grijs van de gekozen knop. 's Avonds mag het wel.
        bars.tabBar.tintColor = UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? ORANGE : INK)
        }
        bars.viewControllers = items.map { item in
            let host = UIHostingController(rootView: page(item.tab))
            // De bladzijde zelf blijft wél een iPad-bladzijde; alleen de balk
            // doet of het scherm smal is.
            host.traitOverrides.horizontalSizeClass = .regular
            // De bladzijde tekent haar eigen hemel; daaronder hoeft niets.
            host.view.backgroundColor = .clear
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.tabBarItem = knob(item)
            return host
        }
        bars.selectedIndex = place(of: chosen)
        return bars
    }

    func updateUIViewController(_ bars: UITabBarController, context: Context) {
        context.coordinator.tabs = self

        for (i, item) in items.enumerated() {
            guard let host = bars.viewControllers?[i] as? UIHostingController<Page> else { continue }
            // Opnieuw opbouwen, zodat wat er van buiten in gaat — de maten,
            // de intrede — meeloopt. De toestand binnenin houdt SwiftUI vast.
            host.rootView = page(item.tab)
        }

        let want = place(of: chosen)
        if bars.selectedIndex != want { bars.selectedIndex = want }
        context.coordinator.show(bar: !barHidden, on: bars)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func place(of tab: Tab) -> Int {
        items.firstIndex { $0.tab == tab } ?? 0
    }

    private func knob(_ item: TabItem) -> UITabBarItem {
        let knob = UITabBarItem(title: item.name,
                                image: UIImage(systemName: item.symbol),
                                selectedImage: nil)
        // De stromen wijzen de balk hierop aan; in SwiftUI valt er geen naam
        // op een tabblad te plakken, in UIKit wel.
        knob.accessibilityIdentifier = item.id
        return knob
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var tabs: GlassTabs
        private var barShown: Bool?

        init(_ tabs: GlassTabs) { self.tabs = tabs }

        func show(bar shown: Bool, on bars: UITabBarController) {
            guard shown != barShown else { return }
            let first = barShown == nil
            barShown = shown
            bars.tabBar.isUserInteractionEnabled = shown
            let settle: () -> Void = {
                bars.tabBar.alpha = shown ? 1 : 0
                bars.tabBar.transform = shown ? .identity
                                              : CGAffineTransform(translationX: 0, y: 30)
            }
            guard !first else { return settle() }
            UIView.animate(withDuration: shown ? 0.38 : 0.20,
                           delay: 0, usingSpringWithDamping: 0.9,
                           initialSpringVelocity: 0, options: [],
                           animations: settle, completion: nil)
        }

        func tabBarController(_ bars: UITabBarController, didSelect picked: UIViewController) {
            guard let i = bars.viewControllers?.firstIndex(of: picked),
                  tabs.items.indices.contains(i) else { return }
            let tab = tabs.items[i].tab
            if tabs.chosen != tab { tabs.onPick(tab) }
        }

        /// Welke kant het op gaat komt uit de plek in de balk: naar rechts
        /// komt de nieuwe bladzijde van rechts binnen, en gaat de oude naar
        /// links het beeld uit.
        func tabBarController(_ bars: UITabBarController,
                              animationControllerForTransitionFrom leaving: UIViewController,
                              to arriving: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            guard let here = bars.viewControllers?.firstIndex(of: leaving),
                  let there = bars.viewControllers?.firstIndex(of: arriving) else { return nil }
            return Sideways(side: there > here ? 1 : -1)
        }
    }
}

/// De schuif zelf: de twee bladzijden liggen naast elkaar en de rij schuift er
/// één breedte langs, op een veer met net zo weinig nadeining als `Motion.glide`.
private final class Sideways: NSObject, UIViewControllerAnimatedTransitioning {
    let side: CGFloat

    init(side: CGFloat) { self.side = side }

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.44
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let leaving = context.viewController(forKey: .from),
              let arriving = context.viewController(forKey: .to) else {
            return context.completeTransition(false)
        }
        let stage = context.containerView
        let span = stage.bounds.width

        arriving.view.frame = stage.bounds
        arriving.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arriving.view.transform = CGAffineTransform(translationX: side * span, y: 0)
        stage.addSubview(arriving.view)

        let glide = UIViewPropertyAnimator(duration: transitionDuration(using: context),
                                           dampingRatio: 0.92) {
            leaving.view.transform = CGAffineTransform(translationX: -self.side * span, y: 0)
            arriving.view.transform = .identity
        }
        glide.addCompletion { _ in
            leaving.view.transform = .identity
            arriving.view.transform = .identity
            context.completeTransition(!context.transitionWasCancelled)
        }
        glide.startAnimation()
    }
}
