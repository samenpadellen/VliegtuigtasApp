import SwiftUI
import UserNotifications

private let heroHeight: CGFloat = 380
private let contentMaxWidth = Theme.contentMaxWidth

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
    @State private var flightSearchTask: Task<Void, Never>?
    @State private var showProfile = false
    @State private var showAccountForFlight = false
    // Programmatische navigatie voor de carrousels: gewone Buttons + een
    // navigationDestination. NavigationLinks met custom ButtonStyle in
    // geneste ScrollViews waren op iPadOS onbetrouwbaar (dode tikken).
    @State private var selectedAirline: Airline?
    @State private var selectedBagId: String?
    @Namespace private var zoomNamespace

    // Airport & rules information
    @State private var showEURules = false
    @State private var showCustomsInfo = false
    @State private var showBaggageIssues = false
    @State private var showAirportSelection = false
    @State private var showBaggageGuide = false
    @State private var showBagsOverview = false
    @State private var showPackingAlarms = false
    @State private var showReminderSheet = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    VStack(spacing: 20) {
                        flightLookupCard
                        if #available(iOS 26.0, *) {
                            AIAssistentHomeCard()
                        }
                        airlineGridSection
                        shopCarouselSection
                        howItWorksSection
                        quickActionsSection
                        #if !targetEnvironment(macCatalyst)
                        // Instellingen > Safari > Extensies bestaat niet op de Mac.
                        safariExtensionTip
                        #endif
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedAirline) { airline in
                AirlineDetailView(airline: airline)
            }
            .navigationDestination(item: $selectedBagId) { bagId in
                BagDetailView(bagId: bagId)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showAccountForFlight) {
                ScrollView {
                    AccountRequiredView(
                        icon: "airplane.departure",
                        title: "Vlucht opslaan werkt met een profiel",
                        reason: "Je vlucht hoort bij je profiel: zo telt dezelfde vlucht af op je widget, je Apple Watch en al je andere apparaten.",
                        onCompleted: {
                            // Sheet dicht en de vlucht die je wilde bewaren
                            // meteen opslaan: geen tweede tik nodig.
                            showAccountForFlight = false
                            savePendingFlight()
                        }
                    )
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
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
            // allowsHitTesting(false) is essentieel: .clipped() knipt alleen
            // het tekenen, niet de hit-test. Op iPad werd deze fill-foto
            // honderden punten hoger dan de hero en ving hij onzichtbaar
            // alle tikken onder de hero af (o.a. de maatschappijen-carrousel).
            Image("PhotoWindowWing")
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
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
            .allowsHitTesting(false)
        }
        .clipped()
        // Branding bar pinned to top (gecentreerde kolom op brede schermen)
        .overlay(alignment: .top) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Vliegtuigtas")
                        .font(.frutiger(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                // Tik op je naam → profiel (gegevens, eigen tas & vlucht,
                // uitloggen, account verwijderen). Ook zichtbaar zonder naam.
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showProfile = true
                } label: {
                    HStack(spacing: 5) {
                        if session.firstName.isEmpty {
                            Image(systemName: "person.circle")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Profiel")
                                .font(.frutiger(size: 13, weight: .semibold))
                        } else {
                            Text("Hey \(session.firstName) 👋")
                                .font(.frutiger(size: 13, weight: .semibold))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassChrome(in: Capsule(), interactive: true, legacyFill: AnyShapeStyle(.white.opacity(0.15)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open mijn profiel")
            }
            .frame(maxWidth: contentMaxWidth)
            .padding(.horizontal, 20)
            .padding(.top, statusBarHeight + 8)
        }
        // Headline + CTA pinned to bottom (gecentreerde kolom op brede schermen)
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    // Vertrekbord-animatie: klappert naar de headline zoals
                    // een Solari-bord op het vliegveld. Eén instantie = één
                    // klok = één state-write per tick.
                    SplitFlapText("PAST JOUW TAS\nIN HET VLIEGTUIG?", size: 21)

                    Text("Check direct de regels van Ryanair,\nKLM, easyJet en meer.")
                        .font(.frutiger(size: 15))
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
                            .font(.frutiger(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(.white)
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: contentMaxWidth)
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
                    .font(.frutiger(size: 15, weight: .bold))
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
                    .font(.frutiger(size: 15))

                if flightStore.isLoading {
                    ProgressView().tint(Theme.sky).scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onChange(of: flightNumber) { _, newValue in
                scheduleFlightAutoLookup(for: newValue)
            }
            .onChange(of: flightStore.result?.flightDate) { _, newDate in
                applyLookedUpDepartureDate(newDate)
            }

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
                                .font(.frutiger(size: 14, weight: .semibold))
                            if let status = result.statusLabel {
                                FlightStatusChip(status: status, rawStatus: result.status)
                            }
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

                        if result.hasRoute {
                            Divider().padding(.horizontal, 12)
                            FlightRouteRow(result: result)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }

                        Divider().padding(.horizontal, 12)

                        // Bewaar de vlucht in je vluchtenlijst (zie profiel).
                        // Twee rijen: de datum+tijd-picker en de knop passen
                        // niet comfortabel samen op één regel.
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.navy)
                                Text("Vertrek")
                                    .font(.frutiger(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                                if flightStore.result?.flightDate != nil {
                                    Label("Automatisch ingevuld", systemImage: "wand.and.stars")
                                        .font(.frutiger(size: 9, weight: .semibold))
                                        .foregroundStyle(Theme.green)
                                }
                                Spacer()
                                DatePicker("", selection: $departureDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }

                            Button {
                                // Accountgebonden: de vlucht wordt aan je
                                // profiel gekoppeld en via iCloud gesynct
                                // naar widget, Watch en andere apparaten.
                                guard session.hasAccount else {
                                    showAccountForFlight = true
                                    return
                                }
                                savePendingFlight()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: flightSaved ? "checkmark" : "plus.square.on.square")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(flightSaved ? "Vlucht opgeslagen" : "Vlucht opslaan")
                                        .font(.frutiger(size: 13, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(flightSaved ? Theme.green : .white)
                                .background(flightSaved
                                    ? AnyShapeStyle(Theme.green.opacity(0.15))
                                    : AnyShapeStyle(Theme.navyGradient))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(Theme.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.green.opacity(0.2), lineWidth: 1)
                    )
                } else if let name = result.rawAirlineName {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill").foregroundStyle(Theme.yellow)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(name)
                                    .font(.frutiger(size: 14, weight: .semibold))
                                Text("Niet in onze database, kies handmatig")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            if let status = result.statusLabel {
                                FlightStatusChip(status: status, rawStatus: result.status)
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

                        if result.hasRoute {
                            Divider().padding(.horizontal, 12)
                            FlightRouteRow(result: result)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                    }
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
                    .font(.frutiger(size: 18, weight: .bold))
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
                    // Ruimer raakvlak dan alleen de tekst zelf
                    .padding(.vertical, 8)
                    .padding(.leading, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if airlineStore.isLoading && airlineStore.airlines.isEmpty {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemBackground))
                            .frame(width: 118, height: 106)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }
                    Spacer()
                }
            } else {
                // Carrousel die direct naar de detailpagina pusht, met dezelfde
                // zoom-overgang als de maatschappijenpagina. Geen cross-tab
                // handoff meer: dat was de bron van de haperende tikken.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(airlineStore.airlines.prefix(10)) { airline in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedAirline = airline
                            } label: {
                                AirlineCard(airline: airline)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -16)
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
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0.0)],
                    startPoint: .bottomLeading, endPoint: .topTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .allowsHitTesting(false)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Aanbevolen tassen & koffers")
                            .font(.frutiger(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("Gecontroleerd op maat")
                                .font(.frutiger(size: 12))
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
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedBagId = bag.id
                            } label: {
                                ShopCarouselCard(bag: bag)
                            }
                            .buttonStyle(.plain)
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
                .allowsHitTesting(false)

            // Donkere overlay
            LinearGradient(
                colors: [Theme.navy.opacity(0.88), Theme.navy.opacity(0.55)],
                startPoint: .bottom, endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                Text("Hoe werkt het?")
                    .font(.frutiger(size: 18, weight: .bold))
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

    // MARK: - Handige acties (onderaan Home)

    private var quickActionsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Handige acties")
                    .font(.frutiger(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                QuickActionCard(
                    icon: "suitcase.rolling.fill",
                    color: Theme.yellow,
                    title: "Passen mijn tassen?",
                    subtitle: "Al je tassen langs de regels"
                ) {
                    showBagsOverview = true
                }
                QuickActionCard(
                    icon: "checkmark.seal.fill",
                    color: Theme.navy,
                    title: "Wat mag mee?",
                    subtitle: "Vloeistoffen, powerbanks & meer"
                ) {
                    showEURules = true
                }
                QuickActionCard(
                    icon: "alarm.fill",
                    color: Theme.red,
                    title: "Douane info",
                    subtitle: "Belastingvrij importeren"
                ) {
                    showCustomsInfo = true
                }
                QuickActionCard(
                    icon: "bell.badge.fill",
                    color: Theme.orange,
                    title: "Bagage kwijt?",
                    subtitle: "Je rechten & procedure"
                ) {
                    showBaggageIssues = true
                }
                QuickActionCard(
                    icon: "checkmark.shield.fill",
                    color: Theme.green,
                    title: "Check je tas",
                    subtitle: "Past hij in de cabine?"
                ) {
                    nav.openChecker(preselected: nil)
                }
                QuickActionCard(
                    icon: "airplane.circle.fill",
                    color: Theme.sky,
                    title: "Luchthavens",
                    subtitle: "Info per vliegveld"
                ) {
                    showAirportSelection = true
                }
            }
        }
        .sheet(isPresented: $showBaggageGuide) {
            BaggageGuideView()
        }
        .sheet(isPresented: $showBagsOverview) {
            MyBagsOverviewView()
        }
        .sheet(isPresented: $showPackingAlarms) {
            PackingAlarmsSheet()
        }
        .sheet(isPresented: $showReminderSheet) {
            DepartureReminderSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEURules) {
            EURulesView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCustomsInfo) {
            CustomsInfoView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBaggageIssues) {
            BaggageIssuesView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAirportSelection) {
            AirportSelectionView()
                .presentationDragIndicator(.visible)
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
                        .font(.frutiger(size: 14, weight: .semibold))
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

    /// Slaat de opgezochte vlucht op — inclusief alle route-info uit de
    /// lookup — als een nieuwe vlucht in je vluchtenlijst. De eerstvolgende
    /// vertrekkende vlucht verschijnt automatisch op widget/Live Activity/watch.
    private func savePendingFlight() {
        guard let result = flightStore.result,
              let airline = result.resolvedAirline else { return }
        FlightsStore.shared.upsert(SavedFlightRecord(
            number: result.flightNumber ?? flightNumber.trimmingCharacters(in: .whitespaces).uppercased(),
            airlineName: airline.name,
            airlineSlug: airline.slug,
            airlineLogoUrl: airline.bestLogoUrl ?? result.airlineLogoUrl,
            flightIcao: result.flightIcao,
            departure: departureDate,
            departureIata: result.departureIata,
            departureAirport: result.departureAirport,
            arrivalIata: result.arrivalIata,
            arrivalAirport: result.arrivalAirport,
            flightDate: result.flightDate,
            status: result.status
        ))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3)) { flightSaved = true }
    }

    private func lookupFlight() {
        flightSearchTask?.cancel()
        let t = flightNumber.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        flightSaved = false
        Task { await flightStore.lookup(t) }
    }

    /// Zoekt vanzelf, kort na het typen — geen tik op "Zoek" meer nodig.
    private func scheduleFlightAutoLookup(for value: String) {
        flightSearchTask?.cancel()
        flightSaved = false
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 4 else {
            flightStore.result = nil
            flightStore.error = nil
            return
        }
        flightSearchTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await flightStore.lookup(trimmed)
        }
    }

    /// Vult de vertrekdatum aan uit de match; het tijdstip (niet in de API)
    /// blijft staan wat er al stond. Een datum in het verleden negeren we.
    private func applyLookedUpDepartureDate(_ raw: String?) {
        guard let raw else { return }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let parsed = iso.date(from: raw) else { return }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: parsed)
        let time = cal.dateComponents([.hour, .minute], from: departureDate)
        comps.hour = time.hour
        comps.minute = time.minute
        if let combined = cal.date(from: comps), combined > .now {
            withAnimation(.spring(response: 0.3)) { departureDate = combined }
        }
    }
}

// MARK: - Vluchtroute & status

/// Boardingpass-achtige routeregel: IATA-codes groot, luchthavens klein,
/// vliegtuigje ertussen. Alle info komt live uit de flight-lookup.
private struct FlightRouteRow: View {
    let result: FlightLookupResponse

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            endpoint(code: result.departureIata, airport: result.departureAirport, alignment: .leading)

            VStack(spacing: 2) {
                Image(systemName: "airplane")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.sky)
                if let date = formattedDate {
                    Text(date)
                        .font(.frutiger(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            endpoint(code: result.arrivalIata, airport: result.arrivalAirport, alignment: .trailing)
        }
    }

    private func endpoint(code: String?, airport: String?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code ?? "—")
                .font(.frutiger(size: 22, weight: .black))
                .foregroundStyle(Theme.navy)
                .kerning(1)
            if let airport {
                Text(airport)
                    .font(.frutiger(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var formattedDate: String? {
        guard let raw = result.flightDate else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: raw) else { return raw }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "nl_NL")
        fmt.dateFormat = "d MMM"
        return fmt.string(from: date)
    }
}

private struct FlightStatusChip: View {
    let status: String
    let rawStatus: String?

    private var color: Color {
        switch rawStatus {
        case "active":                                       return Theme.green
        case "landed":                                       return Theme.textSecondary
        case "cancelled", "incident", "diverted", "delayed": return Theme.red
        default:                                             return Theme.sky
        }
    }

    var body: some View {
        Text(status)
            .font(.frutiger(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Handige actie-kaart

private struct QuickActionCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.frutiger(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.frutiger(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vertrek-reminder zonder vluchtnummer

/// Zet een aftelling + notificaties zonder dat er een vluchtnummer nodig is.
/// Slaat op via dezelfde SharedFlightStore als de vluchtzoeker, dus widget,
/// Live Activity en Siri-intent werken er automatisch mee.
private struct DepartureReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = UserSession.shared
    @State private var label = ""
    @State private var departure = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var saved = false

    var body: some View {
        NavigationStack {
            if session.hasAccount {
                reminderContent
            } else {
                // Accountgebonden: reminders zijn persoonlijk (naam in de
                // notificatie) en syncen via iCloud naar al je apparaten.
                ScrollView {
                    AccountRequiredView(
                        icon: "bell.badge.fill",
                        title: "Reminders werken met een profiel",
                        reason: "Je vertrekreminder hoort bij je profiel: de notificaties zijn persoonlijk en dezelfde aftelling verschijnt op je widget, je Apple Watch en al je andere apparaten."
                    )
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Vertrekreminder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sluit") { dismiss() }
                    }
                }
            }
        }
    }

    private var reminderContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 18) {
                Text("Geen vluchtnummer? Geen probleem: kies je vertrekmoment en we herinneren je op tijd aan je handbagage.")
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Naam (optioneel)")
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("Bijv. Vakantie Ibiza", text: $label)
                        .font(.frutiger(size: 15))
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Vertrek")
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    DatePicker("", selection: $departure, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                Spacer()

                Button {
                    let name = label.trimmingCharacters(in: .whitespaces)
                    FlightsStore.shared.upsert(SavedFlightRecord(
                        number: name.isEmpty ? "Mijn vlucht" : name,
                        departure: departure
                    ))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.3)) { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: saved ? "checkmark" : "bell.badge.fill")
                        Text(saved ? "Reminder staat aan" : "Zet reminder")
                            .font(.frutiger(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(saved ? AnyShapeStyle(Theme.green) : AnyShapeStyle(Theme.navyGradient))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(saved)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Vertrekreminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sub-components

private struct AirlineCard: View {
    let airline: Airline

    var body: some View {
        VStack(spacing: 8) {
            AirlineLogo(airline: airline, size: 50)
            Text(airline.name)
                .font(.frutiger(size: 11, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 118, height: 106)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityLabel("Bekijk bagageregels van \(airline.name)")
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
                        .font(.frutiger(size: 9, weight: .bold))
                        .foregroundStyle(Theme.navy.opacity(0.65))
                        .kerning(0.7)
                }
                Text(bag.name)
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let dims = dimensionsText {
                    Text(dims)
                        .font(.frutiger(size: 9))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 6)
                HStack(alignment: .center) {
                    if let price = bag.priceEur {
                        Text("€\(Int(price))")
                            .font(.frutiger(size: 18, weight: .bold))
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
                    Text("Bekijk alles")
                        .font(.frutiger(size: 13, weight: .bold))
                        .foregroundStyle(Theme.navy)
                    Text("in de shop")
                        .font(.frutiger(size: 12))
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
        .accessibilityLabel("Bekijk alle tassen en koffers in de shop")
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
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.frutiger(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Text(number)
                .font(.frutiger(size: 20, weight: .bold))
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
                    .font(.frutiger(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(description)
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(number)
                .font(.frutiger(size: 22, weight: .bold))
                .foregroundStyle(color.opacity(0.20))
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}
