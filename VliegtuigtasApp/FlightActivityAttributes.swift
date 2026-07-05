// ActivityKit bestaat niet op Mac Catalyst; de Live Activity is daar
// simpelweg afwezig (de countdown-widget blijft wel werken).
#if !targetEnvironment(macCatalyst)
import Foundation
import ActivityKit

/// Gedeeld tussen app en widget-extensie: de Live Activity voor de
/// vertrek-aftelling met tas-reminder.
struct FlightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Vertrektijd — in de state (niet in de attributes) zodat een
        /// gewijzigde vertrektijd zonder herstart bijgewerkt kan worden.
        var departure: Date
        /// Heeft de gebruiker de handbagage-check gedaan sinds het opslaan?
        var bagChecked: Bool
    }

    let flightNumber: String
    let airlineName: String?
    let airlineSlug: String?
    var departureIata: String? = nil
    var arrivalIata: String? = nil
    var arrivalAirport: String? = nil

    /// "AMS → LHR", of nil als de route onbekend is.
    var routeLabel: String? {
        guard let departureIata, let arrivalIata else { return nil }
        return "\(departureIata) → \(arrivalIata)"
    }

    var deepLink: URL? {
        guard let airlineSlug else { return URL(string: "vliegtuigtas://check") }
        return URL(string: "vliegtuigtas://check?airline=\(airlineSlug)")
    }
}
#endif
