import SwiftUI

// MARK: - Model

enum Continent: String, Codable, CaseIterable {
    case europa, afrika, azie, noordAmerika, zuidAmerika, oceanie

    var label: String {
        switch self {
        case .europa:       return "Europa"
        case .afrika:       return "Afrika"
        case .azie:         return "Azië"
        case .noordAmerika: return "Noord-Amerika"
        case .zuidAmerika:  return "Zuid-Amerika"
        case .oceanie:      return "Oceanië"
        }
    }
}

/// Eén land uit de statische wereldlijst. `flagEmoji` wordt berekend uit de
/// ISO-2-code (regional indicator symbols) i.p.v. los opgeslagen — zo kan de
/// vlag nooit los raken van de code.
struct Country: Identifiable, Codable, Equatable, Hashable {
    var id: String { iso2 }
    let iso2: String
    let name: String
    let continent: Continent

    var flagEmoji: String {
        let base: UInt32 = 0x1F1E6
        var scalars = String.UnicodeScalarView()
        for c in iso2.uppercased().unicodeScalars {
            guard let scalar = Unicode.Scalar(base + (c.value - 65)) else { continue }
            scalars.append(scalar)
        }
        return String(scalars)
    }
}

enum VisitStatus: String, Codable {
    case none, wantToVisit, visited
}

// MARK: - Statische wereldlijst (195 soevereine landen)

let allCountries: [Country] = {
    func c(_ iso2: String, _ name: String, _ continent: Continent) -> Country {
        Country(iso2: iso2, name: name, continent: continent)
    }

    let europa: [Country] = [
        c("AL", "Albanië", .europa), c("AD", "Andorra", .europa), c("AT", "Oostenrijk", .europa),
        c("BY", "Wit-Rusland", .europa), c("BE", "België", .europa), c("BA", "Bosnië en Herzegovina", .europa),
        c("BG", "Bulgarije", .europa), c("HR", "Kroatië", .europa), c("CY", "Cyprus", .europa),
        c("CZ", "Tsjechië", .europa), c("DK", "Denemarken", .europa), c("EE", "Estland", .europa),
        c("FI", "Finland", .europa), c("FR", "Frankrijk", .europa), c("DE", "Duitsland", .europa),
        c("GR", "Griekenland", .europa), c("HU", "Hongarije", .europa), c("IS", "IJsland", .europa),
        c("IE", "Ierland", .europa), c("IT", "Italië", .europa), c("XK", "Kosovo", .europa),
        c("LV", "Letland", .europa), c("LI", "Liechtenstein", .europa), c("LT", "Litouwen", .europa),
        c("LU", "Luxemburg", .europa), c("MT", "Malta", .europa), c("MD", "Moldavië", .europa),
        c("MC", "Monaco", .europa), c("ME", "Montenegro", .europa), c("NL", "Nederland", .europa),
        c("MK", "Noord-Macedonië", .europa), c("NO", "Noorwegen", .europa), c("PL", "Polen", .europa),
        c("PT", "Portugal", .europa), c("RO", "Roemenië", .europa), c("RU", "Rusland", .europa),
        c("SM", "San Marino", .europa), c("RS", "Servië", .europa), c("SK", "Slowakije", .europa),
        c("SI", "Slovenië", .europa), c("ES", "Spanje", .europa), c("SE", "Zweden", .europa),
        c("CH", "Zwitserland", .europa), c("UA", "Oekraïne", .europa), c("GB", "Verenigd Koninkrijk", .europa),
        c("VA", "Vaticaanstad", .europa),
    ]

    let afrika: [Country] = [
        c("DZ", "Algerije", .afrika), c("AO", "Angola", .afrika), c("BJ", "Benin", .afrika),
        c("BW", "Botswana", .afrika), c("BF", "Burkina Faso", .afrika), c("BI", "Burundi", .afrika),
        c("CV", "Kaapverdië", .afrika), c("CM", "Kameroen", .afrika), c("CF", "Centraal-Afrikaanse Republiek", .afrika),
        c("TD", "Tsjaad", .afrika), c("KM", "Comoren", .afrika), c("CG", "Congo-Brazzaville", .afrika),
        c("CD", "Congo-Kinshasa", .afrika), c("DJ", "Djibouti", .afrika), c("EG", "Egypte", .afrika),
        c("GQ", "Equatoriaal-Guinea", .afrika), c("ER", "Eritrea", .afrika), c("SZ", "Eswatini", .afrika),
        c("ET", "Ethiopië", .afrika), c("GA", "Gabon", .afrika), c("GM", "Gambia", .afrika),
        c("GH", "Ghana", .afrika), c("GN", "Guinee", .afrika), c("GW", "Guinee-Bissau", .afrika),
        c("CI", "Ivoorkust", .afrika), c("KE", "Kenia", .afrika), c("LS", "Lesotho", .afrika),
        c("LR", "Liberia", .afrika), c("LY", "Libië", .afrika), c("MG", "Madagaskar", .afrika),
        c("MW", "Malawi", .afrika), c("ML", "Mali", .afrika), c("MA", "Marokko", .afrika),
        c("MR", "Mauritanië", .afrika), c("MU", "Mauritius", .afrika), c("MZ", "Mozambique", .afrika),
        c("NA", "Namibië", .afrika), c("NE", "Niger", .afrika), c("NG", "Nigeria", .afrika),
        c("RW", "Rwanda", .afrika), c("ST", "Sao Tomé en Principe", .afrika), c("SN", "Senegal", .afrika),
        c("SC", "Seychellen", .afrika), c("SL", "Sierra Leone", .afrika), c("SO", "Somalië", .afrika),
        c("ZA", "Zuid-Afrika", .afrika), c("SS", "Zuid-Soedan", .afrika), c("SD", "Soedan", .afrika),
        c("TZ", "Tanzania", .afrika), c("TG", "Togo", .afrika), c("TN", "Tunesië", .afrika),
        c("UG", "Oeganda", .afrika), c("ZM", "Zambia", .afrika), c("ZW", "Zimbabwe", .afrika),
    ]

    let azie: [Country] = [
        c("AF", "Afghanistan", .azie), c("AM", "Armenië", .azie), c("AZ", "Azerbeidzjan", .azie),
        c("BH", "Bahrein", .azie), c("BD", "Bangladesh", .azie), c("BT", "Bhutan", .azie),
        c("BN", "Brunei", .azie), c("KH", "Cambodja", .azie), c("CN", "China", .azie),
        c("GE", "Georgië", .azie), c("IN", "India", .azie), c("ID", "Indonesië", .azie),
        c("IQ", "Irak", .azie), c("IR", "Iran", .azie), c("IL", "Israël", .azie),
        c("JP", "Japan", .azie), c("YE", "Jemen", .azie), c("JO", "Jordanië", .azie),
        c("KZ", "Kazachstan", .azie), c("KW", "Koeweit", .azie), c("KG", "Kirgizië", .azie),
        c("LA", "Laos", .azie), c("LB", "Libanon", .azie), c("MY", "Maleisië", .azie),
        c("MV", "Malediven", .azie), c("MN", "Mongolië", .azie), c("MM", "Myanmar", .azie),
        c("NP", "Nepal", .azie), c("KP", "Noord-Korea", .azie), c("OM", "Oman", .azie),
        c("UZ", "Oezbekistan", .azie), c("PK", "Pakistan", .azie), c("PS", "Palestina", .azie),
        c("PH", "Filipijnen", .azie), c("QA", "Qatar", .azie), c("SA", "Saudi-Arabië", .azie),
        c("SG", "Singapore", .azie), c("LK", "Sri Lanka", .azie), c("SY", "Syrië", .azie),
        c("TW", "Taiwan", .azie), c("TJ", "Tadzjikistan", .azie), c("TH", "Thailand", .azie),
        c("TL", "Oost-Timor", .azie), c("TR", "Turkije", .azie), c("TM", "Turkmenistan", .azie),
        c("AE", "Verenigde Arabische Emiraten", .azie), c("VN", "Vietnam", .azie), c("KR", "Zuid-Korea", .azie),
    ]

    let noordAmerika: [Country] = [
        c("AG", "Antigua en Barbuda", .noordAmerika), c("BS", "Bahama's", .noordAmerika),
        c("BB", "Barbados", .noordAmerika), c("BZ", "Belize", .noordAmerika),
        c("CA", "Canada", .noordAmerika), c("CR", "Costa Rica", .noordAmerika),
        c("CU", "Cuba", .noordAmerika), c("DM", "Dominica", .noordAmerika),
        c("DO", "Dominicaanse Republiek", .noordAmerika), c("SV", "El Salvador", .noordAmerika),
        c("GD", "Grenada", .noordAmerika), c("GT", "Guatemala", .noordAmerika),
        c("HT", "Haïti", .noordAmerika), c("HN", "Honduras", .noordAmerika),
        c("JM", "Jamaica", .noordAmerika), c("MX", "Mexico", .noordAmerika),
        c("NI", "Nicaragua", .noordAmerika), c("PA", "Panama", .noordAmerika),
        c("KN", "Saint Kitts en Nevis", .noordAmerika), c("LC", "Saint Lucia", .noordAmerika),
        c("VC", "Saint Vincent en de Grenadines", .noordAmerika), c("TT", "Trinidad en Tobago", .noordAmerika),
        c("US", "Verenigde Staten", .noordAmerika),
    ]

    let zuidAmerika: [Country] = [
        c("AR", "Argentinië", .zuidAmerika), c("BO", "Bolivia", .zuidAmerika),
        c("BR", "Brazilië", .zuidAmerika), c("CL", "Chili", .zuidAmerika),
        c("CO", "Colombia", .zuidAmerika), c("EC", "Ecuador", .zuidAmerika),
        c("GY", "Guyana", .zuidAmerika), c("PY", "Paraguay", .zuidAmerika),
        c("PE", "Peru", .zuidAmerika), c("SR", "Suriname", .zuidAmerika),
        c("UY", "Uruguay", .zuidAmerika), c("VE", "Venezuela", .zuidAmerika),
    ]

    let oceanie: [Country] = [
        c("AU", "Australië", .oceanie), c("FJ", "Fiji", .oceanie),
        c("KI", "Kiribati", .oceanie), c("MH", "Marshalleilanden", .oceanie),
        c("FM", "Micronesië", .oceanie), c("NR", "Nauru", .oceanie),
        c("NZ", "Nieuw-Zeeland", .oceanie), c("PW", "Palau", .oceanie),
        c("PG", "Papoea-Nieuw-Guinea", .oceanie), c("SB", "Salomonseilanden", .oceanie),
        c("WS", "Samoa", .oceanie), c("TO", "Tonga", .oceanie),
        c("TV", "Tuvalu", .oceanie), c("VU", "Vanuatu", .oceanie),
    ]

    return europa + afrika + azie + noordAmerika + zuidAmerika + oceanie
}()

/// Zoekt het land dat in een vrije-tekst bestemming voorkomt (bijv. "Rome,
/// Italië" → Italië). Neemt bij meerdere treffers de langste naam: sommige
/// landnamen zitten letterlijk in een andere ("Niger" ⊂ "Nigeria", "Soedan"
/// ⊂ "Zuid-Soedan", "Dominica" ⊂ "Dominicaanse Republiek"), dus
/// eerste-match-wint zou de verkeerde koppelen.
func matchCountry(in text: String) -> Country? {
    guard !text.isEmpty else { return nil }
    return allCountries
        .filter { text.localizedCaseInsensitiveContains($0.name) }
        .max { $0.name.count < $1.name.count }
}

// MARK: - Store (lokaal + iCloud)

/// Beheert de bezoek-status per land (iso2 → status). Zelfde opzet als
/// TripsStore/BagCollectionStore: UserDefaults als bron, iCloud als sync.
@MainActor
final class BucketListStore: ObservableObject {
    static let shared = BucketListStore()
    static let storageKey = "vt_bucket_list"

    @Published private(set) var statuses: [String: VisitStatus] = [:]

    private let defaults = UserDefaults.standard

    private init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: VisitStatus].self, from: data) {
            statuses = decoded
        }
    }

    func status(for country: Country) -> VisitStatus {
        statuses[country.iso2] ?? .none
    }

    /// Kiezen voor "bezocht" of "wil ik heen" wist automatisch de andere status
    /// — een land staat op precies één van de drie statussen.
    func setStatus(_ status: VisitStatus, for country: Country) {
        if status == .none {
            statuses.removeValue(forKey: country.iso2)
        } else {
            statuses[country.iso2] = status
        }
        persist()
    }

    var visitedCount: Int { statuses.values.filter { $0 == .visited }.count }
    var wantToVisitCount: Int { statuses.values.filter { $0 == .wantToVisit }.count }

    var visitedCountries: [Country] {
        allCountries.filter { statuses[$0.iso2] == .visited }
    }

    var visitedContinents: Set<Continent> {
        Set(visitedCountries.map(\.continent))
    }

    var percentWorld: Double {
        guard !allCountries.isEmpty else { return 0 }
        return Double(visitedCount) / Double(allCountries.count) * 100
    }

    /// Vanuit iCloud overgenomen — alleen lokaal schrijven, niet terugpushen.
    func adopt(data: Data) {
        guard let decoded = try? JSONDecoder().decode([String: VisitStatus].self, from: data) else { return }
        statuses = decoded
        defaults.set(data, forKey: Self.storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(statuses) else { return }
        defaults.set(data, forKey: Self.storageKey)
        CloudSync.shared.pushBucketList(data)
    }
}

// MARK: - Foto-cache per land (Pexels)

struct CountryPhoto: Codable, Equatable {
    let url: String
    let authorName: String
    let authorProfileUrl: String
}

/// Cachet één foto per land, lokaal — geen CloudSync nodig: dit is geen
/// gebruikersdata maar een gedeelde referentie-cache (iedereen zou voor
/// hetzelfde land dezelfde foto opzoeken). Persisteert wel naar UserDefaults
/// zodat een land dat je al eens bekeek niet steeds opnieuw wordt opgezocht —
/// bij 195 landen is dat relevant voor het gratis Pexels-uurquotum.
@MainActor
final class CountryPhotoCache: ObservableObject {
    static let shared = CountryPhotoCache()
    private static let storageKey = "vt_country_photo_cache"

    @Published private(set) var photos: [String: CountryPhoto] = [:]

    private let defaults = UserDefaults.standard
    private var inFlight: Set<String> = []

    private init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: CountryPhoto].self, from: data) {
            photos = decoded
        }
    }

    func photo(for country: Country) -> CountryPhoto? {
        photos[country.iso2]
    }

    /// Zoekt alleen op als er nog geen cache-hit is (en niet al een aanvraag
    /// onderweg is voor hetzelfde land, bijv. door snel scrollen).
    func fetchIfNeeded(for country: Country) async {
        guard photos[country.iso2] == nil, !inFlight.contains(country.iso2) else { return }
        inFlight.insert(country.iso2)
        defer { inFlight.remove(country.iso2) }

        guard let photo = await PexelsClient.searchPhoto(query: "\(country.name) landscape") else { return }
        photos[country.iso2] = CountryPhoto(
            url: photo.regularUrl,
            authorName: photo.authorName,
            authorProfileUrl: photo.authorProfileUrl
        )
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(photos) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
