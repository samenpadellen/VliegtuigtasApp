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
    let flightIata: String?
    let flightIcao: String?
    let airlineName: String?
    let airlineIata: String?
    let departureAirport: String?
    let departureIata: String?
    let arrivalAirport: String?
    let arrivalIata: String?
    let flightDate: String?      // "2026-07-02"
    let status: String?          // scheduled | active | landed | cancelled | ...
    let airlineLogoUrl: String?
    /// Full matched Airline from our database (has id, slug, variants)
    let matchedAirline: Airline?

    enum CodingKeys: String, CodingKey {
        case flightIata       = "flight_iata"
        case flightIcao       = "flight_icao"
        case airlineName      = "airline_name"
        case airlineIata      = "airline_iata"
        case departureAirport = "departure_airport"
        case departureIata    = "departure_iata"
        case arrivalAirport   = "arrival_airport"
        case arrivalIata      = "arrival_iata"
        case flightDate       = "flight_date"
        case status
        case airlineLogoUrl   = "airline_logo_url"
        case matchedAirline   = "matched_airline"
    }

    /// Best resolved airline — matched_airline has full data incl. variants
    var resolvedAirline: Airline? { matchedAirline }

    /// Display name when matched_airline is nil
    var rawAirlineName: String? { airlineName }

    var flightNumber: String? { flightIata }

    var hasRoute: Bool { departureIata != nil && arrivalIata != nil }

    /// Nederlands label voor de vluchtstatus van Aviationstack.
    var statusLabel: String? {
        switch status {
        case "scheduled": return "Gepland"
        case "active":    return "In de lucht"
        case "landed":    return "Geland"
        case "cancelled": return "Geannuleerd"
        case "incident":  return "Incident"
        case "diverted":  return "Omgeleid"
        case "delayed":   return "Vertraagd"
        default:          return nil
        }
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

// MARK: - Airport

struct Airport: Identifiable, Codable, Hashable {
    let id: String
    let iata: String
    let name: String
    let city: String
    let type: String // "Hub", "Low-cost hub", "Regional", etc.
    let airlineExamples: [String]? // Array of airline names that fly there

    // Security features
    let has3DCtScan: Bool?
    let fluidsMustBeRemoved: Bool?
    let electronicsOutOfBag: Bool?
    let jewelryMustBeRemoved: Bool?

    // Facilities
    let hasBaggageLockers: Bool?
    let fastTrackPrice: Double? // in EUR
    let recommendedArrivalMinutes: Int? // minutes before departure
    let recommendedArrivalMinutesHighSeason: Int?
    let airportOpensAt: String? // time like "04:30"

    // Special notes
    let specialNotes: String?
    let tips: [String]?
    let warningMessages: [String]?

    // Links
    let officialUrl: String?
}

// MARK: - EU Rules

struct EULuggageRules: Identifiable, Codable {
    let id: String = "eu-rules"

    struct FluidRule: Codable {
        let title: String
        let description: String
        let maxMlPerBottle: Int
        let maxTotalLiters: Double
        let examples: [String]
    }

    struct PowerBankRule: Codable {
        let title: String
        let maxWhWithoutPermission: Int
        let maxWhWithPermission: Int
        let maxUnitsWithPermission: Int
        let details: String
    }

    struct ProhibitedItem: Codable {
        let name: String
        let category: String // "always", "handbagage-only", "checked-only"
    }

    let fluidRule: FluidRule
    let powerBankRule: PowerBankRule
    let ecigaretteRule: String
    let sharpObjectsRule: String
    let prohibitedItems: [ProhibitedItem]
    let checkedBaggageLiquids: String
}

// MARK: - Customs

struct CustomsInfo: Identifiable, Codable {
    let id: String = "customs"

    struct TobaccoLimits: Codable {
        let cigarettes: Int
        let shaggingTobacco: Int
        let cigarillos: Int
        let cigars: Int
    }

    struct AlcoholLimits: Codable {
        let strongSpirits: String // "1 liter"
        let sparklingWine: String // "2 liters"
        let notes: String?
    }

    let dutyfreeImportLimit: Double // EUR 430
    let landImportLimit: Double // EUR 300
    let tobacco: TobaccoLimits
    let alcohol: AlcoholLimits
    let btw: String? // "21%" for NL, etc
    let cashDeclarationThreshold: Double // EUR 10000
    let restrictedItems: [String]
}

// MARK: - Baggage Issues

struct BaggageIssueInfo: Identifiable, Codable {
    let id: String = "baggage-issues"

    struct Claim: Codable {
        let condition: String // "Damaged", "Delayed", "Lost"
        let daysToReport: Int
        let daysToClaimAfterLoss: Int? // days until can claim as lost
        let maxCompensationEur: Double
        let description: String
    }

    let immediateReporting: String
    let pirForm: String
    let claims: [Claim]
    let baggageRedelivery: String
    let tips: [String]
}

// MARK: - Alert

struct AlertMessage: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let type: String // "info", "warning", "alert"
    let airport: String? // nil = applies to all
    let expiryDate: String? // ISO date string
}
