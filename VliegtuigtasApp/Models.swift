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
    let countryCode: String?
    let flagEmoji: String?
    let flagImageUrl: String?
    // v1.2 verrijkte velden
    let continent: String?
    let alliance: String?
    let airlineType: String?
    let headquarters: String?
    let websiteUrl: String?
    let bookingUrl: String?
    let customerServiceUrl: String?
    let baggagePolicyUrl: String?
    let checkedBagIncluded: Bool?
    let checkedBagMaxWeightKg: Double?
    let checkedBagMaxLCm: Double?
    let checkedBagMaxWCm: Double?
    let checkedBagMaxDCm: Double?
    let checkedBagPriceFromEur: Double?
    let overweightFeePerKgEur: Double?
    let oversizeFeeEur: Double?
    let priorityBoardingPriceEur: Double?
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, variants, domain, continent, alliance, headquarters, currency
        case logoUrl                  = "logo_url"
        case logoUrlSmall             = "logo_url_small"
        case extraNotes               = "extra_notes"
        case sourceUrl                = "source_url"
        case lastVerifiedDate         = "last_verified_date"
        case sortOrder                = "sort_order"
        case personalItemLCm          = "personal_item_l_cm"
        case personalItemWCm          = "personal_item_w_cm"
        case personalItemDCm          = "personal_item_d_cm"
        case countryCode              = "country_code"
        case flagEmoji                = "flag_emoji"
        case flagImageUrl             = "flag_image_url"
        case airlineType              = "airline_type"
        case websiteUrl               = "website_url"
        case bookingUrl               = "booking_url"
        case customerServiceUrl       = "customer_service_url"
        case baggagePolicyUrl         = "baggage_policy_url"
        case checkedBagIncluded       = "checked_bag_included"
        case checkedBagMaxWeightKg    = "checked_bag_max_weight_kg"
        case checkedBagMaxLCm         = "checked_bag_max_l_cm"
        case checkedBagMaxWCm         = "checked_bag_max_w_cm"
        case checkedBagMaxDCm         = "checked_bag_max_d_cm"
        case checkedBagPriceFromEur   = "checked_bag_price_from_eur"
        case overweightFeePerKgEur    = "overweight_fee_per_kg_eur"
        case oversizeFeeEur           = "oversize_fee_eur"
        case priorityBoardingPriceEur = "priority_boarding_price_eur"
    }

    var bestLogoUrl: String? { logoUrlSmall ?? logoUrl }
}

// MARK: - Airline Variant

struct AirlineVariant: Identifiable, Codable, Hashable {
    let id: String
    let airlineId: String?
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
    // v1.2 verrijkte velden
    let priceIndicationEur: Double?
    let includesCheckedBag: Bool?
    let checkedBagCount: Int?
    let checkedBagWeightKg: Double?
    let checkedBagPriceEur: Double?
    let seatSelectionIncluded: Bool?
    let priorityBoarding: Bool?
    let changesAllowed: Bool?
    let refundable: Bool?
    let perks: String?

    enum CodingKeys: String, CodingKey {
        case id, notes, perks, refundable
        case airlineId             = "airline_id"
        case variantName           = "variant_name"
        case includesLargeBag      = "includes_large_bag"
        case smallLCm              = "small_l_cm"
        case smallWCm              = "small_w_cm"
        case smallDCm              = "small_d_cm"
        case largeLCm              = "large_l_cm"
        case largeWCm              = "large_w_cm"
        case largeDCm              = "large_d_cm"
        case maxWeightKg           = "max_weight_kg"
        case weightRule            = "weight_rule"
        case wheelMarginCm         = "wheel_margin_cm"
        case priceIndicationEur    = "price_indication_eur"
        case includesCheckedBag    = "includes_checked_bag"
        case checkedBagCount       = "checked_bag_count"
        case checkedBagWeightKg    = "checked_bag_weight_kg"
        case checkedBagPriceEur    = "checked_bag_price_eur"
        case seatSelectionIncluded = "seat_selection_included"
        case priorityBoarding      = "priority_boarding"
        case changesAllowed        = "changes_allowed"
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

struct Bag: Identifiable, Decodable {
    let id: String
    let name: String
    let brand: String?
    let imageUrl: String?
    let affiliateUrl: String?
    let category: String?
    let type: String?
    let length: Double?
    let width: Double?
    let depth: Double?
    let weight: Double?
    let colors: [String]?
    let airlineSlugs: [String]?
    let shopName: String?
    let shopLogoUrl: String?
    let shopDomain: String?
    let featured: Bool?
    let editorRank: Int?
    let editorNote: String?
    // Afgeleide velden
    let dimensionsLabel: String?
    let volumeLiters: Double?
    let totalDimensionsCm: Double?
    let detailUrl: String?
    let apiDetailUrl: String?
    let priceEur: Double?
    let priceCurrency: String?
    let priceLabel: String?
    let matchedAirlines: [Airline]?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, category, type, colors, featured
        case imageUrl          = "image_url"
        case affiliateUrl      = "affiliate_url"
        case lengthCm          = "length_cm"
        case widthCm           = "width_cm"
        case depthCm           = "depth_cm"
        case weightKg          = "weight_kg"
        case airlineSlugs      = "airline_slugs"
        case shopName          = "shop_name"
        case shopLogoUrl       = "shop_logo_url"
        case shopDomain        = "shop_domain"
        case editorRank        = "editor_rank"
        case editorNote        = "editor_note"
        case dimensionsLabel   = "dimensions_label"
        case volumeLiters      = "volume_liters"
        case totalDimensionsCm = "total_dimensions_cm"
        case detailUrl         = "detail_url"
        case apiDetailUrl      = "api_detail_url"
        case priceEur          = "price_eur"
        case priceCurrency     = "price_currency"
        case priceLabel        = "price_label"
        case matchedAirlines   = "matched_airlines"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        affiliateUrl = try c.decodeIfPresent(String.self, forKey: .affiliateUrl)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        length = try c.decodeIfPresent(Double.self, forKey: .lengthCm)
        width = try c.decodeIfPresent(Double.self, forKey: .widthCm)
        depth = try c.decodeIfPresent(Double.self, forKey: .depthCm)
        weight = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        colors = try c.decodeIfPresent([String].self, forKey: .colors)
        airlineSlugs = try c.decodeIfPresent([String].self, forKey: .airlineSlugs)
        shopName = try c.decodeIfPresent(String.self, forKey: .shopName)
        shopLogoUrl = try c.decodeIfPresent(String.self, forKey: .shopLogoUrl)
        shopDomain = try c.decodeIfPresent(String.self, forKey: .shopDomain)
        featured = try c.decodeIfPresent(Bool.self, forKey: .featured)
        editorRank = try c.decodeIfPresent(Int.self, forKey: .editorRank)
        editorNote = try c.decodeIfPresent(String.self, forKey: .editorNote)
        dimensionsLabel = try c.decodeIfPresent(String.self, forKey: .dimensionsLabel)
        volumeLiters = try c.decodeIfPresent(Double.self, forKey: .volumeLiters)
        totalDimensionsCm = try c.decodeIfPresent(Double.self, forKey: .totalDimensionsCm)
        detailUrl = try c.decodeIfPresent(String.self, forKey: .detailUrl)
        apiDetailUrl = try c.decodeIfPresent(String.self, forKey: .apiDetailUrl)
        priceEur = try c.decodeIfPresent(Double.self, forKey: .priceEur)
        priceCurrency = try c.decodeIfPresent(String.self, forKey: .priceCurrency)
        priceLabel = try c.decodeIfPresent(String.self, forKey: .priceLabel)
        matchedAirlines = try c.decodeIfPresent([Airline].self, forKey: .matchedAirlines)
    }

    var displayPrice: String? { priceLabel ?? priceEur.map { "€\(Int($0)),-" } }
}

// MARK: - Bag Detail

struct BagDetail: Identifiable, Decodable {
    let id: String
    let name: String
    let brand: String?
    let imageUrl: String?
    let affiliateUrl: String?
    let category: String?
    let type: String?
    let length: Double?
    let width: Double?
    let depth: Double?
    let weight: Double?
    let airlineSlugs: [String]?
    let shopName: String?
    let shopLogoUrl: String?
    let shopDomain: String?
    let featured: Bool?
    let editorRank: Int?
    let editorNote: String?
    // Afgeleide velden
    let dimensionsLabel: String?
    let volumeLiters: Double?
    let totalDimensionsCm: Double?
    let detailUrl: String?
    let apiDetailUrl: String?
    let priceEur: Double?
    let priceCurrency: String?
    let priceLabel: String?
    // Detail-only velden
    let colors: [String]?
    let matchedAirlines: [Airline]?
    let similarBags: [Bag]?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, category, type, colors, featured
        case imageUrl          = "image_url"
        case affiliateUrl      = "affiliate_url"
        case lengthCm          = "length_cm"
        case widthCm           = "width_cm"
        case depthCm           = "depth_cm"
        case weightKg          = "weight_kg"
        case airlineSlugs      = "airline_slugs"
        case shopName          = "shop_name"
        case shopLogoUrl       = "shop_logo_url"
        case shopDomain        = "shop_domain"
        case editorRank        = "editor_rank"
        case editorNote        = "editor_note"
        case dimensionsLabel   = "dimensions_label"
        case volumeLiters      = "volume_liters"
        case totalDimensionsCm = "total_dimensions_cm"
        case detailUrl         = "detail_url"
        case apiDetailUrl      = "api_detail_url"
        case priceEur          = "price_eur"
        case priceCurrency     = "price_currency"
        case priceLabel        = "price_label"
        case matchedAirlines   = "matched_airlines"
        case similarBags       = "similar_bags"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        affiliateUrl = try c.decodeIfPresent(String.self, forKey: .affiliateUrl)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        length = try c.decodeIfPresent(Double.self, forKey: .lengthCm)
        width = try c.decodeIfPresent(Double.self, forKey: .widthCm)
        depth = try c.decodeIfPresent(Double.self, forKey: .depthCm)
        weight = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        airlineSlugs = try c.decodeIfPresent([String].self, forKey: .airlineSlugs)
        shopName = try c.decodeIfPresent(String.self, forKey: .shopName)
        shopLogoUrl = try c.decodeIfPresent(String.self, forKey: .shopLogoUrl)
        shopDomain = try c.decodeIfPresent(String.self, forKey: .shopDomain)
        featured = try c.decodeIfPresent(Bool.self, forKey: .featured)
        editorRank = try c.decodeIfPresent(Int.self, forKey: .editorRank)
        editorNote = try c.decodeIfPresent(String.self, forKey: .editorNote)
        dimensionsLabel = try c.decodeIfPresent(String.self, forKey: .dimensionsLabel)
        volumeLiters = try c.decodeIfPresent(Double.self, forKey: .volumeLiters)
        totalDimensionsCm = try c.decodeIfPresent(Double.self, forKey: .totalDimensionsCm)
        detailUrl = try c.decodeIfPresent(String.self, forKey: .detailUrl)
        apiDetailUrl = try c.decodeIfPresent(String.self, forKey: .apiDetailUrl)
        priceEur = try c.decodeIfPresent(Double.self, forKey: .priceEur)
        priceCurrency = try c.decodeIfPresent(String.self, forKey: .priceCurrency)
        priceLabel = try c.decodeIfPresent(String.self, forKey: .priceLabel)
        colors = try c.decodeIfPresent([String].self, forKey: .colors)
        matchedAirlines = try c.decodeIfPresent([Airline].self, forKey: .matchedAirlines)
        similarBags = try c.decodeIfPresent([Bag].self, forKey: .similarBags)
    }

    var displayPrice: String? { priceLabel ?? priceEur.map { "€\(Int($0)),-" } }
}

// MARK: - Bag fit type (onder de stoel vs. bagagevak)

enum BagFitType: String, CaseIterable, Identifiable {
    case underSeat, overhead

    var id: String { rawValue }

    var label: String {
        switch self {
        case .underSeat: return "Onder de stoel"
        case .overhead:  return "In het bagagevak"
        }
    }

    var icon: String {
        switch self {
        case .underSeat: return "figure.seated.side"
        case .overhead:  return "bag.fill"
        }
    }
}

protocol BagDimensioned {
    var length: Double? { get }
    var width: Double? { get }
    var depth: Double? { get }
}

extension BagDimensioned {
    /// Grove classificatie op basis van afmetingen: een klein persoonlijk item
    /// past onder de stoel, een grotere cabin bag hoort in het bagagevak.
    var fitType: BagFitType? {
        guard let l = length, let w = width, let d = depth else { return nil }
        let sorted = [l, w, d].sorted(by: >)
        let fitsUnderSeat = sorted[0] <= 45 && sorted[1] <= 35 && sorted[2] <= 20
        return fitsUnderSeat ? .underSeat : .overhead
    }
}

extension Bag: BagDimensioned {}
extension BagDetail: BagDimensioned {}

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
    let variant: AirlineVariant?
    let airline: Airline?

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
