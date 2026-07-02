import SwiftUI

private let heroHeight: CGFloat = 380

private var statusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct HomeView: View {
    @EnvironmentObject private var session: UserSession
    @EnvironmentObject private var nav: AppNavigator
    @EnvironmentObject private var airlineStore: AirlineStore
    @EnvironmentObject private var bagStore: BagStore
    @StateObject private var flightStore = FlightStore()

    @State private var flightNumber = ""
    @State private var departureDate = Date()
    @State private var flightSaved = false
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    VStack(spacing: 20) {
                        flightLookupCard
                        airlineGridSection
                        shopCarouselSection
                        howItWorksSection
                        safariExtensionTip
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
                async let loadAirlines: () = airlineStore.load()
                async let loadBags: () = bagStore.loadIfNeeded()
                await loadAirlines
                await loadBags
                APIClient.shared.sendEvent("page_view", path: "/home")
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
            Image("PhotoWindowWing")
                .resizable()
                .scaledToFill()
        }
        .overlay {
            // KLM-stijl donker verloop over de foto
            LinearGradient(
                colors: [
                    Theme.navy.opacity(0.72),
                    Theme.navy.opacity(0.30),
                    Theme.navy.opacity(0.60)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
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
                        .glassChrome(in: Capsule(), legacyFill: AnyShapeStyle(.white.opacity(0.15)))
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
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    nav.openChecker(preselected: nil)
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
                    VStack(spacing: 0) {
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
                                nav.openChecker(preselected: airline)
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

                        Divider().padding(.horizontal, 12)

                        // Bewaar de vlucht voor de aftelwidget op home/lockscreen.
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.navy)
                            Text("Vertrek")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                            DatePicker("", selection: $departureDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                            Spacer()
                            Button {
                                SharedFlightStore.saveFlight(
                                    number: result.flightNumber ?? flightNumber.trimmingCharacters(in: .whitespaces).uppercased(),
                                    airlineName: airline.name,
                                    airlineSlug: airline.slug,
                                    departure: departureDate
                                )
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                withAnimation(.spring(response: 0.3)) { flightSaved = true }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: flightSaved ? "checkmark" : "plus.square.on.square")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(flightSaved ? "In widget" : "Zet in widget")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(flightSaved ? Theme.green : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(flightSaved
                                    ? AnyShapeStyle(Theme.green.opacity(0.15))
                                    : AnyShapeStyle(Theme.navyGradient))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
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
                            nav.openChecker(preselected: nil)
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

    // MARK: - Airline grid (3 × 1, meestgebruikte maatschappijen)

    private var airlineGridSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Populaire maatschappijen")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { nav.openAirlines() } label: {
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
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 90)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(airlineStore.airlines.prefix(3)) { airline in
                        AirlineCard(airline: airline) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            nav.openChecker(preselected: airline)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shop carousel

    private var shopCarouselSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Foto-banner header — alleen de "Bekijk alle"-knop is tikbaar,
            // niet de hele banner als sectie.
            ZStack(alignment: .bottomLeading) {
                Image("PhotoOverheadBlue")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                LinearGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0.0)],
                    startPoint: .bottomLeading, endPoint: .topTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .allowsHitTesting(false)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Aanbevolen tassen")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("Gecontroleerd op maat")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Spacer()
                    Button { nav.openShop() } label: {
                        HStack(spacing: 4) {
                            Text("Bekijk alle")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassChrome(in: Capsule(), interactive: true, legacyFill: AnyShapeStyle(.white.opacity(0.20)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            // Edge-to-edge scroll (compenseer de 16pt parent padding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    if bagStore.isLoading && bagStore.bags.isEmpty {
                        ForEach(0..<5, id: \.self) { _ in ShopCarouselSkeletonCard() }
                    } else {
                        ForEach(bagStore.bags.prefix(8)) { bag in
                            NavigationLink(destination: BagDetailView(bagId: bag.id)
                                .zoomDestination(id: bag.id, in: zoomNamespace)) {
                                ShopCarouselCard(bag: bag)
                            }
                            .buttonStyle(.pressableCard)
                            .zoomSource(id: bag.id, in: zoomNamespace)
                            .carouselTransition()
                        }
                        if !bagStore.bags.isEmpty {
                            ViewAllShopCard { nav.openShop() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -16)
        }
    }

    // MARK: - How it works

    private var howItWorksSection: some View {
        ZStack(alignment: .topLeading) {
            // Foto achtergrond
            Image("PhotoOverheadOpen")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22))

            // Donkere overlay
            LinearGradient(
                colors: [Theme.navy.opacity(0.88), Theme.navy.opacity(0.55)],
                startPoint: .bottom, endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 16) {
                Text("Hoe werkt het?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    PhotoStepRow(number: "1", icon: "airplane.departure",
                                 title: "Kies je maatschappij",
                                 description: "Of zoek via vluchtnummer.")
                    PhotoStepRow(number: "2", icon: "ruler",
                                 title: "Vul je tasmaten in",
                                 description: "Lengte, breedte, hoogte en gewicht.")
                    PhotoStepRow(number: "3", icon: "checkmark.shield.fill",
                                 title: "Direct resultaat",
                                 description: "Past het niet? We adviseren de juiste tas.")
                }
            }
            .padding(20)
        }
    }

    private var safariExtensionTip: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.skyLight).frame(width: 44, height: 44)
                    Image(systemName: "safari.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.sky)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Check tassen tijdens het shoppen")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Zet de Vliegtuigtas-extensie aan in Instellingen > Safari > Extensies.")
                        .font(.caption1)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func lookupFlight() {
        let t = flightNumber.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        flightSaved = false
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
        .accessibilityLabel("Controleer handbagage bij \(airline.name)")
    }
}

// MARK: - Shop carousel card

private struct ShopCarouselCard: View {
    let bag: Bag

    private var dimensionsText: String? {
        let parts = [bag.length, bag.width, bag.depth].compactMap { $0.map { "\(Int($0))" } }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "×") + " cm"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Productafbeelding — witte achtergrond, product centred met minimale padding
            ZStack {
                Color.white
                if bag.imageUrl != nil {
                    AuthorisedImage(urlString: bag.imageUrl)
                        .padding(10)
                } else {
                    Image(systemName: "bag")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.navy.opacity(0.15))
                }
            }
            .frame(width: 160, height: 120)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 16, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 16
            ))

            // Info
            VStack(alignment: .leading, spacing: 5) {
                if let brand = bag.brand {
                    Text(brand.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy.opacity(0.65))
                        .kerning(0.7)
                }
                Text(bag.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let dims = dimensionsText {
                    Text(dims)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 6)
                HStack(alignment: .center) {
                    if let price = bag.priceEur {
                        Text("€\(Int(price))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    // Decoratief: de hele kaart opent de productpagina (NavigationLink),
                    // dit is geen losse link meer naar de externe affiliate-URL.
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.navyGradient)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 160)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bag.brand.map { $0 + " " } ?? "")\(bag.name)\(bag.priceEur.map { ", €\(Int($0))" } ?? "")")
    }
}

// MARK: - "Bekijk alle tassen" eindkaart

private struct ViewAllShopCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.navy.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.navy)
                }
                VStack(spacing: 3) {
                    Text("Bekijk alle")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy)
                    Text("tassen")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.navy.opacity(0.45))
            }
            .frame(width: 100)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 20)
            .background(Theme.navy.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.navy.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bekijk alle tassen in de shop")
    }
}

// MARK: - Skeleton carousel card

private struct ShopCarouselSkeletonCard: View {
    @State private var opacity: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemFill)
                .frame(width: 160, height: 120)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 16, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 16
                ))
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 8).frame(maxWidth: 45)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 11).frame(maxWidth: 136)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 11).frame(maxWidth: 100)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 18).frame(maxWidth: 55)
            }
            .padding(12)
        }
        .frame(width: 160)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { opacity = 0.5 }
        }
    }
}

private struct PhotoStepRow: View {
    let number: String
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .glassChrome(in: Circle(), legacyFill: AnyShapeStyle(.white.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Text(number)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.20))
        }
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
