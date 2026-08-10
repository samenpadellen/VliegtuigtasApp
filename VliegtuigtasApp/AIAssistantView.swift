import SwiftUI
import Combine

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Purser Pim's pet

/// Getekende gezagvoerderspet — bewust géén sparkles/AI-iconografie:
/// Pim is bemanning, geen robot.
struct PurserPimCap: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            // Klep (achterste laag, steekt onder de band uit)
            Ellipse()
                .fill(Color(red: 0.08, green: 0.10, blue: 0.16))
                .frame(width: size * 0.78, height: size * 0.34)
                .offset(y: size * 0.22)

            // Bol van de pet
            Ellipse()
                .fill(.white)
                .frame(width: size, height: size * 0.62)
                .offset(y: -size * 0.10)

            // Navy band
            Capsule()
                .fill(Color(red: 0.00, green: 0.12, blue: 0.38))
                .frame(width: size * 0.94, height: size * 0.30)
                .offset(y: size * 0.10)

            // Goudkleurig vleugel-embleem op de band
            Image(systemName: "airplane")
                .font(.system(size: size * 0.20, weight: .bold))
                .foregroundStyle(Color(red: 0.99, green: 0.80, blue: 0.10))
                .offset(y: size * 0.10)
        }
        .frame(width: size, height: size * 0.9)
        .accessibilityHidden(true)
    }
}

// MARK: - Kaart voor "Jouw reiswereld"

/// Kaart voor de Meer-hub: Pim voelt hier aanwezig, niet als een menu-item.
/// Met zijn petje in plaats van een generiek icoontje en, als er een verse
/// tip klaarstaat (dezelfde cache als de widget), die tip in een
/// spreekbelletje — zodat hij ook zonder tikken al iets te zeggen heeft.
struct PimPreviewCard: View {
    let action: () -> Void

    private var cachedTip: String? {
        guard let d = UserDefaults(suiteName: PimTipCache.suiteName),
              let tip = d.string(forKey: "vt_shared_pim_tip"), !tip.isEmpty else { return nil }
        let stamp = d.double(forKey: "vt_shared_pim_tip_stamp")
        guard stamp > 0, Date().timeIntervalSince1970 - stamp < 60 * 60 * 48 else { return nil }
        return tip
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Theme.inkGradient)
                    PurserPimCap(size: 30)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Purser Pim")
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    if let cachedTip {
                        Text("\u{201C}\(cachedTip)\u{201D}")
                            .font(.frutiger(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .italic()
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Theme.yellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text("Vraag Pim om paklijst- of alarmadvies voor je volgende reis.")
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home-kaart

/// Entreekaart op Home. Toont zichzelf alleen als het on-device model
/// beschikbaar is; op oudere toestellen verschijnt er niets.
@available(iOS 26.0, *)
struct AIAssistentHomeCard: View {
    @EnvironmentObject private var airlineStore: AirlineStore
    @EnvironmentObject private var nav: AppNavigator
    @ObservedObject private var session = UserSession.shared
    @State private var showChat = false
    @State private var showAccount = false

    var body: some View {
        if AIAvailability.isAvailable {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Accountgebonden: Pim adviseert persoonlijk op basis van je
                // profiel (jouw naam, tas en vlucht).
                if session.hasAccount {
                    showChat = true
                } else {
                    showAccount = true
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.15))
                            .frame(width: 44, height: 44)
                        PurserPimCap(size: 28)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purser Pim")
                            .font(.frutiger(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Jouw persoonlijke bagageassistent, privé op je iPhone")
                            .font(.frutiger(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .background(Theme.skyGradient)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Theme.navy.opacity(0.25), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showChat) {
                BagageAssistentView(airlines: airlineStore.airlines) { airline in
                    // Vanuit het gesprek rechtstreeks de checker in, met de
                    // besproken maatschappij voorgeselecteerd.
                    nav.openChecker(preselected: airline)
                }
            }
            .sheet(isPresented: $showAccount) {
                ScrollView {
                    AccountRequiredView(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "Purser Pim werkt met een profiel",
                        reason: "Pim kent jouw naam, je tasmaten en je vlucht, en voert echte checks voor je uit. Die gegevens horen bij jouw profiel. Het gesprek zelf blijft privé op je toestel.",
                        onCompleted: {
                            // Sheet dicht en direct door naar het gesprek —
                            // je krijgt meteen waarvoor je het profiel maakte.
                            showAccount = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showChat = true
                            }
                        }
                    )
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            // Vanuit de Purser Pim-widget op het toegangsscherm/thuisscherm:
            // opent direct het gesprek (of, zonder profiel, eerst de gate).
            .onChange(of: nav.openPimChatToken) { _, token in
                guard token != nil else { return }
                if session.hasAccount { showChat = true } else { showAccount = true }
            }
        }
    }
}

// MARK: - Chat

@available(iOS 26.0, *)
struct BagageAssistentView: View {
    let airlines: [Airline]
    /// Springt vanuit het gesprek naar de checker met deze maatschappij.
    var onOpenChecker: ((Airline) -> Void)?

    @StateObject private var assistent: BagageAssistent
    @State private var input = ""
    @Environment(\.dismiss) private var dismiss

    init(airlines: [Airline], onOpenChecker: ((Airline) -> Void)? = nil) {
        self.airlines = airlines
        self.onOpenChecker = onOpenChecker
        _assistent = StateObject(wrappedValue: BagageAssistent(airlines: airlines))
    }


    private let suggesties = [
        "Wat mag mee bij Ryanair?",
        "Hoe vroeg moet ik op Schiphol zijn?",
        "Past 55×40×20 cm bij KLM?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if assistent.messages.isEmpty {
                                introBlock
                            }
                            ForEach(assistent.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            if assistent.isThinking {
                                PimThinkingView()
                                    .id("thinking")
                            }
                            if let error = assistent.error {
                                Label(error, systemImage: "exclamationmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.red)
                            }

                            // Acties onder het laatste antwoord: doorpakken
                            // in plaats van alleen lezen.
                            if !assistent.messages.isEmpty, !assistent.isThinking {
                                actionRow
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: assistent.messages) { _, messages in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Purser Pim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
        .onAppear { assistent.prewarm() }
    }

    /// Vervolgacties na een antwoord: directe sprong naar de echte checker
    /// voor de besproken maatschappij + snelle vervolgvragen.
    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let airline = assistent.suggestedAirline, let onOpenChecker {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                    onOpenChecker(airline)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Check je tas bij \(airline.name)")
                            .font(.frutiger(size: 13, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.inkGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(assistent.followUps, id: \.self) { vraag in
                        Button {
                            Task { await assistent.ask(vraag) }
                        } label: {
                            Text(vraag)
                                .font(.frutiger(size: 12, weight: .medium))
                                .foregroundStyle(Theme.navy)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Theme.skyLight)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private var introBlock: some View {
        VStack(spacing: 14) {
            PurserPimCap(size: 52)
                .padding(.top, 24)
            Text("Vraag Purser Pim alles over handbagage")
                .font(.frutiger(size: 17, weight: .bold))
            Text("Pim antwoordt via Apple Intelligence op je iPhone en gebruikt de actuele regels uit onze database. Niets verlaat je toestel.")
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(suggesties, id: \.self) { suggestie in
                    Button {
                        Task { await assistent.ask(suggestie) }
                    } label: {
                        Text(suggestie)
                            .font(.frutiger(size: 13, weight: .medium))
                            .foregroundStyle(Theme.navy)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(Theme.skyLight)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Typ je vraag…", text: $input)
                .font(.frutiger(size: 15))
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(input.isEmpty || assistent.isThinking ? Theme.textSecondary : Theme.sky)
            }
            .disabled(input.isEmpty || assistent.isThinking)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private func send() {
        let question = input
        input = ""
        Task { await assistent.ask(question) }
    }
}

// MARK: - Pim denkt na

/// Levendige denk-indicator terwijl Apple Intelligence het antwoord maakt:
/// wiebelende purserspet, roterende crew-teksten en typende puntjes — Pim
/// voelt bezig in plaats van bevroren.
private struct PimThinkingView: View {
    @State private var phraseIndex = 0
    @State private var rocking = false

    private let phrases = [
        "Pim bladert door de bagageregels…",
        "Pim meet nog even na…",
        "Pim overlegt met de gezagvoerder…",
        "Pim checkt het bagagevak…",
        "Pim vouwt je antwoord netjes op…"
    ]

    private let timer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            PurserPimCap(size: 24)
                .rotationEffect(.degrees(rocking ? 7 : -7), anchor: .bottom)
                .animation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true), value: rocking)

            Text(phrases[phraseIndex])
                .font(.frutiger(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .id(phraseIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

            TypingDots()

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .onAppear { rocking = true }
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                phraseIndex = (phraseIndex + 1) % phrases.count
            }
        }
        .accessibilityLabel("Purser Pim denkt na")
    }
}

/// Drie om de beurt opverende puntjes, zoals in berichten-apps.
private struct TypingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.sky)
                    .frame(width: 5, height: 5)
                    .offset(y: animating ? -3 : 1)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

@available(iOS 26.0, *)
private struct ChatBubble: View {
    let message: BagageAssistent.ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.frutiger(size: 14))
                .foregroundStyle(message.role == .user ? .white : Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                        ? AnyShapeStyle(Theme.inkGradient)
                        : AnyShapeStyle(Color(.systemBackground))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Pakadvies-knop + sheet (AirlineDetailView)

@available(iOS 26.0, *)
struct PakAdviesButton: View {
    let airline: Airline
    @ObservedObject private var session = UserSession.shared
    @State private var showSheet = false
    @State private var showAccount = false

    var body: some View {
        if AIAvailability.isAvailable {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if session.hasAccount {
                    showSheet = true
                } else {
                    showAccount = true
                }
            } label: {
                HStack(spacing: 8) {
                    PurserPimCap(size: 22)
                    Text("Pakadvies van Purser Pim")
                        .font(.frutiger(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.skyLight)
                .foregroundStyle(Theme.navy)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                PakAdviesSheet(airline: airline)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAccount) {
                ScrollView {
                    AccountRequiredView(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "Purser Pim werkt met een profiel",
                        reason: "Pims pakadvies is afgestemd op jouw profiel, tas en reis. Het advies wordt privé op je toestel gegenereerd.",
                        onCompleted: {
                            showAccount = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showSheet = true
                            }
                        }
                    )
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

@available(iOS 26.0, *)
private struct PakAdviesSheet: View {
    let airline: Airline
    @StateObject private var model = PakAdviesModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isLoading {
                        VStack(spacing: 12) {
                            ProgressView().tint(Theme.sky)
                            Text("Advies wordt op je toestel gegenereerd…")
                                .font(.frutiger(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else if let advies = model.advies {
                        Text(advies.titel)
                            .font(.frutiger(size: 20, weight: .bold))

                        ForEach(Array(advies.tips.enumerated()), id: \.offset) { index, tip in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.frutiger(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Theme.sky)
                                    .clipShape(Circle())
                                Text(tip)
                                    .font(.frutiger(size: 14))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.orange)
                            Text(advies.waarschuwing)
                                .font(.frutiger(size: 13, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.orange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text("Gegenereerd op je toestel met Apple Intelligence, op basis van de bagageregels van \(airline.name).")
                            .font(.frutiger(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    } else if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.red)
                            .padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pakadvies van Pim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
            }
            .task { await model.generate(for: airline) }
        }
    }
}

#endif
