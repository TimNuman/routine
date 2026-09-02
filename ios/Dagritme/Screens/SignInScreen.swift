import AuthenticationServices
import SwiftUI

/// Het eerste scherm zolang er niemand ingelogd is.
struct SignInScreen: View {
    @Environment(Session.self) private var session

    var body: some View {
        Welcome {
            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await apple(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("signin.apple")

                BigButton(String(localized: "Ga door met Google"), glyph: "G", id: "signin.google") {
                    Task { await session.signInWithGoogle() }
                }
            }
            .disabled(session.busy)
            .opacity(session.busy ? 0.6 : 1)

            TextButton(String(localized: "Zonder account verder"), id: "signin.legacy") {
                session.continueWithoutAccount()
            }
            .padding(.top, 18)
        }
    }

    private func apple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken, let token = String(data: data, encoding: .utf8)
            else {
                session.error = String(localized: "Apple gaf geen token terug.")
                return
            }
            let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            await session.signIn(.apple, idToken: token, name: name)
        case let .failure(error):
            if let error = error as? ASAuthorizationError, error.code == .canceled { return }
            session.error = error.localizedDescription
        }
    }
}

/// Ingelogd, maar nog geen huis gekozen: kies er een, of maak er een.
struct HomeScreen: View {
    @Environment(Session.self) private var session
    @Environment(\.palette) private var palette

    @State private var name = ""
    @State private var problem = ""

    var body: some View {
        Welcome(subtitle: session.account?.label ?? "") {
            if !session.homes.isEmpty {
                FormHead(String(localized: "Jullie huizen"), first: true)
                CardList {
                    ForEach(Array(session.homes.enumerated()), id: \.element.id) { i, home in
                        CardRow(icon: "🏠", title: home.name,
                                note: home.role == "owner" ? String(localized: "van jou") : String(localized: "lid"),
                                first: i == 0, id: "home.\(home.id)") { session.choose(home) }
                    }
                }
                .padding(.top, -8)
            }

            FormHead(session.homes.isEmpty ? String(localized: "Een huis beginnen")
                                           : String(localized: "Nog een huis"))
            Field(value: $name, placeholder: String(localized: "Hoe heet jullie huis?"), id: "home.name")
            if !problem.isEmpty { AlertBox(problem).padding(.top, 12) }
            BigButton(String(localized: "Maak het huis"), id: "home.create") {
                Task {
                    problem = await session.createHome(name.trimmingCharacters(in: .whitespaces)) ?? ""
                }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || session.busy)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .padding(.top, 12)

            TextButton(String(localized: "Uitloggen"), id: "home.signout") {
                Task { await session.signOut() }
            }
            .padding(.top, 18)
        }
    }
}

/// De lucht, het zonnetje en de naam van de app; daaronder wat het scherm
/// zelf te zeggen heeft.
private struct Welcome<Inner: View>: View {
    var subtitle = ""
    @ViewBuilder var content: () -> Inner

    @Environment(Session.self) private var session

    var body: some View {
        GeometryReader { space in
            let m = Metrics(width: space.size.width)
            ZStack {
                Sky(dark: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: -3) {
                            Text("☀️").font(.system(size: 54)).padding(.bottom, 6)
                            Text("Routines").textStyle(Fonts.title).foregroundStyle(INK)
                            Text(subtitle.isEmpty
                                 ? String(localized: "Het dagritme van jullie huis, op elke telefoon tegelijk.")
                                 : subtitle)
                                .textStyle(Fonts.subtitle).foregroundStyle(SOFT_INK)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, m.indent)
                        .padding(.top, 60)
                        .padding(.bottom, 28)

                        if !session.error.isEmpty { AlertBox(session.error) }

                        content()
                    }
                    .padding(.horizontal, m.gutter)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .environment(\.metrics, m)
            .environment(\.palette, Palette(dark: false))
        }
    }
}

/// Een brede knop met de kleur van de app.
struct BigButton: View {
    let title: String
    var glyph: String? = nil
    var id: String? = nil
    let onTap: () -> Void

    init(_ title: String, glyph: String? = nil, id: String? = nil, onTap: @escaping () -> Void) {
        self.title = title
        self.glyph = glyph
        self.id = id
        self.onTap = onTap
    }

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            HStack(spacing: 10) {
                if let glyph {
                    Text(glyph).font(.system(size: 19, weight: .heavy, design: .rounded))
                }
                Text(title).textStyle(Fonts.bigButton)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ORANGE))
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityIdentifier(id ?? "")
    }
}
