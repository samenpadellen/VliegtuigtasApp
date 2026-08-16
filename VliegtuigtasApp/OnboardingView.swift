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
                WelcomePage(onNext: { advance(to: 1) })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 1:
                TripsFeaturePage(onNext: { advance(to: 2) })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 2:
                JourneyFeaturePage(onNext: { advance(to: 3) })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 3:
                PimFeaturePage(onNext: { advance(to: 4) })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 4:
                NamePage(
                    firstName: $firstName,
                    error: $nameError,
                    isFocused: $nameFocused,
                    onNext: tryAdvanceFromName,
                    onBack: { advance(to: 3) }
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
                    onBack: { advance(to: 4) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .overlay(alignment: .top) {
            progressDots
                .padding(.top, Theme.Spacing.section)
        }
        // App Review 5.1.1(v): naam/e-mail zijn optioneel — de app werkt
        // volledig zonder. Overslaan is daarom altijd één tik.
        .overlay(alignment: .topTrailing) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                session.completeWithoutAccount()
            } label: {
                Text("Sla over")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(.black.opacity(0.30))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.trailing, Theme.Spacing.base)
        }
    }

    // MARK: - Progress dots

    private static let pageCount = 6

    private var progressDots: some View {
        // Witte dots: alle pagina's hebben bovenin een foto/hero.
        HStack(spacing: 6) {
            ForEach(0..<Self.pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == page ? .white : .white.opacity(0.35))
                    .frame(width: i == page ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.4), value: page)
            }
        }
        .cardElevation()
    }

    // MARK: - Logic

    private func advance(to newPage: Int) {
        withAnimation(.easeInOut(duration: 0.35)) { page = newPage }
    }

    private func tryAdvanceFromName() {
        let trimmed = firstName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            nameError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            firstName = trimmed
            nameError = false
            nameFocused = false
            advance(to: 5)
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
        // Full-bleed hero over het hele scherm; alle content onderin verankerd
        // op een navy scrim — geen loze witruimte, edge-to-edge zoals moderne
        // reis-apps.
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                heroImage(height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                    .offset(y: -geo.safeAreaInsets.top)
            }

            // Scrim: foto loopt bovenin vrij, onderin diep navy voor leesbaarheid
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Theme.navyDark.opacity(0.55), location: 0.45),
                    .init(color: Theme.navyDark.opacity(0.96), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.yellow)
                    Text("VLIEGTUIGTAS")
                        .font(.frutiger(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.8))
                        .kerning(2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nooit meer verrast\nbij de gate.")
                        .font(.frutiger(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                    Text("Controleer in seconden of jouw handbagage past bij Ryanair, KLM, easyJet en meer.")
                        .font(.frutiger(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(2)
                }

                VStack(spacing: 8) {
                    WelcomeFeatureRow(icon: "checkmark.shield.fill", tint: Theme.green,
                                      text: "Direct weten of jouw tas past")
                    WelcomeFeatureRow(icon: "camera.viewfinder", tint: Theme.sky,
                                      text: "Scan je tas met de camera (LiDAR)")
                    WelcomeFeatureRow(icon: "airplane", tint: Theme.yellow,
                                      text: "Alle grote Europese maatschappijen")
                }

                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text("Aan de slag")
                            .font(.frutiger(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.base)
                    .background(.white)
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.sm)
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.navyDark)
        .ignoresSafeArea(edges: .top)
    }
}

/// Featureregel op de donkere welkomstpagina: glazen chip-stijl.
private struct WelcomeFeatureRow: View {
    let iconView: AnyView
    let tint: Color
    let text: String

    init(icon systemName: String, tint: Color, text: String) {
        self.iconView = AnyView(Image(systemName: systemName).font(.system(size: 14, weight: .semibold)))
        self.tint = tint
        self.text = text
    }

    /// Voor niet-SF Symbol iconen, zoals Purser Pim's eigen petje-tekening
    /// (bewust géén sparkles/AI-iconografie — zie PurserPimCap).
    init(icon: AnyView, tint: Color, text: String) {
        self.iconView = icon
        self.tint = tint
        self.text = text
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            Text(text)
                .font(.frutiger(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Featurepagina's (alles wat de app te bieden heeft)

/// Zelfde opbouw als WelcomePage — full-bleed foto, navy scrim, wordmark,
/// kop + subkop, drie featureregels, witte knop — maar herbruikbaar voor
/// de extra pagina's die laten zien wat de app allemaal kan, vóórdat er om
/// een naam/e-mailadres wordt gevraagd.
private struct FeaturePage: View {
    let heroImageName: String
    let heading: String
    let subheading: String
    let features: [(icon: AnyView, tint: Color, text: String)]
    let onNext: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                heroImage(heroImageName, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                    .offset(y: -geo.safeAreaInsets.top)
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Theme.navyDark.opacity(0.55), location: 0.45),
                    .init(color: Theme.navyDark.opacity(0.96), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.yellow)
                    Text("VLIEGTUIGTAS")
                        .font(.frutiger(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.8))
                        .kerning(2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(heading)
                        .font(.frutiger(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                    Text(subheading)
                        .font(.frutiger(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(2)
                }

                VStack(spacing: 8) {
                    ForEach(features.indices, id: \.self) { i in
                        WelcomeFeatureRow(icon: features[i].icon, tint: features[i].tint, text: features[i].text)
                    }
                }

                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text("Volgende")
                            .font(.frutiger(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.base)
                    .background(.white)
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.sm)
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.navyDark)
        .ignoresSafeArea(edges: .top)
    }
}

/// Reizen: paklijst, reisklaar-score, bucket list, reisverslag.
private struct TripsFeaturePage: View {
    let onNext: () -> Void

    var body: some View {
        FeaturePage(
            heroImageName: "PhotoTraveler",
            heading: "Jouw hele reis,\nop één plek.",
            subheading: "Van paklijst tot reisverslag — Vliegtuigtas denkt met je mee, vóór en ná iedere trip.",
            features: [
                (AnyView(Image(systemName: "list.bullet.clipboard.fill")), Theme.green,
                 "Slimme paklijst per soort reis"),
                (AnyView(Image(systemName: "gauge.with.dots.needle.67percent")), Theme.sky,
                 "Reisklaar-score in één oogopslag"),
                (AnyView(Image(systemName: "star.fill")), Theme.yellow,
                 "Beoordeel en bewaar je reisverslag")
            ],
            onNext: onNext
        )
    }
}

/// Onderweg: vluchten volgen, widget/Watch/CarPlay/Apple TV.
private struct JourneyFeaturePage: View {
    let onNext: () -> Void

    var body: some View {
        FeaturePage(
            heroImageName: "PhotoAirportSigns",
            heading: "Ook onderweg\naltijd op de hoogte.",
            subheading: "Volg je vlucht live, en vind je gegevens automatisch terug op je widget, Watch en zelfs je tv.",
            features: [
                (AnyView(Image(systemName: "airplane.circle.fill")), Theme.sky,
                 "Live gate- en vertragingsinformatie"),
                (AnyView(Image(systemName: "applewatch")), Theme.orange,
                 "Ook op je Apple Watch en widget"),
                (AnyView(Image(systemName: "tv.fill")), Theme.yellow,
                 "Vertrekbord op je Apple TV")
            ],
            onNext: onNext
        )
    }
}

/// Purser Pim + LiDAR-scan + gratis.
private struct PimFeaturePage: View {
    let onNext: () -> Void

    var body: some View {
        FeaturePage(
            heroImageName: "PhotoBaggageTag",
            heading: "Purser Pim helpt\njou persoonlijk.",
            subheading: "Scan je tas met de camera, krijg pakadvies op maat — allemaal volledig gratis.",
            features: [
                (AnyView(Image(systemName: "camera.viewfinder")), Theme.sky,
                 "3D-scan van je tas met LiDAR"),
                (AnyView(PurserPimCap(size: 22)), Theme.yellow,
                 "Purser Pim geeft pakadvies op maat"),
                (AnyView(Image(systemName: "checkmark.seal.fill")), Theme.green,
                 "Alles gratis — geen abonnement")
            ],
            onNext: onNext
        )
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
        OnboardFormScaffold {
            VStack(alignment: .leading, spacing: 16) {
                OnboardKicker(text: "STAP 1 VAN 2 · JOUW PROFIEL")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hoe mogen we\nje noemen?")
                        .font(.frutiger(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                    Text("Zodat we je persoonlijk kunnen helpen.")
                        .font(.frutiger(size: 15))
                        .foregroundStyle(.white.opacity(0.75))
                }

                AppleSignInButton()

                HStack(spacing: 10) {
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                    Text("of vul je naam handmatig in")
                        .font(.frutiger(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize()
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                }

                DarkInputField(
                    icon: "person.fill",
                    placeholder: "bijv. Emma of Luca",
                    text: $firstName,
                    error: error,
                    isFocused: $isFocused,
                    contentType: .givenName,
                    submitLabel: .next,
                    onSubmit: onNext
                )

                if error {
                    Label("Vul je voornaam in", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.red)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                OnboardPrimaryButton(title: "Volgende", icon: "arrow.right", action: onNext)

                OnboardBackButton(action: onBack)
            }
            .animation(.easeInOut(duration: 0.2), value: error)
        }
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
        OnboardFormScaffold {
            VStack(alignment: .leading, spacing: 16) {
                OnboardKicker(text: "STAP 2 VAN 2 · BIJNA KLAAR")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hoi \(firstName.isEmpty ? "daar" : firstName)! 👋")
                        .font(.frutiger(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Waar mogen we reistips en alerts naartoe sturen als regels veranderen?")
                        .font(.frutiger(size: 15))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineSpacing(2)
                }

                DarkInputField(
                    icon: "envelope.fill",
                    placeholder: "jouw@email.nl",
                    text: $email,
                    error: error,
                    isFocused: $isFocused,
                    keyboard: .emailAddress,
                    contentType: .emailAddress,
                    capitalization: .never,
                    submitLabel: .done,
                    onSubmit: onNext
                )

                if error {
                    Label("Vul een geldig e-mailadres in", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.red)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                OnboardPrimaryButton(
                    title: isSending ? "Opslaan…" : "Start de app",
                    icon: isSending ? nil : "checkmark",
                    loading: isSending,
                    action: onNext
                )
                .disabled(isSending)

                OnboardBackButton(action: onBack)

                ReferralCodeEntryField()

                Text("We delen je gegevens nooit met derden.")
                    .font(.frutiger(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
            .animation(.easeInOut(duration: 0.2), value: error)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFocused = true }
        }
    }
}

// MARK: - Donkere formulier-bouwstenen (stijl van de welkomstpagina)

/// Full-bleed hero + navy scrim met onderin verankerde content — zelfde
/// edge-to-edge opbouw als de welkomstpagina, dus geen loze witruimte.
private struct OnboardFormScaffold<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                heroImage(height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                    .offset(y: -geo.safeAreaInsets.top)
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Theme.navyDark.opacity(0.55), location: 0.40),
                    .init(color: Theme.navyDark.opacity(0.96), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            content
                .frame(maxWidth: Theme.contentMaxWidth)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.navyDark)
        .ignoresSafeArea(edges: .top)
    }
}

private struct OnboardKicker: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.yellow)
            Text(text)
                .font(.frutiger(size: 10, weight: .black))
                .foregroundStyle(.white.opacity(0.75))
                .kerning(1.8)
        }
    }
}

/// Invoerveld op donkere ondergrond: glazen vlak, gele focusrand.
private struct DarkInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var error: Bool
    @FocusState.Binding var isFocused: Bool
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .words
    var submitLabel: SubmitLabel = .next
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(error ? Theme.red : (isFocused ? Theme.yellow : .white.opacity(0.5)))
                .frame(width: 20)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.35)))
                .font(.frutiger(size: 16))
                .foregroundStyle(.white)
                .tint(Theme.yellow)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
        }
        .padding(Theme.Spacing.base)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .strokeBorder(
                    error ? Theme.red : (isFocused ? Theme.yellow : .white.opacity(0.15)),
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.2), value: error)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

private struct OnboardPrimaryButton: View {
    let title: String
    var icon: String?
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(Theme.navy)
                }
                Text(title)
                    .font(.frutiger(size: 17, weight: .semibold))
                if let icon, !loading {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.base)
            .background(.white)
            .foregroundStyle(Theme.navy)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
        .padding(.top, Theme.Spacing.sm)
    }
}

private struct OnboardBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Terug", systemImage: "chevron.left")
                .font(.frutiger(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared hero image
// LinearGradient establishes the layout frame; image is overlay to prevent width overflow.

private func heroImage(_ name: String = "HeroSuitcase", height: CGFloat) -> some View {
    LinearGradient(
        colors: [Theme.navy, Theme.navyDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .overlay {
        if UIImage(named: name) != nil {
            Image(name)
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
    // Puur decoratief; de fill-foto mag nooit tikken afvangen van de
    // knoppen/velden die eroverheen of eronder liggen.
    .allowsHitTesting(false)
}

// MARK: - Feature row

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.frutiger(size: 15))
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
                        .font(.frutiger(size: 17, weight: .semibold))
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.base)
            .background(Theme.inkGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            // bewust eigen schaduw: navy-getinte gloed onder de CTA-knop op de
            // inktgradiënt, geen generieke kaart-lift (cardElevation is te subtiel)
            .shadow(color: Theme.navy.opacity(0.35), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
