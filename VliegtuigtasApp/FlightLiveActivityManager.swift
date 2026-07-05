import Foundation

#if targetEnvironment(macCatalyst)

/// ActivityKit bestaat niet op Mac Catalyst — no-op stub zodat call sites
/// (app-start, vlucht opslaan, geslaagde check) ongewijzigd blijven.
@MainActor
final class FlightLiveActivityManager {
    static let shared = FlightLiveActivityManager()
    private init() {}
    func sync() {}
    func markBagChecked() {}
}

#else
import ActivityKit

/// Start, actualiseert en beëindigt de vertrek-Live Activity.
///
/// Live Activities mogen maximaal ±8 uur actief zijn, dus we starten pas
/// als het vertrek binnen `startWindow` valt. `sync()` is idempotent en
/// wordt aangeroepen bij app-start en na het opslaan van een vlucht.
@MainActor
final class FlightLiveActivityManager {
    static let shared = FlightLiveActivityManager()
    private init() {}

    /// Vanaf hoeveel uur vóór vertrek de activity mag starten.
    private let startWindow: TimeInterval = 8 * 3600
    /// Hoe lang ná vertrek de activity nog blijft staan ("Goede reis!").
    private let linger: TimeInterval = 30 * 60

    func sync() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let suite = UserDefaults(suiteName: SharedFlightStore.suiteName)
        let number = suite?.string(forKey: "vt_shared_flight_number") ?? ""
        let departureStamp = suite?.double(forKey: "vt_shared_flight_departure") ?? 0
        let departure = departureStamp > 0 ? Date(timeIntervalSince1970: departureStamp) : nil

        let current = Activity<FlightActivityAttributes>.activities.first

        guard !number.isEmpty, let departure, departure.addingTimeInterval(linger) > .now else {
            // Geen (relevante) vlucht meer — ruim een lopende activity op.
            if let current { end(current) }
            return
        }

        guard departure.timeIntervalSinceNow < startWindow else {
            // Vertrek nog te ver weg; niets starten (limiet van het systeem).
            if let current { end(current) }
            return
        }

        let state = FlightActivityAttributes.ContentState(
            departure: departure,
            bagChecked: current?.content.state.bagChecked ?? false
        )
        let staleDate = departure.addingTimeInterval(linger)

        if let current {
            // Zelfde vlucht → update; andere vlucht → vervang.
            if current.attributes.flightNumber == number {
                Task { await current.update(ActivityContent(state: state, staleDate: staleDate)) }
                return
            }
            end(current)
        }

        let attributes = FlightActivityAttributes(
            flightNumber: number,
            airlineName: suite?.string(forKey: "vt_shared_flight_airline"),
            airlineSlug: suite?.string(forKey: "vt_shared_flight_slug"),
            departureIata: suite?.string(forKey: "vt_shared_flight_dep_iata"),
            arrivalIata: suite?.string(forKey: "vt_shared_flight_arr_iata"),
            arrivalAirport: suite?.string(forKey: "vt_shared_flight_arr_name")
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: staleDate)
        )
    }

    /// Aangeroepen na een geslaagde handbagage-check zodat de reminder
    /// op de Live Activity omslaat naar "tas gecheckt".
    func markBagChecked() {
        guard let activity = Activity<FlightActivityAttributes>.activities.first else { return }
        var state = activity.content.state
        state.bagChecked = true
        let staleDate = state.departure.addingTimeInterval(linger)
        Task { await activity.update(ActivityContent(state: state, staleDate: staleDate)) }
    }

    private func end(_ activity: Activity<FlightActivityAttributes>) {
        Task { await activity.end(activity.content, dismissalPolicy: .immediate) }
    }
}
#endif
