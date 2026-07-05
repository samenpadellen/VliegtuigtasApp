import Foundation
import Combine
import WidgetKit

/// Deelt de opgeslagen vlucht en voornaam met de widgets via de App Group,
/// zodat de vlucht-aftelwidget buiten het app-proces bij deze data kan.
enum SharedFlightStore {
    static let suiteName = "group.com.vliegtuigtas.app"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    private enum Key {
        static let flightNumber = "vt_shared_flight_number"
        static let airlineName  = "vt_shared_flight_airline"
        static let airlineSlug  = "vt_shared_flight_slug"
        static let departure    = "vt_shared_flight_departure"
        static let firstName    = "vt_shared_first_name"
        static let depIata      = "vt_shared_flight_dep_iata"
        static let depName      = "vt_shared_flight_dep_name"
        static let arrIata      = "vt_shared_flight_arr_iata"
        static let arrName      = "vt_shared_flight_arr_name"
    }

    /// Alle sleutels van één opgeslagen vlucht (voor wissen/adopteren).
    fileprivate static var flightKeys: [String] {
        [Key.flightNumber, Key.airlineName, Key.airlineSlug, Key.departure,
         Key.depIata, Key.depName, Key.arrIata, Key.arrName]
    }

    /// Route-informatie van de flight-lookup (vertrek/aankomst) reist mee
    /// zodat widget, Live Activity, watch en Siri een rijkere vlucht tonen.
    struct Route {
        var departureIata: String?
        var departureAirport: String?
        var arrivalIata: String?
        var arrivalAirport: String?

        var isEmpty: Bool { departureIata == nil && arrivalIata == nil }
    }

    static func saveFlight(
        number: String, airlineName: String?, airlineSlug: String?,
        departure: Date, route: Route = Route()
    ) {
        writeFlightLocally(number: number, airlineName: airlineName, airlineSlug: airlineSlug, departure: departure, route: route)
        // Mee naar iCloud: dezelfde vlucht verschijnt ook op je andere toestellen.
        CloudSync.shared.pushFlight(
            number: number, airlineName: airlineName,
            airlineSlug: airlineSlug, departure: departure, route: route
        )
        // Reminders rond het vertrek (1 week / 24 uur / 3 uur vooraf).
        NotificationPlanner.scheduleFlightReminders(departure: departure, label: number)
    }

    /// Vanuit iCloud overgenomen — alleen lokaal schrijven, niet terugpushen.
    static func adoptFlight(
        number: String, airlineName: String?, airlineSlug: String?,
        departure: Date, route: Route = Route()
    ) {
        writeFlightLocally(number: number, airlineName: airlineName, airlineSlug: airlineSlug, departure: departure, route: route)
    }

    static func adoptClearedFlight() {
        clearFlightLocally()
    }

    private static func writeFlightLocally(
        number: String, airlineName: String?, airlineSlug: String?,
        departure: Date, route: Route
    ) {
        guard let d = defaults else { return }
        d.set(number, forKey: Key.flightNumber)
        d.set(airlineName, forKey: Key.airlineName)
        d.set(airlineSlug, forKey: Key.airlineSlug)
        d.set(departure.timeIntervalSince1970, forKey: Key.departure)
        d.set(route.departureIata, forKey: Key.depIata)
        d.set(route.departureAirport, forKey: Key.depName)
        d.set(route.arrivalIata, forKey: Key.arrIata)
        d.set(route.arrivalAirport, forKey: Key.arrName)
        WidgetCenter.shared.reloadTimelines(ofKind: "VluchtCountdownWidget")
    }

    private static func clearFlightLocally() {
        guard let d = defaults else { return }
        flightKeys.forEach { d.removeObject(forKey: $0) }
        WidgetCenter.shared.reloadTimelines(ofKind: "VluchtCountdownWidget")
    }

    static func syncFirstName(_ name: String) {
        defaults?.set(name, forKey: Key.firstName)
        WidgetCenter.shared.reloadTimelines(ofKind: "VluchtCountdownWidget")
    }

    struct SavedFlight {
        let number: String
        let airlineName: String?
        let airlineSlug: String?
        let departure: Date
        let route: Route

        /// "AMS → LHR", of nil als de route onbekend is.
        var routeLabel: String? {
            guard let dep = route.departureIata, let arr = route.arrivalIata else { return nil }
            return "\(dep) → \(arr)"
        }
    }

    /// Verwijdert de opgeslagen vlucht overal: App Group, widget, iCloud.
    static func clearFlight() {
        clearFlightLocally()
        CloudSync.shared.pushClearedFlight()
    }

    /// Leest de opgeslagen vlucht terug (gebruikt door de "Mijn vlucht"-intent).
    static func loadFlight() -> SavedFlight? {
        guard let d = defaults,
              let number = d.string(forKey: Key.flightNumber) else { return nil }
        let interval = d.double(forKey: Key.departure)
        guard interval > 0 else { return nil }
        return SavedFlight(
            number: number,
            airlineName: d.string(forKey: Key.airlineName),
            airlineSlug: d.string(forKey: Key.airlineSlug),
            departure: Date(timeIntervalSince1970: interval),
            route: Route(
                departureIata: d.string(forKey: Key.depIata),
                departureAirport: d.string(forKey: Key.depName),
                arrivalIata: d.string(forKey: Key.arrIata),
                arrivalAirport: d.string(forKey: Key.arrName)
            )
        )
    }
}

/// Persists user identity in UserDefaults (equivalent of a session cookie).
final class UserSession: ObservableObject {
    static let shared = UserSession()

    @Published private(set) var firstName: String = ""
    @Published private(set) var email: String = ""
    @Published private(set) var isOnboarded: Bool = false

    /// Accountgebonden features (vluchtopslag, reminders, Purser Pim) vereisen
    /// een profiel: die data wordt aan het profiel gekoppeld, via iCloud
    /// gesynct en bij accountverwijdering gewist. De bagagecheck zelf blijft
    /// altijd vrij toegankelijk (App Review 5.1.1).
    var hasAccount: Bool { isOnboarded && !email.isEmpty }

    private let defaults = UserDefaults.standard
    private enum Key {
        static let firstName  = "vt_first_name"
        static let email      = "vt_email"
        static let isOnboarded = "vt_onboarded"
        static let sessionId  = "vt_session_id"
    }

    private init() {
        firstName   = defaults.string(forKey: Key.firstName) ?? ""
        email       = defaults.string(forKey: Key.email) ?? ""
        isOnboarded = defaults.bool(forKey: Key.isOnboarded)
        SharedFlightStore.syncFirstName(firstName)
    }

    /// Called when the user completes onboarding.
    func completeOnboarding(firstName: String, email: String) {
        self.firstName   = firstName
        self.email       = email
        self.isOnboarded = true

        defaults.set(firstName,  forKey: Key.firstName)
        defaults.set(email,      forKey: Key.email)
        defaults.set(true,       forKey: Key.isOnboarded)
        SharedFlightStore.syncFirstName(firstName)
        CloudSync.shared.pushUser(firstName: firstName, email: email, onboarded: true)

        // Sync to API
        APIClient.shared.saveLead(firstName: firstName, email: email)
        APIClient.shared.sendEvent("onboarding_complete", path: "/onboarding")
    }

    /// Doorgaan zonder gegevens: de volledige app werkt zonder account
    /// (App Review 5.1.1(v)). Geen lead naar de API.
    func completeWithoutAccount() {
        isOnboarded = true
        defaults.set(true, forKey: Key.isOnboarded)
        CloudSync.shared.pushUser(firstName: "", email: "", onboarded: true)
        APIClient.shared.sendEvent("onboarding_skipped", path: "/onboarding")
    }

    /// Overgenomen van een ander apparaat via iCloud: geen nieuwe onboarding
    /// en géén nieuwe lead/event naar de API (dat is al eens gebeurd).
    func adoptFromCloud(firstName: String, email: String) {
        self.firstName   = firstName
        self.email       = email
        self.isOnboarded = true
        defaults.set(firstName, forKey: Key.firstName)
        defaults.set(email,     forKey: Key.email)
        defaults.set(true,      forKey: Key.isOnboarded)
        SharedFlightStore.syncFirstName(firstName)
    }

    /// Op een ander apparaat uitgelogd — hier lokaal ook, zonder terug te
    /// schrijven naar iCloud (dat deed het andere apparaat al).
    func adoptLogout() {
        firstName   = ""
        email       = ""
        isOnboarded = false
        [Key.firstName, Key.email, Key.isOnboarded].forEach { defaults.removeObject(forKey: $0) }
    }

    /// Stable session ID per install (used for analytics).
    var sessionId: String {
        if let existing = defaults.string(forKey: Key.sessionId) { return existing }
        let new = "ios-\(UUID().uuidString.prefix(8).lowercased())"
        defaults.set(new, forKey: Key.sessionId)
        return new
    }

    /// Sign out / reset.
    func reset() {
        firstName   = ""
        email       = ""
        isOnboarded = false
        [Key.firstName, Key.email, Key.isOnboarded].forEach { defaults.removeObject(forKey: $0) }
        CloudSync.shared.clearUser()
    }
}
