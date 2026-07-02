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
    }

    static func saveFlight(number: String, airlineName: String?, airlineSlug: String?, departure: Date) {
        guard let d = defaults else { return }
        d.set(number, forKey: Key.flightNumber)
        d.set(airlineName, forKey: Key.airlineName)
        d.set(airlineSlug, forKey: Key.airlineSlug)
        d.set(departure.timeIntervalSince1970, forKey: Key.departure)
        WidgetCenter.shared.reloadTimelines(ofKind: "VluchtCountdownWidget")
    }

    static func syncFirstName(_ name: String) {
        defaults?.set(name, forKey: Key.firstName)
        WidgetCenter.shared.reloadTimelines(ofKind: "VluchtCountdownWidget")
    }
}

/// Persists user identity in UserDefaults (equivalent of a session cookie).
final class UserSession: ObservableObject {
    static let shared = UserSession()

    @Published private(set) var firstName: String = ""
    @Published private(set) var email: String = ""
    @Published private(set) var isOnboarded: Bool = false

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

        // Sync to API
        APIClient.shared.saveLead(firstName: firstName, email: email)
        APIClient.shared.sendEvent("onboarding_complete", path: "/onboarding")
    }

    /// Stable session ID per install (used for analytics).
    var sessionId: String {
        if let existing = defaults.string(forKey: Key.sessionId) { return existing }
        let new = "ios-\(UUID().uuidString.prefix(8).lowercased())"
        defaults.set(new, forKey: Key.sessionId)
        return new
    }

    /// Sign out / reset (handy for testing).
    func reset() {
        firstName   = ""
        email       = ""
        isOnboarded = false
        [Key.firstName, Key.email, Key.isOnboarded].forEach { defaults.removeObject(forKey: $0) }
    }
}
