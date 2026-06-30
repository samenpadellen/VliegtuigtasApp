import Foundation

// MARK: - Airline

struct Airline: Identifiable, Codable, Hashable {
    let id: String
    let slug: String
    let name: String
    let logoUrl: String?
    let logoUrlSmall: String?
    let domain: String?
    let extraNotes: String?
    let sourceUrl: String?
    let lastVerifiedDate: String?
    let sortOrder: Int?
    let personalItemLCm: Double?
    let personalItemWCm: Double?
    let personalItemDCm: Double?
    let variants: [AirlineVariant]?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, variants, domain
        case logoUrl          = "logo_url"
        case logoUrlSmall     = "logo_url_small"
        case extraNotes       = "extra_notes"
        case sourceUrl        = "source_url"
        case lastVerifiedDate = "last_verified_date"
        case sortOrder        = "sort_order"
        case personalItemLCm  = "personal_item_l_cm"
        case personalItemWCm  = "personal_item_w_cm"
        case personalItemDCm  = "personal_item_d_cm"
    }

    /// Best logo URL: prefer small (list views), fall back to full
    var bestLogoUrl: String? { logoUrlSmall ?? logoUrl }
}

// MARK: - Airline Variant

struct AirlineVariant: Identifiable, Codable, Hashable {
    let id: String
    let variantName: String
    let includesLargeBag: Bool?
    let smallLCm: Double?
    let smallWCm: Double?
    let smallDCm: Double?
    let largeLCm: Double?
    let largeWCm: Double?
    let largeDCm: Double?
    let maxWeightKg: Double?
    let weightRule: String?
    let wheelMarginCm: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case variantName      = "variant_name"
        case includesLargeBag = "includes_large_bag"
        case smallLCm         = "small_l_cm"
        case smallWCm         = "small_w_cm"
        case smallDCm         = "small_d_cm"
        case largeLCm         = "large_l_cm"
        case largeWCm         = "large_w_cm"
        case largeDCm         = "large_d_cm"
        case maxWeightKg      = "max_weight_kg"
        case weightRule       = "weight_rule"
        case wheelMarginCm    = "wheel_margin_cm"
    }

    var smallDimString: String {
        dims(smallLCm, smallWCm, smallDCm)
    }

    var largeDimString: String {
        dims(largeLCm, largeWCm, largeDCm)
    }

    private func dims(_ l: Double?, _ w: Double?, _ d: Double?) -> String {
        let parts = [l, w, d].compactMap { $0.map { "\(Int($0))" } }
        return parts.isEmpty ? "–" : parts.joined(separator: " × ") + " cm"
    }
}

// MARK: - Bag (affiliate product)

struct Bag: Identifiable, Codable {
    let id: String
    let name: String
    let brand: String?
    let imageUrl: String?
    let price: Double?
    let currency: String?
    let affiliateUrl: String?
    let category: String?
    let length: Double?
    let width: Double?
    let depth: Double?
    let weight: Double?
    let shopLogoUrl: String?
    let shopDomain: String?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, price, currency, category, length, width, depth, weight
        case imageUrl     = "image_url"
        case affiliateUrl = "affiliate_url"
        case shopLogoUrl  = "shop_logo_url"
        case shopDomain   = "shop_domain"
    }
}

// MARK: - Check

struct CheckRequest: Encodable {
    let airlineSlug: String
    let lengthCm: Double
    let widthCm: Double
    let depthCm: Double
    let weightKg: Double
    let email: String?
    let firstName: String?
    let source: String = "ios"

    enum CodingKeys: String, CodingKey {
        case airlineSlug = "airline_slug"
        case lengthCm    = "length_cm"
        case widthCm     = "width_cm"
        case depthCm     = "depth_cm"
        case weightKg    = "weight_kg"
        case email
        case firstName   = "first_name"
        case source
    }
}

struct CheckResponse: Decodable, Equatable {
    let status: String      // "fit" | "too_large" | "too_heavy" | "no_match"
    let target: String?     // "large" | "small" | nil
    let reasons: [String]?
    let variant: CheckVariant?
    let airline: CheckAirline?

    var verdict: Verdict {
        switch status {
        case "fit":     return .ok
        case "no_match": return .warning
        default:        return .fail
        }
    }

    var verdictTitle: String {
        switch status {
        case "fit":        return "Je tas past!"
        case "too_large":  return "Helaas, te groot"
        case "too_heavy":  return "Helaas, te zwaar"
        case "no_match":   return "Helaas, geen match"
        default:           return "Helaas"
        }
    }

    var verdictMessage: String {
        switch status {
        case "fit":
            if target == "large" { return "Past als grote handbagage (cabin bag)." }
            if target == "small" { return "Past als klein persoonlijk item (onder de stoel)." }
            return "Past als handbagage."
        case "too_large":  return "De afmetingen overschrijden de toegestane maten."
        case "too_heavy":  return "Het gewicht is te hoog voor dit ticket type."
        case "no_match":   return "Geen passende variant gevonden voor deze maten."
        default:           return ""
        }
    }
}

struct CheckVariant: Decodable, Equatable {
    let id: String?
    let name: String?
    let includesLargeBag: Bool?
    let maxWeightKg: Double?

    enum CodingKeys: String, CodingKey {
        case id, name
        case includesLargeBag = "includes_large_bag"
        case maxWeightKg      = "max_weight_kg"
    }
}

struct CheckAirline: Decodable, Equatable {
    let slug: String?
    let name: String?
    let logoUrl: String?

    enum CodingKeys: String, CodingKey {
        case slug, name
        case logoUrl = "logo_url"
    }
}

// MARK: - Flight lookup

struct FlightLookupResponse: Decodable {
    /// Raw Aviationstack airline info — may lack id/slug
    let rawAirline: RawFlightAirline?
    let flightNumber: String?
    let airlineLogoUrl: String?
    /// Full matched Airline from our database (has id, slug, variants)
    let matchedAirline: Airline?

    enum CodingKeys: String, CodingKey {
        case rawAirline     = "airline"
        case flightNumber   = "flight_number"
        case airlineLogoUrl = "airline_logo_url"
        case matchedAirline = "matched_airline"
    }

    /// Best resolved airline — matched_airline has full data incl. variants
    var resolvedAirline: Airline? { matchedAirline }

    /// Display name when matched_airline is nil
    var rawAirlineName: String? { rawAirline?.name }
}

/// Lightweight airline from Aviationstack — only name is guaranteed
struct RawFlightAirline: Decodable {
    let name: String?
    let iataCode: String?

    enum CodingKeys: String, CodingKey {
        case name
        case iataCode = "iata_code"
    }
}

// MARK: - Lead

struct LeadRequest: Encodable {
    let firstName: String
    let email: String
    let airlineSlug: String?
    let source: String = "ios"

    enum CodingKeys: String, CodingKey {
        case firstName   = "first_name"
        case email
        case airlineSlug = "airline_slug"
        case source
    }
}

// MARK: - Event

struct EventRequest: Encodable {
    let eventType: String
    let path: String?
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case path
        case sessionId = "session_id"
    }
}

// MARK: - API wrapper

struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let error: String?
}

// MARK: - Verdict

enum Verdict { case ok, warning, fail }
