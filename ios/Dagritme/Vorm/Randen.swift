// De veilige rand onderaan. SwiftUI regelt die zelf zolang iets binnen de
// veilige zone blijft, maar een blad dat vanaf de onderkant omhoog komt loopt er
// juist doorheen — en moet zijn inhoud er dan zelf bovenhouden.
import SwiftUI
import UIKit

enum Randen {
    static var onder: CGFloat { venster?.safeAreaInsets.bottom ?? 0 }

    private static var venster: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.keyWindow
    }
}

// Een vloeiende rij: chips die doorlopen op de volgende regel zodra ze niet meer
// naast elkaar passen. Dat is wat flex-wrap op web doet.
struct Vloeiend: Layout {
    var gat: CGFloat = 6
    var rijgat: CGFloat = 6
    // De rondjes op een kaartje staan in het midden; chips beginnen links.
    var midden: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let breedte = proposal.width ?? .infinity
        let rijen = verdeel(breedte: breedte, subviews: subviews)
        let hoogte = rijen.reduce(0) { $0 + $1.hoogte } + rijgat * CGFloat(max(0, rijen.count - 1))
        let gebruikt = rijen.map { $0.breedte }.max() ?? 0
        return CGSize(width: proposal.width ?? gebruikt, height: hoogte)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout Void) {
        let rijen = verdeel(breedte: bounds.width, subviews: subviews)
        var y = bounds.minY
        for rij in rijen {
            var x = bounds.minX + (midden ? (bounds.width - rij.breedte) / 2 : 0)
            for i in rij.stukken {
                let maat = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(maat))
                x += maat.width + gat
            }
            y += rij.hoogte + rijgat
        }
    }

    private struct Rij {
        var stukken: [Int] = []
        var breedte: CGFloat = 0
        var hoogte: CGFloat = 0
    }

    private func verdeel(breedte: CGFloat, subviews: Subviews) -> [Rij] {
        var rijen: [Rij] = []
        var nu = Rij()
        for i in subviews.indices {
            let maat = subviews[i].sizeThatFits(.unspecified)
            let erbij = nu.stukken.isEmpty ? maat.width : nu.breedte + gat + maat.width
            if !nu.stukken.isEmpty && erbij > breedte {
                rijen.append(nu)
                nu = Rij()
            }
            nu.breedte = nu.stukken.isEmpty ? maat.width : nu.breedte + gat + maat.width
            nu.hoogte = max(nu.hoogte, maat.height)
            nu.stukken.append(i)
        }
        if !nu.stukken.isEmpty { rijen.append(nu) }
        return rijen
    }
}
