import SwiftUI
import UIKit

enum SafeArea {
    static var top: CGFloat { window?.safeAreaInsets.top ?? 0 }
    static var bottom: CGFloat { window?.safeAreaInsets.bottom ?? 0 }

    private static var window: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.keyWindow
    }
}

/// Hoeveel kinderen er naast elkaar staan, of het nu de gezichtjes op een
/// kaartje zijn of de balkjes in de kop: tot drie op een rij, met z'n vieren
/// twee bij twee — vier op een rij worden strookjes — en met z'n vijven drie
/// en twee.
func childrenPerRow(_ count: Int) -> Int {
    let count = max(1, count)
    return count == 4 ? 2 : min(3, count)
}

struct Flow: Layout {
    var gap: CGFloat = 6
    var rowGap: CGFloat = 6
    var centered: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = split(width: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + rowGap * CGFloat(max(0, rows.count - 1))
        let used = rows.map { $0.width }.max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout Void) {
        let rows = split(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (centered ? (bounds.width - row.width) / 2 : 0)
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + gap
            }
            y += row.height + rowGap
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func split(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let grown = current.items.isEmpty ? size.width : current.width + gap + size.width
            if !current.items.isEmpty && grown > width {
                rows.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + gap + size.width
            current.height = max(current.height, size.height)
            current.items.append(i)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
