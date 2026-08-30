// Het weekritme naast de stappen: wat er die dag verder nog is. Een eenmalig
// ding krijgt een oranje randje links, zodat het opvalt tussen het vaste.
// In de kolom ernaast staan ze gewoon onder elkaar: de eerste ligt gelijk met de
// kaartjes, wat erna komt krijgt er ruimte boven. De streep boven Morgen is daar
// niet nodig, die scheidt op een telefoon de stappen van wat er morgen is.
import SwiftUI

struct Agenda: View {
    let blok: Blok
    let mensen: [Persoon]
    var zij: Bool = false
    var eerste: Bool = false
    // Waar dit blok in de volgorde staat als de regels één voor één binnenkomen.
    // `nil` betekent: niet nodig hier — dan animeert wie dit blok plaatst het als
    // geheel, en zou een tweede beweging erbovenop alleen maar rommelig worden.
    var vanaf: Int? = nil
    var richting: CGFloat = 0
    // Op het ritmescherm doet alles hier mee aan de ochtend/avond-wissel: de
    // kop op zijn plek, de kaart mét zijn eerste regel één erachter, en elke
    // volgende regel weer één verder. Die latere regels schuiven bínnen het
    // glas — dat knipt ze bij zijn rand af, dus ze komen de kaart in in plaats
    // van er los naast te hangen. Het weekscherm kent geen wissel en laat dit
    // leeg.
    var wissel: Wissel? = nil
    var opOpen: ((Agendaitem) -> Void)? = nil

    @Environment(\.palet) private var palet

    private var later: Bool { blok.later && !zij }

    var body: some View {
        if !blok.items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if later {
                    Stippellijn()
                        .frame(height: 1)
                        .padding(.bottom, 22)
                        .wisselplek(wissel)
                }
                Blokkop(blok.kop, marge: zij ? 0 : 22)
                    .trapje(vanaf, 0, richting)
                    .wisselplek(wissel)
                Glas(radius: 26) {
                    VStack(spacing: 0) {
                        ForEach(Array(blok.items.enumerated()), id: \.offset) { (i, item) in
                            if i > 0 {
                                // Het streepje reist met de regel eronder mee.
                                Rectangle().fill(palet.streep).frame(height: 1).padding(.horizontal, 16)
                                    .wisselplek(wissel, extra: 1 + i)
                            }
                            Rij(item: item, mensen: mensen,
                                eerste: i == 0, laatste: i == blok.items.count - 1,
                                opOpen: item.bijzonder ? opOpen : nil)
                                .trapje(vanaf, i + 1, richting)
                                // De eerste regel zit al aan de kaart vast; de
                                // rest schuift er los achteraan naar binnen.
                                .wisselplek(i == 0 ? nil : wissel, extra: 1 + i)
                        }
                    }
                }
                .wisselplek(wissel, extra: 1)
            }
            .padding(.top, zij ? (eerste ? 0 : 22) : (blok.later ? 26 : 0))
        }
    }
}

private struct Rij: View {
    let item: Agendaitem
    let mensen: [Persoon]
    var eerste: Bool = false
    var laatste: Bool = false
    var opOpen: ((Agendaitem) -> Void)?

    @Environment(\.palet) private var palet

    private var gekozen: [Persoon] {
        item.wie.compactMap { id in mensen.first { $0.id == id } }
    }

    private var toonNamen: Bool { !gekozen.isEmpty && gekozen.count < mensen.count }

    var body: some View {
        let wanneer = tijdTekst(item)
        let vak = HStack(alignment: .top, spacing: 12) {
            Text(item.icoon)
                .font(.system(size: 24))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.tekst)
                    .letter(L.agendanaam)
                    .foregroundStyle(palet.inkt)
                    .fixedSize(horizontal: false, vertical: true)
                if toonNamen || !wanneer.isEmpty {
                    HStack(spacing: 7) {
                        if toonNamen {
                            ForEach(gekozen) { Merk(persoon: $0) }
                        }
                        if !wanneer.isEmpty {
                            Text(wanneer).letter(L.agendatijd).foregroundStyle(palet.zacht)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(minHeight: 54, alignment: .leading)
        .background(item.bijzonder ? palet.bijzonder : .clear)
        .overlay(alignment: .leading) {
            if item.bijzonder {
                Randje(boven: eerste ? 24.5 : 0, onder: laatste ? 24.5 : 0)
                    .stroke(ORANJE, style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                    .padding(.leading, 1.5)
            }
        }
        .contentShape(Rectangle())

        if let opOpen {
            Button {
                Trilling.tik()
                opOpen(item)
            } label: { vak }
            .buttonStyle(.druk(0.975))
        } else {
            vak
        }
    }
}

// Wie het betreft, als gekleurd label — alleen als het niet voor iedereen is.
struct Merk: View {
    let persoon: Persoon

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle().fill(.white.opacity(0.28))
                Text(persoon.emoji).font(.system(size: 11))
            }
            .frame(width: 19, height: 19)
            Text(persoon.naam).letter(L.merk).foregroundStyle(.white)
        }
        .padding(.leading, 3)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color(hex: persoon.kleur)))
    }
}

struct Blokkop: View {
    let tekst: String
    var marge: CGFloat = 22

    @Environment(\.palet) private var palet

    init(_ tekst: String, marge: CGFloat = 22) {
        self.tekst = tekst
        self.marge = marge
    }

    var body: some View {
        Text(tekst)
            .letter(L.blokkop)
            .foregroundStyle(palet.inkt)
            .padding(.top, marge)
            .padding(.horizontal, 16)
            .padding(.bottom, 9)
    }
}

// Morgen zakt op een telefoon onder de stappen, met een streep ertussen.
private struct Stippellijn: View {
    @Environment(\.palet) private var palet

    var body: some View {
        Rectangle()
            .fill(.clear)
            .overlay {
                Path { pad in
                    pad.move(to: CGPoint(x: 0, y: 0.5))
                    pad.addLine(to: CGPoint(x: 4000, y: 0.5))
                }
                .stroke(palet.donker ? Color.white.opacity(0.14) : INKT.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .clipped()
    }
}

// Alleen meedoen aan het golfje als er een plek in de volgorde is meegegeven.
private extension View {
    @ViewBuilder
    func trapje(_ vanaf: Int?, _ eigen: Int, _ richting: CGFloat) -> some View {
        if let vanaf {
            komtBinnen(vanaf + eigen, vanaf: richting, afstand: 18)
        } else {
            self
        }
    }
}

// Het oranje randje links bij iets eenmaligs. Bovenaan en onderaan de kaart buigt
// het mee met de ronde hoek in plaats van er vierkant tegenaan te stoppen — een
// rechte streep wordt daar door het glas afgeknipt, en dat zie je.
private struct Randje: Shape {
    var boven: CGFloat
    var onder: CGFloat

    func path(in r: CGRect) -> Path {
        var pad = Path()
        let b = min(boven, r.height / 2)
        let o = min(onder, r.height / 2)

        if b > 0 {
            pad.move(to: CGPoint(x: r.minX + b, y: r.minY))
            pad.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + b),
                             control: CGPoint(x: r.minX, y: r.minY))
        } else {
            pad.move(to: CGPoint(x: r.minX, y: r.minY))
        }

        pad.addLine(to: CGPoint(x: r.minX, y: r.maxY - o))

        if o > 0 {
            pad.addQuadCurve(to: CGPoint(x: r.minX + o, y: r.maxY),
                             control: CGPoint(x: r.minX, y: r.maxY))
        }
        return pad
    }
}
