import Foundation

/// Rechtstreekse Aviationstack-aanroep die het bestaande backend-endpoint
/// (`APIClient.flightLookup`, dat zelf ook al Aviationstack gebruikt maar
/// maar een smalle set velden doorgeeft) aanvult met rijke data: terminal,
/// gate, vertraging, geplande/verwachte/actuele tijden, vliegtuiginfo en
/// live positie. Puur additief — de maatschappij-matching blijft bij het
/// backend, dat matcht tegen de eigen Airline-catalogus.
enum AviationstackClient {
    private static let accessKey = "04b24744641be29ec0f71dd2d8f45e22"

    struct Endpoint: Decodable {
        let airport: String?
        let terminal: String?
        let gate: String?
        let delay: Int?
        let scheduled: String?
        let estimated: String?
        let actual: String?
        let baggage: String?
    }

    struct Aircraft: Decodable {
        let registration: String?
        let icao24: String?
    }

    struct Live: Decodable {
        let latitude: Double?
        let longitude: Double?
        let altitude: Double?
        let direction: Double?
        let speedHorizontal: Double?
        let isGround: Bool?
    }

    struct AviationstackFlight: Decodable {
        let flightDate: String?
        let flightStatus: String?
        let departure: Endpoint?
        let arrival: Endpoint?
        let aircraft: Aircraft?
        let live: Live?
    }

    private struct SearchResponse: Decodable {
        let data: [AviationstackFlight]
    }

    private static let isoFormatter = ISO8601DateFormatter()

    /// Aviationstack geeft vaak meerdere resultaten terug voor hetzelfde
    /// herhalende vluchtnummer (bijv. vandaag én gisteren) — kies het
    /// resultaat waarvan flight_date het dichtst bij de al bekende
    /// vertrekdatum ligt, niet zomaar het eerste.
    static func lookup(iata: String, near date: Date) async -> AviationstackFlight? {
        let trimmed = iata.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !accessKey.isEmpty else { return nil }

        var components = URLComponents(string: "https://api.aviationstack.com/v1/flights")
        components?.queryItems = [
            URLQueryItem(name: "access_key", value: accessKey),
            URLQueryItem(name: "flight_iata", value: trimmed),
        ]
        guard let url = components?.url else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? decoder.decode(SearchResponse.self, from: data),
              !decoded.data.isEmpty
        else { return nil }

        let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }()

        return decoded.data.min { lhs, rhs in
            let lhsDate = lhs.flightDate.flatMap(dayFormatter.date(from:)) ?? .distantPast
            let rhsDate = rhs.flightDate.flatMap(dayFormatter.date(from:)) ?? .distantPast
            return abs(lhsDate.timeIntervalSince(date)) < abs(rhsDate.timeIntervalSince(date))
        }
    }

    static func date(from iso: String?) -> Date? {
        guard let iso else { return nil }
        return isoFormatter.date(from: iso)
    }
}
