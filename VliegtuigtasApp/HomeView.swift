import SwiftUI

private let heroHeight: CGFloat = 380

private var statusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct HomeView: View {
    @EnvironmentObject private var session: UserSession
    @StateObject private var airlineStore = AirlineStore()
    @StateObject private var flightStore  = FlightStore()

    @State private var flightNumber = ""
    @State private var selectedAirline: Airline?
    @State private var showChecker  = false
    @State private var showAirlines = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    VStack(spacing: 20) {
                        flightLookupCard
                        airlineGridSection
                        howItWorksSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .task {
                await airlineStore.load()
                APIClient.shared.sendEvent("page_view", path: "/home")
            }
            .navigationDestination(isPresented: $showChecker) {
                CheckFlowView(preselected: selectedAirline)
            }
            .navigationDestination(isPresented: $showAirlines) {
                AirlineListView()
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        // The gradient establishes the layout frame; the image and overlays
        // are applied via .overlay so they can never push the layout wider.
        LinearGradient(
            colors: [Theme.navy, Theme.navyDark],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .overlay {
            // Photo layer (won't affect layout bounds)
            if UIImage(named: "HeroSuitcase") != nil {
                Image("HeroSuitcase")
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "suitcase.fill")
                    .font(.system(size: 90, weight: .thin))
                    .foregroundStyle(.white.opacity(0.15))
                    .offset(x: 60, y: -20)
            }
        }
        .overlay {
            // Dark gradient on top of photo
            Theme.heroGradient
        }
        .clipped()
        // Branding bar pinned to top
        .overlay(alignment: .topLeading) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Vliegtuigtas")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                if !session.firstName.isEmpty {
                    Text("Hey \(session.firstName) 👋")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, statusBarHeight + 8)
        }
        // Headline + CTA pinned to bottom
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Past jouw tas\nin het vliegtuig?")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(2)

                    Text("Check direct de regels van Ryanair,\nKLM, easyJet en meer.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.80))
                        .lineSpacing(2)
                }

                Button {
                    selectedAirline = nil
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showChecker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Controleer mijn handbagage")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(.white)
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Flight lookup

    private var flightLookupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                Text("Vluchtnummer opzoeken")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.system(size: 15))

                TextField("bijv. KL1234 of FR7542", text: $flightNumber)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.search)
                    .onSubmit { lookupFlight() }
                    .font(.system(size: 15, design: .rounded))

                if flightStore.isLoading {
                    ProgressView().tint(Theme.sky).scaleEffect(0.8)
                } else if !flightNumber.isEmpty {
                    Button { lookupFlight() } label: {
                        Text("Zoek")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.navyGradient)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if let result = flightStore.result {
                if let airline = result.resolvedAirline {
                    HStack(spacing: 10) {
                        if airline.bestLogoUrl != nil {
                            AuthorisedImage(urlString: airline.bestLogoUrl)
                                .frame(width: 28, height: 20)
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                        }
                        Text(airline.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        Button {
                            selectedAirline = airline
                            showChecker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Check nu")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Theme.navy)
                        }
                    }
                    .padding(12)
                    .background(Theme.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.green.opacity(0.2), lineWidth: 1)
                    )
                } else if let name = result.rawAirlineName {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Theme.yellow)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("Niet in onze database — kies handmatig")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button {
                            selectedAirline = nil
                            showChecker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Kies")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Theme.navy)
                        }
                    }
                    .padding(12)
                    .background(Theme.yellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.yellow.opacity(0.25), lineWidth: 1)
                    )
                }
            }

            if let err = flightStore.error {
                Label(err, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.red)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    // MARK: - Airline grid

    private var airlineGridSection: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Populaire maatschappijen")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button {
                    showAirlines = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Bekijk alle")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.navy)
                }
            }

            if airlineStore.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.navy)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(airlineStore.airlines.prefix(9)) { airline in
                        AirlineCard(airline: airline) {
                            selectedAirline = airline
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showChecker = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - How it works

    private var howItWorksSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Hoe werkt het?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            VStack(spacing: 10) {
                StepRow(number: "1", icon: "airplane.departure", color: Theme.navy,
                        title: "Kies je maatschappij",
                        description: "Of zoek automatisch via vluchtnummer.")
                StepRow(number: "2", icon: "ruler", color: Theme.sky,
                        title: "Vul je tasmaten in",
                        description: "Lengte, breedte, hoogte en gewicht.")
                StepRow(number: "3", icon: "checkmark.shield.fill", color: Theme.green,
                        title: "Direct resultaat",
                        description: "Past het niet? We adviseren de juiste tas.")
            }
        }
    }

    private func lookupFlight() {
        let t = flightNumber.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        Task { await flightStore.lookup(t) }
    }
}

// MARK: - Sub-components

private struct AirlineCard: View {
    let airline: Airline
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                AirlineLogo(airline: airline, size: 50)
                Text(airline.name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct StepRow: View {
    let number: String
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.10))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(number)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.20))
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}
