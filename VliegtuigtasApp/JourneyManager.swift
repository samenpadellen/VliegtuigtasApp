import SwiftUI

/// Customer-journey-motor: houdt bij waar de gebruiker in zijn reis zit
/// (activatie-mijlpalen) en stuurt de "aan de slag"-gids, het aha-moment na
/// de eerste geslaagde check, en de "volgende beste actie" op Home aan.
///
/// De mijlpalen worden afgeleid uit bestaande stores + één teller die al
/// bestond (`vt_successful_checks`, van ReviewPrompter) — geen dubbele
/// bookkeeping. `version` wordt opgehoogd na acties die niet vanzelf
/// observeerbaar zijn (zoals een geslaagde check), zodat Home hertekent.
@MainActor
final class JourneyManager: ObservableObject {
    static let shared = JourneyManager()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let successfulChecks = "vt_successful_checks"   // gedeeld met ReviewPrompter
        static let celebratedFirstCheck = "vt_celebrated_first_check"
        static let dismissedGettingStarted = "vt_dismissed_getting_started"
    }

    /// Toont de eenmalige viering na de allereerste geslaagde tas-check.
    @Published var showFirstCheckCelebration = false
    /// Ophogen dwingt observers (Home) tot hertekenen na een niet-observeerbare
    /// wijziging (bijv. een geslaagde check die alleen UserDefaults raakt).
    @Published private(set) var version = 0

    private init() {}

    func bump() { version += 1 }

    // MARK: - Mijlpalen

    var hasBag: Bool { !BagCollectionStore.shared.bags.isEmpty }
    var hasCheckedBag: Bool { successfulChecks > 0 }
    var hasFlight: Bool { !FlightsStore.shared.flights.isEmpty }
    var hasTrip: Bool { !TripsStore.shared.trips.isEmpty }

    /// Aantal geslaagde tas-checks — ook als statistiek op Home.
    var successfulChecks: Int { defaults.integer(forKey: Key.successfulChecks) }

    var completedSteps: Int { [hasBag, hasCheckedBag, hasFlight, hasTrip].filter { $0 }.count }
    var totalSteps: Int { 4 }
    var isFullyActivated: Bool { completedSteps >= totalSteps }

    // MARK: - Aan de slag-gids

    private var gettingStartedDismissed: Bool { defaults.bool(forKey: Key.dismissedGettingStarted) }

    /// Toon de gids zolang de gebruiker nog niet alle mijlpalen heeft én 'm
    /// niet zelf heeft weggeklikt.
    var showGettingStarted: Bool { !isFullyActivated && !gettingStartedDismissed }

    func dismissGettingStarted() {
        defaults.set(true, forKey: Key.dismissedGettingStarted)
        bump()
    }

    // MARK: - Aha-moment

    /// Roep aan direct nadat een tas is geslaagd (past). De allereerste keer
    /// triggert dit de viering; daarna nooit meer.
    func registerSuccessfulCheck() {
        if !defaults.bool(forKey: Key.celebratedFirstCheck) {
            defaults.set(true, forKey: Key.celebratedFirstCheck)
            showFirstCheckCelebration = true
            // Het aha-moment is hét moment om om zichtbare meldingen te vragen:
            // de app heeft zich net bewezen, en pas hierna heeft de gebruiker
            // iets aan een seintje over zijn gate of vertraging.
            NotificationPlanner.promoteToVisibleNotifications()
        }
        bump()
    }
}
