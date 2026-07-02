import SwiftUI

@MainActor
final class AirlineStore: ObservableObject {
    @Published var airlines: [Airline] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        guard airlines.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            airlines = try await APIClient.shared.airlines()
        } catch {
            self.error = error.localizedDescription
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
        isLoading = true
        bags = (try? await APIClient.shared.bags()) ?? []
        isLoading = false
    }

    func reload() async {
        isLoading = true
        bags = (try? await APIClient.shared.bags()) ?? []
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
