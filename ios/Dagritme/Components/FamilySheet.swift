import SwiftUI

/// Wie er in dit huis zit, een code om iemand erbij te halen, en een vak om
/// zelf een code in te tikken. Je eigen regel aanraken opent je gezicht en
/// naam; wie het huis begon kan de anderen wegvegen.
struct FamilySheet: View {
    let onClose: () -> Void

    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette

    @State private var members: [Member] = []
    @State private var invite: Invite?
    @State private var typed = ""
    @State private var alert = ""
    @State private var making = false
    @State private var editing: Member?

    private var me: Member? { members.first { $0.id == session.account?.id } }
    private var iOwn: Bool { me?.owner ?? false }

    var body: some View {
        ZStack {
            Sheet(title: String(localized: "Ouders en verzorgers"), alert: alert, onCancel: onClose) {
                FormHead(String(localized: "Wie doet mee"), first: true)
                EditCard {
                    ForEach(Array(members.enumerated()), id: \.element.id) { i, member in
                        if i > 0 { HairLine() }
                        if iOwn && member.id != me?.id {
                            SwipeAway(title: String(localized: "Weg"), onDelete: { remove(member) }) {
                                row(member)
                            }
                        } else {
                            row(member)
                        }
                    }
                }
                if me?.nickname == nil {
                    Note(String(localized: "Tik op jezelf om te kiezen hoe de kinderen je noemen."))
                }

                FormHead(String(localized: "Iemand erbij"))
                if let invite {
                    EditCard {
                        VStack(spacing: 6) {
                            Text(invite.pretty)
                                .textStyle(TextStyle(font: Fonts.balooHeavy(30), tracking: 2))
                                .foregroundStyle(palette.ink)
                                .accessibilityIdentifier("family.code")
                            Text("Eén keer te gebruiken, een week geldig.")
                                .textStyle(Fonts.note).foregroundStyle(palette.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    ShareLink(item: shareText(invite)) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .bold))
                            Text("Deel de code").textStyle(Fonts.bigButton)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ORANGE))
                    }
                    .buttonStyle(.press)
                    .padding(.top, 12)
                    .accessibilityIdentifier("family.share")
                } else {
                    Note(String(localized: "Maak een code en stuur die naar de ander. Die tikt hem in bij Ouders en verzorgers op zijn eigen telefoon."))
                    CardButton(String(localized: "Maak een code"), plus: true, id: "family.invite") {
                        guard !making else { return }
                        making = true
                        Task {
                            do { invite = try await session.invite(); alert = "" }
                            catch { alert = error.localizedDescription }
                            making = false
                        }
                    }
                    .opacity(making ? 0.5 : 1)
                }

                FormHead(String(localized: "Ik heb een code"))
                HStack(spacing: 10) {
                    Field(value: $typed, placeholder: "ABCD-EFGH", id: "family.typed")
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextButton(String(localized: "Doe mee"), bold: true, id: "family.join") {
                        Task {
                            if let problem = await session.accept(code: typed) {
                                alert = problem
                            } else {
                                onClose()
                            }
                        }
                    }
                    .disabled(typed.isEmpty || session.busy)
                    .opacity(typed.isEmpty ? 0.4 : 1)
                }
                Note(String(localized: "Dan zie je voortaan het huis van de ander."))
            }
            .task {
                members = (try? await session.members()) ?? []
            }

            if let editing {
                MemberSheet(member: editing,
                            onCancel: { self.editing = nil }) { nickname, emoji, color, birthday in
                    Task {
                        do {
                            members = try await session.updateMember(
                                nickname: nickname, emoji: emoji, color: color, birthday: birthday)
                            alert = ""
                        } catch {
                            alert = error.localizedDescription
                        }
                        self.editing = nil
                    }
                }
            }
        }
    }

    private func row(_ member: Member) -> some View {
        Button {
            guard member.id == me?.id else { return }
            Haptics.tap()
            editing = member
        } label: {
            HStack(spacing: 12) {
                MemberFace(member: member, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.label).textStyle(Fonts.rowLabel).foregroundStyle(palette.ink).lineLimit(1)
                    if let email = member.email, member.nickname != nil || member.name != nil {
                        Text(email).textStyle(Fonts.listNote).foregroundStyle(palette.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text(member.owner ? String(localized: "begonnen")
                     : member.id == me?.id ? String(localized: "jij") : String(localized: "lid"))
                    .textStyle(Fonts.rowMeta).foregroundStyle(palette.muted)
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityIdentifier("family.member." + member.id)
    }

    private func remove(_ member: Member) {
        Task {
            do {
                members = try await session.removeMember(member.id)
                alert = ""
            } catch {
                alert = error.localizedDescription
            }
        }
    }

    private func shareText(_ invite: Invite) -> String {
        String(localized: "Doe mee in Routines: \(Config.baseURL)/join/\(invite.pretty)\n\nLukt de link niet? Log in de app in en tik bij Instellingen → Ouders en verzorgers deze code in: \(invite.pretty)")
    }
}

/// Iemand tikte op een uitnodigingslink: de code staat klaar, één tik doet mee.
struct InviteSheet: View {
    let code: String

    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette
    @State private var alert = ""

    private var pretty: String { code.prefix(4) + "-" + code.suffix(4) }

    var body: some View {
        Sheet(title: String(localized: "Uitnodiging"), alert: alert,
              button: String(localized: "Doe mee"), busy: session.busy,
              onCancel: { session.pendingInvite = nil },
              onButton: {
                  Task {
                      if let problem = await session.accept(code: code) {
                          alert = problem
                      } else {
                          session.pendingInvite = nil
                      }
                  }
              }) {
            VStack(spacing: 6) {
                Text(pretty)
                    .textStyle(TextStyle(font: Fonts.balooHeavy(30), tracking: 2))
                    .foregroundStyle(palette.ink)
                Text("Je bent uitgenodigd in een huis. Doe je mee, dan laat de app voortaan dat huis zien.")
                    .textStyle(Fonts.note).foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

/// Een rondje met het gezicht van een gezinslid, in zijn eigen kleur.
struct MemberFace: View {
    let member: Member
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(soft(member.color ?? COLORS[0], 0.18))
            Text(member.face).font(.system(size: size * 0.56))
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
        .accessibilityHidden(true)
    }
}

/// Hoe de kinderen jou noemen, met een gezicht en een kleur; dezelfde vorm
/// als het blad voor een kind.
struct MemberSheet: View {
    let onCancel: () -> Void
    let onSave: (String, String, String, String) -> Void

    @State private var nickname: String
    @State private var emoji: String
    @State private var color: String
    @State private var birthday: String
    @State private var picker = false

    @Environment(\.palette) private var palette

    init(member: Member, onCancel: @escaping () -> Void,
         onSave: @escaping (String, String, String, String) -> Void) {
        self.onCancel = onCancel
        self.onSave = onSave
        _nickname = State(initialValue: member.nickname ?? "")
        _emoji = State(initialValue: member.face)
        _color = State(initialValue: member.color ?? COLORS[0])
        _birthday = State(initialValue: member.birthday ?? "")
    }

    /// Dezelfde invulregel als bij een kind: de compacte DatePicker ligt er
    /// onzichtbaar onder voor de tik en de kalender, met een eigen knop
    /// eroverheen.
    @ViewBuilder
    private var born: some View {
        HStack(spacing: 10) {
            DatePicker("Verjaardag", selection: bornBinding, in: ...Date(),
                       displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .opacity(0.02)
                .overlay {
                    Chip(label: bornLabel, on: !birthday.isEmpty) {}
                        .allowsHitTesting(false)
                }
                .accessibilityIdentifier("member.birthday")
                .accessibilityLabel(Spoken.date)

            if !birthday.isEmpty {
                Text(ageText(birthday))
                    .textStyle(Fonts.listNote)
                    .foregroundStyle(palette.muted)
                Spacer(minLength: 0)
                TextButton(String(localized: "Wissen"), id: "member.birthday.clear") {
                    birthday = ""
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, 4)
    }

    private var bornLabel: String {
        guard let day = asDate(birthday) else { return String(localized: "Nog niet ingevuld") }
        return day.formatted(.dateTime.day().month(.abbreviated).year()
            .locale(.autoupdatingCurrent))
    }

    private var bornBinding: Binding<Date> {
        Binding(
            get: { asDate(birthday) ?? Date() },
            set: { birthday = dateString($0) }
        )
    }

    var body: some View {
        ZStack {
            Sheet(title: String(localized: "Jij"), button: String(localized: "Bewaar"), onCancel: onCancel,
                  onButton: {
                      onSave(nickname.trimmingCharacters(in: .whitespaces), emoji, color, birthday)
                  }) {
                FormHead(String(localized: "Hoe noemen de kinderen je?"), first: true)
                HStack(spacing: 10) {
                    EmojiButton(value: emoji, size: 52) { picker = true }
                    Field(value: $nickname, placeholder: String(localized: "papa, mama, oma…"), id: "member.nickname")
                }

                FormHead(String(localized: "Kleur"))
                Chips {
                    ForEach(COLORS, id: \.self) { option in
                        Button { color = option } label: {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color(hex: option))
                                .frame(minHeight: 34)
                                .frame(maxWidth: .infinity)
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(INK, lineWidth: color == option ? 2.5 : 0))
                        }
                        .buttonStyle(.press)
                        .frame(width: 64, height: 34)
                        .accessibilityLabel(Spoken.color)
                    }
                }

                FormHead(String(localized: "Verjaardag"))
                born
            }

            if picker {
                EmojiPicker(title: String(localized: "Kies een gezicht"), current: emoji,
                            onCancel: { picker = false },
                            onDone: { glyph in emoji = glyph; picker = false })
            }
        }
    }
}
