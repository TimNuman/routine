// Een brede knop op glas, zoals 'Iets bijzonders toevoegen' onder de agenda.
import SwiftUI

struct Kaartknop: View {
    var teken: String? = nil
    var plus: Bool = false
    let opschrift: String
    let opTik: () -> Void

    @Environment(\.palet) private var palet

    init(_ opschrift: String, teken: String? = nil, plus: Bool = false,
         opTik: @escaping () -> Void) {
        self.opschrift = opschrift
        self.teken = teken
        self.plus = plus
        self.opTik = opTik
    }

    var body: some View {
        Button {
            Trilling.tik()
            opTik()
        } label: {
            Glas(radius: 22) {
                HStack(spacing: 10) {
                    if plus {
                        Rondbolletje()
                    } else {
                        Text(teken ?? "")
                            .font(.system(size: 20))
                            .frame(width: 28)
                    }
                    Text(opschrift)
                        .letter(L.kaartknop)
                        .foregroundStyle(palet.zacht)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.druk)
        .padding(.top, 14)
    }
}

// Het groene plusje: hetzelfde bolletje als in de bewerkschermen.
struct Rondbolletje: View {
    var teken: String = "+"
    var kleur: Color = GROEN

    var body: some View {
        ZStack {
            Circle().fill(kleur)
            Text(teken)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }
}
