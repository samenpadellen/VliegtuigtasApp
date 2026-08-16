import SwiftUI

@MainActor
final class AirlineStore: ObservableObject {
    @Published var airlines: [Airline] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        guard airlines.isEmpty else { return }
        await fetch(forceRefresh: false)
    }

    /// Voor pull-to-refresh: haalt altijd verse data op — ook als de
    /// catalogus al gevuld was en ook binnen de cache-TTL van `APIClient` —
    /// anders lijkt "verversen" iets te doen zonder ooit echt een nieuwe
    /// call te maken. `fetch()` wijzigt `airlines` alleen bij succes, dus
    /// een mislukte refresh klapt het scherm niet leeg.
    func reload() async {
        await fetch(forceRefresh: true)
    }

    private func fetch(forceRefresh: Bool) async {
        // Instant: laatste catalogus van schijf zodat de UI direct vult
        // (ook offline); het netwerk ververst er stil achteraan.
        if airlines.isEmpty, let cached = APIClient.shared.airlinesFromDisk(), !cached.isEmpty {
            airlines = cached
        }
        isLoading = airlines.isEmpty
        error = nil
        do {
            airlines = try await APIClient.shared.airlines(forceRefresh: forceRefresh)
            // Niet in de App Clip of de iMessage-extensie: die bevatten geen App Intents-laag.
            #if os(iOS) && !APPCLIP && !MESSAGES_EXTENSION
            // Spotlight-index + Siri-zinnen met maatschappijnamen bijwerken.
            IntentDonations.airlinesLoaded(airlines)
            #endif
        } catch {
            // Met een gevulde cache is een mislukte refresh geen fout voor de UI.
            if airlines.isEmpty { self.error = error.localizedDescription }
        }
        isLoading = false
    }
}

@MainActor
final class CheckStore: ObservableObject {
    @Published var result: CheckResponse?
    @Published var isChecking = false
    @Published var error: String?

    func check(
        airlineSlug: String,
        length: Double, width: Double, depth: Double, weight: Double,
        email: String? = nil, firstName: String? = nil
    ) async {
        isChecking = true
        error = nil
        result = nil
        do {
            result = try await APIClient.shared.check(
                airlineSlug: airlineSlug,
                length: length, width: width, depth: depth, weight: weight,
                email: email, firstName: firstName
            )
            APIClient.shared.sendEvent("bag_check", path: "/check")
            #if os(iOS) && !APPCLIP && !MESSAGES_EXTENSION
            if result?.status == "fit" {
                FlightLiveActivityManager.shared.markBagChecked()
            }
            #endif
        } catch {
            self.error = error.localizedDescription
        }
        isChecking = false
    }
}

/// Gedeelde, ongefilterde tassencatalogus. Wordt als environment object één keer
/// geladen en hergebruikt door Home én de Shop-tab, zodat tabwisselen instant
/// aanvoelt in plaats van telkens opnieuw dezelfde data op te vragen.
@MainActor
final class BagStore: ObservableObject {
    @Published var bags: [Bag] = []
    @Published var isLoading = false

    func loadIfNeeded() async {
        guard bags.isEmpty else { return }
        await fetch(forceRefresh: false)
    }

    /// Voor pull-to-refresh: haalt altijd verse data op — ook binnen de
    /// cache-TTL van `APIClient`. Bij een mislukte fetch behouden we de
    /// bestaande producten i.p.v. het scherm leeg te maken.
    func reload() async {
        await fetch(forceRefresh: true)
    }

    private func fetch(forceRefresh: Bool) async {
        // Instant van schijf; netwerk ververst erna.
        if bags.isEmpty, let cached = APIClient.shared.bagsFromDisk(), !cached.isEmpty {
            bags = cached
        }
        isLoading = bags.isEmpty
        if let fresh = try? await APIClient.shared.bags(forceRefresh: forceRefresh) {
            bags = fresh
        }
        isLoading = false
    }
}

@MainActor
final class FlightStore: ObservableObject {
    @Published var result: FlightLookupResponse?
    @Published var isLoading = false
    @Published var error: String?

    func lookup(_ number: String) async {
        isLoading = true
        error = nil
        result = nil
        do {
            result = try await APIClient.shared.flightLookup(number: number)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
