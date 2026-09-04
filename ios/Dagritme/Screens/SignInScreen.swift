import AuthenticationServices
import SwiftUI

/// Het eerste scherm zolang er niemand ingelogd is.
struct SignInScreen: View {
    @Environment(Session.self) private var session

    var body: some View {
        Welcome {
            if session.pendingInvite != nil {
                Note(String(localized: "Je hebt een uitnodiging. Log in, dan doe je meteen mee."))
                    .padding(.bottom, 16)
            }
            VStack(spacing: 12) {
                if Capabilities.signInWithApple {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await apple(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("signin.apple")
                }

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

/// Ingelogd, maar de server gaf geen huis terug. Hoort niet te gebeuren;
/// dan is dit de uitweg.
struct NoHomeScreen: View {
    @Environment(Session.self) private var session

    var body: some View {
        Welcome(subtitle: session.account?.label ?? "") {
            if session.busy {
                ProgressView().tint(ORANGE).frame(maxWidth: .infinity).padding(.top, 12)
            } else {
                BigButton(String(localized: "Probeer opnieuw"), id: "home.retry") {
                    Task { await session.ensureHome() }
                }
            }
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
                            Text("Routines").textStyle(Fonts.title()).foregroundStyle(INK)
                            Text(subtitle.isEmpty
                                 ? String(localized: "Het dagritme van jullie huis, op elke telefoon tegelijk.")
                                 : subtitle)
                                .textStyle(Fonts.subtitle()).foregroundStyle(SOFT_INK)
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
