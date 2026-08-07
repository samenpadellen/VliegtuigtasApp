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
    @ObservedObject private var tripsStore = TripsStore.shared
    @ObservedObject private var flightsStore = FlightsStore.shared
    @ObservedObject private var bagCollection = BagCollectionStore.shared
    @ObservedObject private var journey = JourneyManager.shared
    @ObservedObject private var bucketStore = BucketListStore.shared

    @State private var showAddFlight = false
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
    @State private var selectedTripId: UUID?
    @Namespace private var zoomNamespace

    // Luchthaveninfo, EU-regels, douane, bagageproblemen, bagagegids en
    // inpak-alarmen hingen hier als losse sheets. Ze staan nu in de Meer-hub
    // en de Reizen-tab, waar ze een eigen label en vaste plek hebben.
    @State private var showBagsOverview = false
    @State private var showFarewell = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    VStack(spacing: 20) {
                        // Home is een geschetste luchthaven: vertrekbord,
                        // route door de terminal, gate-bordjes met tips en een
                        // instapkaart met je statistieken. Alles wat hier
                        // eerder als losse feed-kaart stond (maatschappijen,
                        // shop, luchthaveninfo) heeft nu een eigen tab of
                        // staat in de Meer-hub.
                        // Één leidende kaart, en nooit twee dingen die hetzelfde
                        // zeggen:
                        // • reis/vlucht op komst → bord + reisklaar-kaart
                        // • niets gepland, wél alles ingericht → volgende actie
                        // • nog niet ingericht → niets; de terminal-route
                        //   hieronder is dan zélf de volgende actie
                        if hasUpcoming {
                            departureBoard
                            NextTripCard(
                                onOpenTrip: { selectedTripId = $0 },
                                onAddBag: { showBagsOverview = true }
                            )
                        } else if journey.isFullyActivated {
                            NextBestActionCard(
                                onAddBag: { showBagsOverview = true },
                                onPlanTrip: { nav.selectedTab = .trips },
                                onOpenBucketList: { nav.openMore(.bucketList) },
                                onCheckBag: { nav.openChecker(preselected: nil) }
                            )
                        }

                        TerminalRouteStrip(
                            onAddBag: { showBagsOverview = true },
                            onCheckBag: { nav.openChecker(preselected: nil) },
                            onAddFlight: { showAddFlight = true },
                            onPlanTrip: { nav.selectedTab = .trips }
                        )

                        GateTipsRow(tips: gateTips)

                        BoardingPassStats()
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    // Ruim genoeg om onder de zwevende tabbalk uit te scrollen;
                    // met 48pt bleef de onderste kaart er half achter hangen.
                    .padding(.bottom, 110)
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
            .navigationDestination(item: $selectedTripId) { tripId in
                TripDetailView(tripId: tripId)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showBagsOverview) {
                MyBagsOverviewView()
            }
            .sheet(isPresented: $showAddFlight) {
                AddFlightSheet()
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

    // MARK: - Vertrekbord

    private var hasUpcoming: Bool { tripsStore.next != nil || flightsStore.next != nil }

    /// Bestemming voor het klapperbord. Het bord kent alleen A–Z, cijfers en
    /// een paar tekens, dus accenten worden platgeslagen en de rest gefilterd —
    /// anders komt er een vreemd teken op een klepje terecht.
    private var boardDestination: String {
        let raw = tripsStore.next?.destination
            ?? tripsStore.next?.name
            ?? flightsStore.next?.routeLabel
            ?? flightsStore.next?.number
            ?? "ONBEKEND"
        // De pijl uit "NRN → GRO" zit niet in de tekenset van het bord en werd
        // daardoor een gat van lege klepjes. Een midden-punt kán het bord wel
        // tonen, dus die zetten we ervoor in de plaats.
        let normalised = raw
            .replacingOccurrences(of: "→", with: "·")
            .replacingOccurrences(of: "->", with: "·")
        let folded = normalised.uppercased().folding(options: .diacriticInsensitive, locale: nil)
        let allowed = Set(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789?!.-·")
        let cleaned = String(folded.map { allowed.contains($0) ? $0 : " " })
        // Dubbele spaties samenvouwen, zodat er nooit een rij lege klepjes
        // midden in de tekst overblijft.
        let collapsed = cleaned.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return String(collapsed.prefix(12))
    }

    private var boardCountdown: String {
        tripsStore.next?.countdownLabel ?? flightsStore.next?.countdownLabel ?? "—"
    }

    /// Zwart vertrekbord bovenaan: bestemming klappert in beeld, met vertrek en
    /// status ernaast — zoals het bord in een vertrekhal.
    private var departureBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VERTREK")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .kerning(1.2)
                Spacer()
                Text(boardCountdown.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.yellow, in: Capsule())
            }

            SplitFlapText(boardDestination, size: 19)

            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.yellow)
                Text(tripsStore.next != nil ? "Jouw volgende reis" : "Jouw volgende vlucht")
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.inkGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        // Easter egg: bord lang vasthouden → afscheidsgroet over het bord.
        .overlay {
            if showFarewell {
                VStack(spacing: 4) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 26, weight: .bold))
                    Text("GOEDE REIS!")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .kerning(1.5)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .onLongPressGesture(minimumDuration: 0.9) {
            guard !showFarewell else { return }
            EasterEggStore.shared.discover(.boardFarewell)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { showFarewell = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                withAnimation(.easeOut(duration: 0.35)) { showFarewell = false }
            }
        }
    }

    // MARK: - Gate-tips

    /// Tips om meer uit de app te halen. Elke tip staat er alleen zolang de
    /// bijbehorende actie nog niet gedaan is — behalve de "leer de app"-tips
    /// (widget, Pim, alarm), die niet meetbaar zijn en dus weg te klikken zijn.
    /// Bewust géén tips voor dingen die de terminal-route al vraagt (tas, check,
    /// vlucht, reis). Anders staat dezelfde vraag twee keer op één scherm: als
    /// halte in de route én als gele knop in een tip. De route is de baas over
    /// die vier stappen; de tips gaan over alles daarbuiten.
    private var gateTips: [GateTip] {
        var tips: [GateTip] = []

        if session.passportExpiry == nil {
            tips.append(GateTip(
                id: "passport", gate: "A3",
                title: "Vul je paspoortdatum in",
                body: "We waarschuwen je als hij te kort geldig is.",
                actionTitle: "Naar profiel",
                action: { showProfile = true }
            ))
        }

        if bucketStore.visitedCount == 0 {
            tips.append(GateTip(
                id: "bucket", gate: "C1",
                title: "Vul je bucket list",
                body: "Vink landen af en zie je paspoort vollopen.",
                actionTitle: "Bucket list",
                action: { nav.openMore(.bucketList) }
            ))
        }

        tips.append(GateTip(
            id: "widget", gate: "B1",
            title: "Zet de aftelling op je beginscherm",
            body: "Beginscherm ingedrukt houden, tik op + en zoek Vliegtuigtas.",
            actionTitle: nil, action: nil
        ))

        if #available(iOS 26.0, *) {
            tips.append(GateTip(
                id: "pim", gate: "B3",
                title: "Laat Purser Pim meedenken",
                body: "Vraag wat mee mag bij jouw maatschappij.",
                actionTitle: "Vraag het Pim",
                action: { nav.openMore(.pim) }
            ))
        }

        tips.append(GateTip(
            id: "alarm", gate: "B4",
            title: "Zet een inpak-alarm",
            body: "Word op tijd herinnerd — ook in stille modus.",
            actionTitle: "Naar Reizen",
            action: { nav.selectedTab = .trips }
        ))

        return tips
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
            // De hero heeft een vaste hoogte, en het klapperbord schaalt niet
            // mee met Dynamic Type. Zonder deze grens liep de tekst bij de
            // grootste letterinstellingen dwars door de merkregel bovenaan.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
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

    /// Gedeeld en gecachet i.p.v. per aanroep een nieuwe formatter te maken.
    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    /// Vult de vertrekdatum aan uit de match; het tijdstip (niet in de API)
    /// blijft staan wat er al stond. Een datum in het verleden negeren we.
    private func applyLookedUpDepartureDate(_ raw: String?) {
        guard let raw else { return }
        guard let parsed = Self.isoDateFormatter.date(from: raw) else { return }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: parsed)
        let time = cal.dateComponents([.hour, .minute], from: departureDate)
        comps.hour = time.hour
        comps.minute = time.minute
        guard let combined = cal.date(from: comps) else { return }
        // Een looked-up dag die al voorbij is (herhalend vluchtnummer, andere
        // dag) negeren we; op dagniveau vergelijken i.p.v. exacte timestamp
        // (zelfde reden als AddFlightSheet in Flights.swift).
        guard cal.startOfDay(for: combined) >= cal.startOfDay(for: .now) else { return }
        // Tijdstip komt niet uit de API; als het restant-tijdstip al voorbij
        // is (vandaag vertrekkende vlucht), zou de DatePicker (`in: Date()...`)
        // onze update anders stilletjes terugklemmen naar "nu".
        let finalDate = max(combined, .now)
        withAnimation(.spring(response: 0.3)) { departureDate = finalDate }
    }
}


// MARK: - Volgende reis-kaart

/// Eén samenhangende kaart i.p.v. losse stukjes: vlucht/reis-countdown,
/// paklijst-voortgang en tas-fit voor je eerstvolgende reis, op één plek.
/// `myTripsSection` (alle reizen) en `flightLookupCard` (een nieuwe vlucht
/// opzoeken) blijven ernaast bestaan — dit is puur de "sta ik klaar?"-status.
// MARK: - Terminal-beeldtaal
//
// Home is een geschetste luchthaven: een vertrekbord bovenaan, een route door
// de terminal (check-in → scan → gate → boarding) en gate-bordjes met tips.
// De beeldtaal is die van echte luchthavensignage — zwart bord, geel accent,
// gate-codes — en hergebruikt het klapperbord en de bagagelabel-bouwstenen
// die de app al had.

/// Onthoudt welke gate-tips zijn weggeklikt, zodat een tip niet blijft
/// terugkomen nadat je hem hebt gezien.
@MainActor
final class HomeTipsStore: ObservableObject {
    static let shared = HomeTipsStore()
    private let key = "vt_dismissed_home_tips"
    @Published private(set) var dismissed: Set<String>

    private init() {
        dismissed = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func dismiss(_ id: String) {
        dismissed.insert(id)
        UserDefaults.standard.set(Array(dismissed), forKey: key)
    }
}

/// Geel gate-plaatje met code, zoals de bordjes boven een gate.
private struct GateBadge: View {
    let code: String
    /// Inactieve bordjes krijgen een eigen grijze stijl in plaats van geel met
    /// verlaagde opacity: dat laatste werd in donkere modus een vuile olijfkleur.
    var active: Bool = true

    var body: some View {
        Text(code)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(active ? Theme.ink : Theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                active ? AnyShapeStyle(Theme.yellow) : AnyShapeStyle(Color(.tertiarySystemFill)),
                in: RoundedRectangle(cornerRadius: 5)
            )
    }
}

/// Eén halte op de route door de terminal.
private struct TerminalStop: Identifiable {
    let id: String
    let gate: String
    let title: String
    let icon: String
    let done: Bool
    let action: () -> Void
}

/// De route door de terminal: vier haltes, verbonden door een gestreepte
/// taxibaan. Vervangt de vlakke "Aan de slag"-checklist — dezelfde vier
/// mijlpalen, maar als looproute door een luchthaven, en hij blijft staan als
/// alles klaar is ("READY TO BOARD").
private struct TerminalRouteStrip: View {
    @ObservedObject private var journey = JourneyManager.shared

    let onAddBag: () -> Void
    let onCheckBag: () -> Void
    let onAddFlight: () -> Void
    let onPlanTrip: () -> Void

    private var stops: [TerminalStop] {
        [
            TerminalStop(id: "checkin", gate: "A1", title: "Check-in",
                         icon: "suitcase.rolling.fill", done: journey.hasBag, action: onAddBag),
            TerminalStop(id: "scan", gate: "A2", title: "Scan",
                         icon: "checkmark.shield.fill", done: journey.hasCheckedBag, action: onCheckBag),
            TerminalStop(id: "gate", gate: "B1", title: "Gate",
                         icon: "airplane.departure", done: journey.hasFlight, action: onAddFlight),
            TerminalStop(id: "boarding", gate: "B2", title: "Boarding",
                         icon: "map.fill", done: journey.hasTrip, action: onPlanTrip),
        ]
    }

    private var allDone: Bool { journey.isFullyActivated }

    private var remainingLabel: String {
        let remaining = journey.totalSteps - journey.completedSteps
        return remaining == 1
            ? "Nog één halte te gaan."
            : "Nog \(remaining) haltes te gaan."
    }

    @State private var gateTaps: [String: Int] = [:]
    @State private var lastGateTap = Date.distantPast
    @State private var announcement: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(allDone ? "READY TO BOARD" : "JOUW ROUTE DOOR DE TERMINAL")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(allDone ? Theme.green : Theme.textSecondary)
                        .kerning(1.1)
                    Text(allDone
                         ? "Alles geregeld — je staat klaar bij de gate."
                         : remainingLabel)
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    stopNode(stop)
                    if index < stops.count - 1 {
                        // Taxibaan tussen twee haltes: doorlopend geel tot waar
                        // je bent, daarna gestreept grijs.
                        Rectangle()
                            .fill(stop.done ? Theme.yellow : Theme.textSecondary.opacity(0.22))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 22)
                    }
                }
            }

            // Easter egg: gate-omroep na 3× tikken op een afgeronde halte.
            if let announcement {
                HStack(spacing: 7) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(announcement)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .kerning(0.5)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 10))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    /// Afgeronde haltes blijven tikbaar — 3× tikken roept de gate om
    /// (easter egg). Openstaande haltes doen gewoon hun actie.
    private func handleDoneTap(_ stop: TerminalStop) {
        let now = Date()
        if now.timeIntervalSince(lastGateTap) > 1.2 { gateTaps = [:] }
        lastGateTap = now
        let count = (gateTaps[stop.id] ?? 0) + 1
        gateTaps[stop.id] = count
        guard count >= 3, announcement == nil else { return }
        gateTaps = [:]
        EasterEggStore.shared.discover(.gateAnnouncement)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            announcement = "LAATSTE OMROEP · GATE \(stop.gate) · \(stop.title.uppercased())"
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(.easeOut(duration: 0.35)) { announcement = nil }
        }
    }

    private func stopNode(_ stop: TerminalStop) -> some View {
        Button(action: stop.done ? { handleDoneTap(stop) } : stop.action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(stop.done ? Theme.ink : Color(.secondarySystemBackground))
                    Circle()
                        .strokeBorder(stop.done ? Theme.yellow : Theme.textSecondary.opacity(0.25), lineWidth: 2)
                    Image(systemName: stop.done ? "checkmark" : stop.icon)
                        .font(.system(size: stop.done ? 15 : 14, weight: .bold))
                        .foregroundStyle(stop.done ? Theme.yellow : Theme.textSecondary)
                }
                .frame(width: 46, height: 46)

                // Eén regel, desnoods verkleind: bij grote letters brak
                // "Check-in" anders middenin het woord af ("Chec k-in").
                Text(stop.title)
                    .font(.frutiger(size: 11, weight: .bold))
                    .foregroundStyle(stop.done ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                GateBadge(code: stop.gate, active: stop.done)
            }
            // Iets breder dan de cirkel: zonder deze ruimte had "Boarding" geen
            // plek en werd het afgekapt tot "Board…" bij grote letters.
            .frame(width: 66)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(stop.title), gate \(stop.gate), \(stop.done ? "klaar" : "nog te doen")")
    }
}

/// Eén tip, gepresenteerd als gate-bordje.
private struct GateTip: Identifiable {
    let id: String
    let gate: String
    let title: String
    let body: String
    let actionTitle: String?
    let action: (() -> Void)?
}

/// Rij gate-bordjes met tips om meer uit de app te halen. Elke tip verschijnt
/// alleen als de bijbehorende actie nog níét gedaan is, en is weg te klikken.
private struct GateTipsRow: View {
    let tips: [GateTip]
    @ObservedObject private var store = HomeTipsStore.shared

    private var visible: [GateTip] {
        tips.filter { !store.dismissed.contains($0.id) }
    }

    var body: some View {
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("TIPS VOOR ONDERWEG")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .kerning(1.1)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(visible) { tip in
                            card(tip)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    /// Zwart bord met geel accent — een gate-bordje, geen gewone tipkaart.
    private func card(_ tip: GateTip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                GateBadge(code: tip.gate)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        store.dismiss(tip.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tip verbergen")
            }

            Text(tip.title)
                .font(.frutiger(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(tip.body)
                .font(.frutiger(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let actionTitle = tip.actionTitle, let action = tip.action {
                Button(action: action) {
                    HStack(spacing: 5) {
                        Text(actionTitle)
                            .font(.frutiger(size: 12, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        // Ruimer dan eerst: bij 168pt viel de laatste tekstregel weg achter de
        // knop. De kaarten houden gelijke hoogte, maar nu mét de tekst erin.
        .frame(width: 232, height: 196, alignment: .topLeading)
        .background(Theme.inkGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Statistiekenstrip in instapkaart-vorm: perforatie, velden en streepjescode
/// — dezelfde beeldtaal als het bagagelabel in het profiel.
private struct BoardingPassStats: View {
    @ObservedObject private var journey = JourneyManager.shared
    @ObservedObject private var bucket = BucketListStore.shared
    @ObservedObject private var trips = TripsStore.shared
    @ObservedObject private var session = UserSession.shared

    /// Jaartal waarin deze reispas "uitgegeven" is — het jaar van je eerste
    /// reis, of anders dit jaar.
    private var memberSince: String {
        let earliest = trips.sortedIncludingHidden.first?.startDate ?? .now
        let year = Calendar.current.component(.year, from: min(earliest, .now))
        return String(year)
    }

    @State private var planeTaps = 0
    @State private var lastPlaneTap = Date.distantPast
    @State private var taxiing = false
    @State private var showLogbook = false

    var body: some View {
        TagPaper {
            VStack(spacing: 12) {
                HStack {
                    Text("VLIEGTUIGTAS · REISPAS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .kerning(1)
                    Spacer()
                    // Easter egg: 3× tikken laat het vliegtuigje taxiën.
                    Image(systemName: "airplane")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(taxiing ? Theme.yellow : Theme.navy)
                        .offset(x: taxiing ? -170 : 0)
                        .contentShape(Rectangle().inset(by: -10))
                        .onTapGesture { handlePlaneTap() }
                        .accessibilityLabel("Vliegtuigje")
                }

                TagPerforation()

                // Je naam bovenaan, zoals op de paspoortomslag — dat maakt van
                // een statistiekenkaart iets persoonlijks.
                HStack(spacing: 8) {
                    TagField(label: "PASSAGIER",
                             value: session.firstName.isEmpty ? "REIZIGER" : session.firstName.uppercased())
                    TagField(label: "SINDS", value: memberSince, alignment: .trailing)
                }

                TagPerforation()

                HStack(spacing: 8) {
                    TagField(label: "CHECKS", value: "\(journey.successfulChecks)")
                    TagField(label: "LANDEN", value: "\(bucket.visitedCount)", alignment: .center)
                    TagField(label: "REIZEN", value: "\(trips.trips.count)", alignment: .trailing)
                }

                Barcode(seed: "vliegtuigtas-\(journey.successfulChecks)-\(bucket.visitedCount)", height: 26)

                // De kleine lettertjes onderaan een instapkaart — hier staat de
                // verwijzing naar Pursers logboek, met alle hints.
                Button {
                    showLogbook = true
                } label: {
                    Text("KLEINE LETTERTJES · DEZE APP HEEFT GEHEIMEN. PURSERS LOGBOEK →")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary.opacity(0.75))
                        .kerning(0.3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pursers logboek met hints voor verborgen grapjes")
            }
            .padding(16)
        }
        .sheet(isPresented: $showLogbook) {
            PurserLogbookView()
        }
    }

    private func handlePlaneTap() {
        let now = Date()
        if now.timeIntervalSince(lastPlaneTap) > 1.2 { planeTaps = 0 }
        lastPlaneTap = now
        planeTaps += 1
        guard planeTaps >= 3, !taxiing else { return }
        planeTaps = 0
        EasterEggStore.shared.discover(.taxiingPlane)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 1.1)) { taxiing = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.45)) { taxiing = false }
        }
    }
}

private struct NextTripCard: View {
    @EnvironmentObject private var airlineStore: AirlineStore
    @EnvironmentObject private var session: UserSession
    @ObservedObject private var tripsStore = TripsStore.shared
    @ObservedObject private var flightsStore = FlightsStore.shared
    @ObservedObject private var bagCollection = BagCollectionStore.shared
    @State private var selectedAirlineOverride: Airline?

    let onOpenTrip: (UUID) -> Void
    let onAddBag: () -> Void

    private var trip: Trip? { tripsStore.next }

    private var flight: SavedFlightRecord? {
        if let linkedId = trip?.linkedFlightId,
           let linked = flightsStore.flights.first(where: { $0.id == linkedId }) {
            return linked
        }
        return flightsStore.next
    }

    private var resolvedAirline: Airline? {
        guard let slug = flight?.airlineSlug else { return nil }
        return airlineStore.airlines.first { $0.slug == slug }
    }

    private var countdownLabel: String {
        trip?.countdownLabel ?? flight?.countdownLabel ?? "—"
    }

    private var bagFitOK: Bool? {
        guard let bag = bagCollection.bags.first,
              let airline = resolvedAirline ?? selectedAirlineOverride else { return nil }
        return BagAirlineFit.evaluate(bag: bag, airline: airline).allowedInCabin
    }

    /// Alleen zinvol bij een echte Trip (paklijst-voortgang bestaat niet voor
    /// een losse, niet-gekoppelde vlucht) — vandaar optioneel.
    private var readiness: TripReadiness? {
        guard let trip else { return nil }
        let progress = trip.progress
        let packingPercent = progress.total > 0 ? Double(progress.checked) / Double(progress.total) : 1
        return TripReadiness(
            packingPercent: packingPercent,
            bagFitOK: bagFitOK,
            passportOK: session.isPassportValid(forTripStarting: trip.startDate)
        )
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().padding(.leading, 16)
                if let trip, trip.progress.total > 0 {
                    packingRow(trip)
                    Divider().padding(.leading, 16)
                }
                bagFitRow
            }
        }
    }

    private var header: some View {
        Button {
            if let trip { onOpenTrip(trip.id) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.navy.opacity(0.10))
                    if let photoUrl = trip?.photoUrl {
                        AuthorisedImage(urlString: photoUrl, fill: true)
                    } else {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.navy)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip?.name ?? flight?.number ?? "Jouw volgende reis")
                        .font(.frutiger(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle = trip?.destination ?? flight?.routeLabel {
                        Text(subtitle)
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // Geen aftelling meer hier: het vertrekbord direct hierboven
                // toont die al. Twee keer "Over 3 dagen" pal onder elkaar was
                // dubbelop. Deze kaart gaat over hoe klaar je bent, het bord
                // over wanneer je gaat.
                if let readiness {
                    Text("\(readiness.overallPercent)% reisklaar")
                        .font(.frutiger(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Theme.yellow)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .disabled(trip == nil)
    }

    private func packingRow(_ trip: Trip) -> some View {
        Button {
            onOpenTrip(trip.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.navy)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paklijst: \(trip.progress.checked)/\(trip.progress.total) ingepakt")
                        .font(.frutiger(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    ProgressView(value: Double(trip.progress.checked), total: Double(trip.progress.total))
                        .tint(Theme.navy)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bagFitRow: some View {
        if bagCollection.bags.isEmpty {
            Button(action: onAddBag) {
                HStack(spacing: 12) {
                    Image(systemName: "suitcase.rolling")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.navy)
                    Text("Voeg een tas toe om je tas-fit te zien")
                        .font(.frutiger(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.navy)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.navy)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
        } else if let airline = resolvedAirline ?? selectedAirlineOverride {
            fitVerdictRow(airline: airline)
        } else {
            airlinePickerRow
        }
    }

    private var airlinePickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kies je maatschappij voor een tas-fit-check")
                .font(.frutiger(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(airlineStore.airlines.prefix(12)) { airline in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedAirlineOverride = airline
                        } label: {
                            Text(airline.name)
                                .font(.frutiger(size: 12, weight: .semibold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
    }

    private func fitVerdictRow(airline: Airline) -> some View {
        let fit = BagAirlineFit.evaluate(bag: bagCollection.bags.first!, airline: airline)
        let (text, icon, color): (String, String, Color) = {
            if fit.allowedInCabin {
                return ("Je tas mag mee in de cabine bij \(airline.name)", "checkmark.seal.fill", Theme.green)
            } else if fit.withinWeight == false {
                return ("Te zwaar voor de cabine bij \(airline.name)", "scalemass.fill", Theme.orange)
            } else {
                return ("Past niet in de cabine bij \(airline.name)", "xmark.seal.fill", Theme.red)
            }
        }()
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.frutiger(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Vertrek-reminder zonder vluchtnummer

/// Zet een aftelling + notificaties zonder dat er een vluchtnummer nodig is.
/// Slaat op via dezelfde SharedFlightStore als de vluchtzoeker, dus widget,
/// Live Activity en Siri-intent werken er automatisch mee.
/// Vertrekreminder zonder vluchtnummer. Dit scherm was tot 3.0.0 volledig
/// onbereikbaar: de sheet zat wel in HomeView, maar niets zette de vlag ooit
/// op true. Nu staat het in de Reizen-tab, naast "Vlucht toevoegen".
struct DepartureReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = UserSession.shared
    @State private var label = ""
    @State private var departure = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var saved = false
    /// Schiphol als vertrek voorgevuld: veruit de meeste gebruikers vertrekken
    /// daar, en het scheelt een keuze.
    @State private var from: RouteAirport? = RouteAirports.find(iata: "AMS")
    @State private var to: RouteAirport?
    @State private var pickingFrom = false
    @State private var pickingTo = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Geen vluchtnummer? Kies je route en vertrekmoment. Je krijgt dezelfde aftelling op je widget en Apple Watch als bij een echte vlucht.")
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Route: dit maakt van een kale reminder een echte vlucht met
                // een herkenbare "AMS → ZRH" op alle glanceable plekken.
                HStack(spacing: 10) {
                    airportField(title: "VAN", airport: from) { pickingFrom = true }
                    Image(systemName: "airplane")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 14)
                    airportField(title: "NAAR", airport: to) { pickingTo = true }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("VERTREK")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(Theme.textSecondary)
                    DatePicker("", selection: $departure, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .tint(Theme.navy)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("NAAM (OPTIONEEL)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(Theme.textSecondary)
                    TextField(suggestedLabel, text: $label)
                        .font(.frutiger(size: 15))
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    save()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: saved ? "checkmark" : "bell.badge.fill")
                        Text(saved ? "Staat in je vluchten" : "Bewaar deze vlucht")
                            .font(.frutiger(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(saved ? AnyShapeStyle(Theme.green) : AnyShapeStyle(Theme.inkGradient))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(saved)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vlucht zonder nummer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sluit") { dismiss() }
            }
        }
        .sheet(isPresented: $pickingFrom) {
            AirportPickerSheet(title: "Van welke luchthaven?", selection: $from)
        }
        .sheet(isPresented: $pickingTo) {
            AirportPickerSheet(title: "Waar vlieg je heen?", selection: $to)
        }
    }

    /// Eén helft van de route. Leeg toont een uitnodiging, gevuld de code groot
    /// met de stad eronder — zoals op een instapkaart.
    private func airportField(title: String, airport: RouteAirport?, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .kerning(0.8)
                    .foregroundStyle(Theme.textSecondary)
                Text(airport?.iata ?? "––")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(airport == nil ? Theme.textSecondary.opacity(0.5) : Theme.textPrimary)
                Text(airport?.city ?? "Kies luchthaven")
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.ink.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Voorstel voor de naam, zodat het veld zelden ingevuld hoeft te worden.
    private var suggestedLabel: String {
        if let to { return "Bijv. \(to.city)" }
        return "Bijv. Vakantie Ibiza"
    }

    private func save() {
        let name = label.trimmingCharacters(in: .whitespaces)
        // Zonder vluchtnummer is de route de beste identificatie; anders de
        // zelfgekozen naam, en pas als laatste een generieke titel.
        let number: String
        if !name.isEmpty {
            number = name
        } else if let from, let to {
            number = "\(from.iata) → \(to.iata)"
        } else {
            number = "Mijn vlucht"
        }

        FlightsStore.shared.upsert(SavedFlightRecord(
            number: number,
            departure: departure,
            departureIata: from?.iata,
            departureAirport: from.map { "\($0.name), \($0.city)" },
            arrivalIata: to?.iata,
            arrivalAirport: to.map { "\($0.name), \($0.city)" }
        ))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
    }
}

// MARK: - Luchthavenkiezer

/// Zoekbare lijst met luchthavens. Zoekt op code, stad, land én
/// luchthavennaam, zodat "ZRH", "zurich" en "zwitserland" alle drie werken.
struct AirportPickerSheet: View {
    let title: String
    @Binding var selection: RouteAirport?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var dutchResults: [RouteAirport] {
        RouteAirports.dutch.filter { $0.matches(query) }
    }
    private var otherResults: [RouteAirport] {
        RouteAirports.international.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !dutchResults.isEmpty {
                    Section("Vanuit Nederland") {
                        ForEach(dutchResults) { airport in row(airport) }
                    }
                }
                if !otherResults.isEmpty {
                    Section(query.isEmpty ? "Bestemmingen" : "Resultaten") {
                        ForEach(otherResults) { airport in row(airport) }
                    }
                }
                if dutchResults.isEmpty && otherResults.isEmpty {
                    Text("Geen luchthaven gevonden voor '\(query)'.")
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: "Zoek op stad, land of code")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Annuleer") { dismiss() }
                }
            }
        }
    }

    private func row(_ airport: RouteAirport) -> some View {
        Button {
            selection = airport
            UISelectionFeedbackGenerator().selectionChanged()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(airport.iata)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 46, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(airport.city)
                        .font(.frutiger(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(airport.name) · \(airport.country)")
                        .font(.frutiger(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if selection?.iata == airport.iata {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.navy)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
