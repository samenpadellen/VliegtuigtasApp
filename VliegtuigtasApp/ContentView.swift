import SwiftUI

/// Eén gedeelde navigator voor de tabbalk. Voorheen duwde HomeView zijn eigen
/// kopie van CheckFlowView/AirlineListView/BagsShopView op zijn eigen stack,
/// terwijl de tabbalk al aparte instanties van diezelfde schermen had — dat
/// zorgde ervoor dat de tabbalk het verkeerde item liet oplichten (of dat een
/// tik op een maatschappij in de shop leek te belanden). Door hier écht van
/// tab te wisselen blijft de tabbalk altijd gesynchroniseerd met het scherm.

/// Eén verzoek om de Checker-tab op een specifieke maatschappij te zetten.
/// De `token` verandert bij élke aanroep — ook als dezelfde maatschappij
/// nogmaals wordt getikt — zodat CheckFlowView altijd reageert, zonder dat
/// de hele tab opnieuw opgebouwd hoeft te worden (dat gaf een instabiele,
/// flikkerende overgang omdat de view + zijn data telkens weer vers laadden).
struct CheckerRequest: Equatable {
    let airline: Airline?
    let token: UUID
}

/// Verzoek om de Shop-tab met een maatschappij-filter te openen ("tassen
/// die passen bij X"), vanuit het checkresultaat of de detailpagina.
struct ShopRequest: Equatable {
    let airlineSlug: String
    let token: UUID
}

/// Alles wat onder "Meer" een vaste plek heeft. In 3.0.0 hingen deze schermen
/// als losse sheets achter de Home-feed, waardoor ze in de praktijk
/// onvindbaar waren; nu staan ze in één benoemde hub.
enum MoreDestination: String, Identifiable, Hashable, CaseIterable {
    case airports, euRules, customs, baggageIssues
    case passport, bucketList, pim, guide
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .airports:      return "Luchthavens"
        case .euRules:       return "EU-regels"
        case .customs:       return "Douane"
        case .baggageIssues: return "Bagageprobleem"
        case .passport:      return "Reispaspoort"
        case .bucketList:    return "Bucket list"
        case .pim:           return "Purser Pim"
        case .guide:         return "Wat mag mee?"
        case .profile:       return "Mijn profiel"
        }
    }

    var subtitle: String {
        switch self {
        case .airports:      return "Terminals en tips"
        case .euRules:       return "Vloeistoffen en verboden"
        case .customs:       return "Wat mag je meenemen?"
        case .baggageIssues: return "Kwijt of beschadigd"
        case .passport:      return "Jouw landen en stats"
        case .bucketList:    return "Waar wil je heen?"
        case .pim:           return "Vraag het de purser"
        case .guide:         return "Complete bagagegids"
        case .profile:       return "Gegevens en account"
        }
    }

    var icon: String {
        switch self {
        case .airports:      return "building.2.fill"
        case .euRules:       return "checklist"
        case .customs:       return "shield.lefthalf.filled"
        case .baggageIssues: return "exclamationmark.triangle.fill"
        case .passport:      return "book.closed.fill"
        case .bucketList:    return "globe.europe.africa.fill"
        case .pim:           return "person.fill.questionmark"
        case .guide:         return "bag.badge.questionmark"
        case .profile:       return "person.crop.circle.fill"
        }
    }

    /// Op reis / voor vertrek / over jou — bepaalt de groepering in de hub.
    var group: MoreGroup {
        switch self {
        case .airports, .euRules, .customs, .baggageIssues: return .airport
        case .guide:                                        return .airport
        case .passport, .bucketList, .pim:                  return .travel
        case .profile:                                      return .account
        }
    }
}

enum MoreGroup: String, CaseIterable {
    case airport, travel, account

    var title: String {
        switch self {
        case .airport: return "Luchthaven & regels"
        case .travel:  return "Jouw reiswereld"
        case .account: return "Account"
        }
    }
}

@MainActor
final class AppNavigator: ObservableObject {
    enum Tab: Hashable {
        case home, check, trips, shop, more
    }

    @Published var selectedTab: Tab = .home
    @Published var checkerRequest: CheckerRequest?
    @Published var shopRequest: ShopRequest?
    /// Token in plaats van Bool: verandert bij élke aanroep, ook als Home
    /// al vooraan stond, zodat de widget-deeplink altijd het gesprek opent.
    @Published var openPimChatToken: UUID?
    /// Vraagt de Check-tab om de maatschappijenlijst te openen.
    @Published var airlineListToken: UUID?
    /// Vraagt de Meer-tab om direct één bestemming te openen.
    @Published var moreDestination: MoreDestination?

    func openChecker(preselected airline: Airline?) {
        checkerRequest = CheckerRequest(airline: airline, token: UUID())
        selectedTab = .check
    }

    /// De maatschappijenlijst is geen eigen tab meer: regels opzoeken hoort
    /// bij "Check", waar de tas-check zelf ook begint.
    func openAirlines() {
        airlineListToken = UUID()
        selectedTab = .check
    }

    func openShop(airlineSlug: String? = nil) {
        if let airlineSlug {
            shopRequest = ShopRequest(airlineSlug: airlineSlug, token: UUID())
        }
        selectedTab = .shop
    }

    /// Vanuit de Purser Pim-widget: Pim woont onder "Meer".
    func openPimChat() {
        selectedTab = .more
        moreDestination = .pim
        openPimChatToken = UUID()
    }

    func openMore(_ destination: MoreDestination) {
        selectedTab = .more
        moreDestination = destination
    }
}

struct ContentView: View {
    @StateObject private var nav = AppNavigator()
    // Eén gedeelde AirlineStore/BagStore voor de hele app — voorheen laadde
    // bijna elk scherm (Home, Shop, Checker, Maatschappijen-lijst, ...) zijn
    // eigen kopie van dezelfde catalogus. Dat kostte extra data en zorgde voor
    // een laadspinner bij elke tabwissel, ook als de data al bekend was.
    @StateObject private var airlineStore = AirlineStore()
    @StateObject private var bagStore = BagStore()
    @StateObject private var updateChecker = AppUpdateChecker.shared

    var body: some View {
        tabView
            .tint(Theme.inkAccent)
            .environmentObject(nav)
            .environmentObject(airlineStore)
            .environmentObject(bagStore)
            // "Wat is er nieuw" na een update, of anders — stil — een
            // check of de App Store een nieuwere versie heeft. Nooit
            // allebei tegelijk: net bijgewerkt zijn en al weer achterlopen
            // kan in theorie, maar is geen twee schermen waard.
            .task {
                updateChecker.checkForUpdateNotes()
                if !updateChecker.showWhatsNew {
                    await updateChecker.checkForAvailableUpdate()
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { updateChecker.showWhatsNew },
                set: { if !$0 { updateChecker.dismissWhatsNew() } }
            )) {
                if let highlights = WhatsNewContent.notes[updateChecker.currentVersion] {
                    WhatsNewView(
                        version: updateChecker.currentVersion,
                        highlights: highlights,
                        onDismiss: { updateChecker.dismissWhatsNew() }
                    )
                }
            }
            .sheet(isPresented: Binding(
                get: { updateChecker.updateAvailableVersion != nil },
                set: { if !$0 { updateChecker.dismissUpdateAvailable() } }
            )) {
                if let version = updateChecker.updateAvailableVersion {
                    UpdateAvailableView(
                        version: version,
                        onUpdate: {
                            updateChecker.openAppStore()
                            updateChecker.dismissUpdateAvailable()
                        },
                        onDismiss: { updateChecker.dismissUpdateAvailable() }
                    )
                    .presentationDetents([.medium])
                }
            }
            // Lichte tik-feedback bij elke tabwissel — een kleine, directe
            // microanimatie op het moment dat je "naar een andere pagina gaat",
            // los van de overgang van de pagina-inhoud zelf.
            .onChange(of: nav.selectedTab) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
            }
            // Deeplinks vanuit de widgets:
            // - vliegtuigtas://check?airline=<slug> → checker met maatschappij
            // - vliegtuigtas://pim                  → Purser Pim-gesprek
            .onOpenURL { url in
                guard url.scheme == "vliegtuigtas" else { return }
                if url.host == "pim" {
                    nav.openPimChat()
                    return
                }
                let slug = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "airline" })?.value
                Task { @MainActor in
                    await airlineStore.load()
                    let airline = slug.flatMap { s in
                        airlineStore.airlines.first { $0.slug == s }
                    }
                    nav.openChecker(preselected: airline)
                }
            }
    }

    /// Op iOS 26 krimpt de zwevende Liquid Glass-tabbalk automatisch tijdens
    /// scrollen en klapt hij weer uit bij terugscrollen — puur systeemgedrag,
    /// één modifier, geen eigen implementatie.
    @ViewBuilder
    private var tabView: some View {
        if #available(iOS 26.0, *) {
            baseTabView.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            baseTabView
        }
    }

    /// Vijf tabs, elk met een tekstlabel: alleen icoontjes lieten te veel aan
    /// de fantasie over ("is dat schild nu de checker of de regels?").
    private var baseTabView: some View {
        TabView(selection: $nav.selectedTab) {
            HomeView()
                .tabItem { Label("Start", systemImage: "house.fill") }
                .tag(AppNavigator.Tab.home)

            CheckTab()
                .tabItem { Label("Check", systemImage: "checkmark.shield.fill") }
                .tag(AppNavigator.Tab.check)

            NavigationStack {
                TripsListView()
            }
            .tabItem { Label("Reizen", systemImage: "suitcase.rolling.fill") }
            .tag(AppNavigator.Tab.trips)

            NavigationStack {
                BagsShopView()
            }
            .tabItem { Label("Shop", systemImage: "bag.fill") }
            .tag(AppNavigator.Tab.shop)

            MoreHubView()
                .tabItem { Label("Meer", systemImage: "square.grid.2x2.fill") }
                .tag(AppNavigator.Tab.more)
        }
    }
}

// MARK: - Check-tab

/// De Check-tab: de tas-check zelf is de root, met de maatschappijenlijst als
/// vervolgstap voor wie alleen regels wil opzoeken.
private struct CheckTab: View {
    @EnvironmentObject private var nav: AppNavigator
    @State private var airlineList: UUID?

    var body: some View {
        NavigationStack {
            CheckFlowView(request: nav.checkerRequest)
                .navigationDestination(item: $airlineList) { _ in
                    AirlineListView()
                }
        }
        .onChange(of: nav.airlineListToken) { _, token in
            airlineList = token
        }
    }
}

// MARK: - Meer-hub

/// Eén benoemde hub in plaats van tien sheets achter de Home-feed. Alles wat
/// geen dagelijkse actie is — luchthaveninfo, regels, paspoort, profiel —
/// staat hier als zichtbare tegel met een eigen label.
struct MoreHubView: View {
    @EnvironmentObject private var nav: AppNavigator
    @EnvironmentObject private var airlineStore: AirlineStore
    @State private var pushedBucketList = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(MoreGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: group.title)
                            if group == .travel {
                                // Elk van de drie items hier heeft al zijn eigen
                                // gezicht (foto's, paspoortomslag, Pim's petje),
                                // dus die krijgen geen generieke tegel meer.
                                VStack(spacing: 10) {
                                    BucketListPreviewCard { pushedBucketList = true }
                                    PassportPreviewCard { open(.passport) }
                                    PimPreviewCard { open(.pim) }
                                }
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                                    spacing: 12
                                ) {
                                    ForEach(MoreDestination.allCases.filter { $0.group == group }) { item in
                                        MoreTile(item: item) { open(item) }
                                    }
                                }
                            }
                        }
                    }
                    awardBadge
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Meer")
            // Bucket list is het enige scherm hier dat als push is ontworpen
            // (geen eigen NavigationStack) — de rest opent als sheet, zoals
            // die schermen zelf al gebouwd zijn.
            .navigationDestination(isPresented: $pushedBucketList) {
                BucketListView()
            }
        }
        // Sheets hangen buiten de NavigationStack zodat ze het hele scherm
        // vullen en niet meeschuiven met een push.
        .sheet(item: sheetBinding) { destination in
            sheetContent(for: destination)
        }
        .onChange(of: nav.moreDestination) { _, destination in
            if destination == .bucketList { pushedBucketList = true }
        }
    }

    /// Onderscheiding in de vorm die je bij prijsuitreikingen ziet: lauwertakken
    /// om gecentreerde tekst op een donker vlak. `laurel.leading` en
    /// `laurel.trailing` zijn precies daarvoor bedoeld in SF Symbols.
    ///
    /// Staat bewust onderaan de hub: het mag zichtbaar zijn, maar niet de plek
    /// innemen van iets waar de gebruiker daadwerkelijk heen wil.
    private var awardBadge: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))

                VStack(spacing: 3) {
                    Text("Nederlandse App\nvan de Maand")
                        .font(.frutiger(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("iCulture · 2026")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Image(systemName: "laurel.trailing")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.18, blue: 0.30),
                        Color(red: 0.09, green: 0.10, blue: 0.18)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Bedankt dat je Vliegtuigtas gebruikt.")
                .font(.frutiger(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nederlandse App van de Maand, iCulture 2026")
    }

    /// De bucket list gaat via push, dus die filteren we uit de sheet-binding.
    private var sheetBinding: Binding<MoreDestination?> {
        Binding(
            get: { nav.moreDestination == .bucketList ? nil : nav.moreDestination },
            set: { nav.moreDestination = $0 }
        )
    }

    private func open(_ item: MoreDestination) {
        if item == .bucketList {
            pushedBucketList = true
        } else {
            nav.moreDestination = item
        }
    }

    @ViewBuilder
    private func sheetContent(for destination: MoreDestination) -> some View {
        switch destination {
        case .airports:      AirportSelectionView()
        case .euRules:       EURulesView()
        case .customs:       CustomsInfoView()
        case .baggageIssues: BaggageIssuesView()
        case .guide:         BaggageGuideView()
        case .passport:      TravelPassportView()
        case .pim:
            if #available(iOS 26.0, *) {
                BagageAssistentView(airlines: airlineStore.airlines) { airline in
                    nav.moreDestination = nil
                    nav.openChecker(preselected: airline)
                }
            } else {
                // Pim leunt op Apple Intelligence (iOS 26+); daarvoor is de
                // bagagegids het bruikbare alternatief.
                BaggageGuideView()
            }
        case .profile:       ProfileView()
        case .bucketList:    EmptyView()   // via push, zie navigationDestination
        }
    }
}

/// Tegel in de Meer-hub: geel rond icoon op wit, met titel en één regel
/// uitleg — zodat je zonder tikken weet wat erachter zit.
private struct MoreTile: View {
    let item: MoreDestination
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle().fill(Theme.yellow)
                    Image(systemName: item.icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.frutiger(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(item.subtitle)
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("\(item.title). \(item.subtitle)")
    }
}
