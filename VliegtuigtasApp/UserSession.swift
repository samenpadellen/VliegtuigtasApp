import Foundation
import Combine

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
    }

    /// Called when the user completes onboarding.
    func completeOnboarding(firstName: String, email: String) {
        self.firstName   = firstName
        self.email       = email
        self.isOnboarded = true

        defaults.set(firstName,  forKey: Key.firstName)
        defaults.set(email,      forKey: Key.email)
        defaults.set(true,       forKey: Key.isOnboarded)

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
