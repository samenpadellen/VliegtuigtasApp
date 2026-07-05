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

@MainActor
final class AppNavigator: ObservableObject {
    enum Tab: Hashable {
        case home, checker, airlines, shop
    }

    @Published var selectedTab: Tab = .home
    @Published var checkerRequest: CheckerRequest?
    @Published var shopRequest: ShopRequest?
    /// Token in plaats van Bool: verandert bij élke aanroep, ook als Home
    /// al vooraan stond, zodat de widget-deeplink altijd het gesprek opent.
    @Published var openPimChatToken: UUID?

    func openChecker(preselected airline: Airline?) {
        checkerRequest = CheckerRequest(airline: airline, token: UUID())
        selectedTab = .checker
    }

    func openAirlines() {
        selectedTab = .airlines
    }

    func openShop(airlineSlug: String? = nil) {
        if let airlineSlug {
            shopRequest = ShopRequest(airlineSlug: airlineSlug, token: UUID())
        }
        selectedTab = .shop
    }

    /// Vanuit de Purser Pim-widget: naar Home en het gesprek openen.
    func openPimChat() {
        selectedTab = .home
        openPimChatToken = UUID()
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

    var body: some View {
        tabView
            .tint(Theme.navy)
            .environmentObject(nav)
            .environmentObject(airlineStore)
            .environmentObject(bagStore)
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

    private var baseTabView: some View {
        TabView(selection: $nav.selectedTab) {
            HomeView()
                .tabItem { Image(systemName: "house.fill") }
                .tag(AppNavigator.Tab.home)

            NavigationStack {
                CheckFlowView(request: nav.checkerRequest)
            }
            .tabItem { Image(systemName: "checkmark.shield.fill") }
            .tag(AppNavigator.Tab.checker)

            NavigationStack {
                AirlineListView()
            }
            .tabItem { Image(systemName: "airplane") }
            .tag(AppNavigator.Tab.airlines)

            NavigationStack {
                BagsShopView()
            }
            .tabItem { Image(systemName: "bag.fill") }
            .tag(AppNavigator.Tab.shop)
        }
    }
}
