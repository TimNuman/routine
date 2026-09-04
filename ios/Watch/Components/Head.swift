import SwiftUI

/// De dag en de datum, bovenaan de eerste bladzijde. Welke dag het is staat
/// er groot bij, want dat is waar je op het horloge het eerst naar kijkt.
struct Head: View {
    let now: Date

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(weekday)
                .textStyle(Wrist.title)
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(now.formatted(.dateTime.day().month(.wide).locale(.autoupdatingCurrent)))
                .textStyle(Wrist.date)
                .foregroundStyle(palette.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    /// De kalender van het toestel geeft hem klein; bovenaan een bladzijde
    /// hoort hij met een hoofdletter.
    private var weekday: String {
        let raw = now.formatted(.dateTime.weekday(.wide).locale(.autoupdatingCurrent))
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }
}
