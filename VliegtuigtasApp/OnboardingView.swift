import SwiftUI

struct OnboardingView: View {
    @StateObject private var session = UserSession.shared
    @State private var page = 0
    @State private var firstName = ""
    @State private var email = ""
    @State private var isSending = false
    @State private var nameError = false
    @State private var emailError = false
    @FocusState private var nameFocused: Bool
    @FocusState private var emailFocused: Bool

    var body: some View {
        ZStack {
            switch page {
            case 0:
                WelcomePage(onNext: { withAnimation(.easeInOut(duration: 0.35)) { page = 1 } })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 1:
                NamePage(
                    firstName: $firstName,
                    error: $nameError,
                    isFocused: $nameFocused,
                    onNext: tryAdvanceFromName,
                    onBack: { withAnimation(.easeInOut(duration: 0.35)) { page = 0 } }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            default:
                EmailPage(
                    firstName: firstName,
                    email: $email,
                    error: $emailError,
                    isFocused: $emailFocused,
                    isSending: isSending,
                    onNext: tryComplete,
                    onBack: { withAnimation(.easeInOut(duration: 0.35)) { page = 1 } }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .overlay(alignment: .top) {
            progressDots
                .padding(.top, 60)
        }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i == page ? Theme.navy : Color(.systemFill))
                    .frame(width: i == page ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.4), value: page)
            }
        }
    }

    // MARK: - Logic

    private func tryAdvanceFromName() {
        let trimmed = firstName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            nameError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            firstName = trimmed
            nameError = false
            nameFocused = false
            withAnimation(.easeInOut(duration: 0.35)) { page = 2 }
        }
    }

    private func tryComplete() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            emailError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        emailError = false
        isSending = true
        email = trimmedEmail
        emailFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            session.completeOnboarding(firstName: firstName, email: email)
        }
    }
}

// MARK: - Welcome page

private struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Hero image
                heroImage(height: 320)

                // Card
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text("Nooit meer\nverrast bij de gate.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Controleer in seconden of jouw handbagage past bij Ryanair, KLM, easyJet en meer.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        FeatureRow(icon: "checkmark.shield.fill", color: Theme.green,
                                   text: "Direct weten of jouw tas past")
                        FeatureRow(icon: "bag.fill", color: Theme.sky,
                                   text: "Tassen aanbevolen die altijd passen")
                        FeatureRow(icon: "airplane", color: Theme.yellow,
                                   text: "Alle grote Europese maatschappijen")
                    }

                    OnboardButton(title: "Aan de slag", icon: "arrow.right", action: onNext)
                }
                .padding(28)
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Name page

private struct NamePage: View {
    @Binding var firstName: String
    @Binding var error: Bool
    @FocusState.Binding var isFocused: Bool
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroImage(height: 220)
                    .overlay(alignment: .bottomLeading) {
                        Text("✋ Even\nvoorstellen")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 8)
                            .padding(24)
                    }

                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("Hoe mogen we je noemen?")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("Zodat we je persoonlijk kunnen helpen.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Voornaam")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)

                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(error ? Theme.red : (isFocused ? Theme.sky : Theme.textSecondary))
                                .frame(width: 20)
                            TextField("bijv. Emma of Luca", text: $firstName)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                                .focused($isFocused)
                                .submitLabel(.next)
                                .onSubmit { onNext() }
                                .font(.system(size: 16, design: .rounded))
                        }
                        .padding(16)
                        .background(error ? Theme.red.opacity(0.06) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    error ? Theme.red : (isFocused ? Theme.sky : .clear),
                                    lineWidth: 2
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: error)
                        .animation(.easeInOut(duration: 0.2), value: isFocused)

                        if error {
                            Label("Vul je voornaam in", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.red)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: error)

                    OnboardButton(title: "Volgende", icon: "arrow.right", action: onNext)

                    Button(action: onBack) {
                        Label("Terug", systemImage: "chevron.left")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(28)
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFocused = true }
        }
    }
}

// MARK: - Email page

private struct EmailPage: View {
    let firstName: String
    @Binding var email: String
    @Binding var error: Bool
    @FocusState.Binding var isFocused: Bool
    let isSending: Bool
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroImage(height: 200)
                    .overlay(alignment: .bottomLeading) {
                        Text("Hoi \(firstName.isEmpty ? "daar" : firstName)! 👋")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 8)
                            .padding(24)
                    }

                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("Wat is je e-mailadres?")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("We sturen je handige reistips en alerts als regels veranderen.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("E-mailadres")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)

                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(error ? Theme.red : (isFocused ? Theme.sky : Theme.textSecondary))
                                .frame(width: 20)
                            TextField("jouw@email.nl", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($isFocused)
                                .submitLabel(.done)
                                .onSubmit { onNext() }
                                .font(.system(size: 16, design: .rounded))
                        }
                        .padding(16)
                        .background(error ? Theme.red.opacity(0.06) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    error ? Theme.red : (isFocused ? Theme.sky : .clear),
                                    lineWidth: 2
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: error)
                        .animation(.easeInOut(duration: 0.2), value: isFocused)

                        if error {
                            Label("Vul een geldig e-mailadres in", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.red)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: error)

                    OnboardButton(
                        title: isSending ? "Opslaan…" : "Start de app",
                        icon: isSending ? nil : "checkmark",
                        loading: isSending,
                        action: onNext
                    )
                    .disabled(isSending)

                    Button(action: onBack) {
                        Label("Terug", systemImage: "chevron.left")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text("We delen je gegevens nooit met derden.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary.opacity(0.5))
                }
                .padding(28)
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFocused = true }
        }
    }
}

// MARK: - Shared hero image
// LinearGradient establishes the layout frame; image is overlay to prevent width overflow.

private func heroImage(height: CGFloat) -> some View {
    LinearGradient(
        colors: [Theme.navy, Theme.navyDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .overlay {
        if UIImage(named: "HeroSuitcase") != nil {
            Image("HeroSuitcase")
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.white.opacity(0.2))
        }
    }
    .overlay {
        LinearGradient(
            colors: [.clear, .black.opacity(0.45)],
            startPoint: .top, endPoint: .bottom
        )
    }
    .clipped()
}

// MARK: - Feature row

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }
}

// MARK: - Primary button

private struct OnboardButton: View {
    let title: String
    let icon: String?
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.navyGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.navy.opacity(0.35), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
