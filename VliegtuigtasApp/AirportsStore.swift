import Foundation

@MainActor
final class AirportsStore: ObservableObject {
    @Published var airports: [Airport] = []
    @Published var euRules: EULuggageRules? = nil
    @Published var customsInfo: CustomsInfo? = nil
    @Published var baggageIssueInfo: BaggageIssueInfo? = nil
    @Published var isLoading = false

    static let shared = AirportsStore()

    init() {
        loadLocalData()
    }

    private func loadLocalData() {
        airports = mockAirports()
        euRules = mockEURules()
        customsInfo = mockCustomsInfo()
        baggageIssueInfo = mockBaggageIssueInfo()
    }

    private func mockAirports() -> [Airport] {
        [
            Airport(
                id: "ams",
                iata: "AMS",
                name: "Amsterdam Airport Schiphol",
                city: "Amsterdam",
                type: "Hub",
                airlineExamples: ["KLM", "TUI", "Transavia", "Corendon"],
                has3DCtScan: nil,
                fluidsMustBeRemoved: true,
                electronicsOutOfBag: true,
                jewelryMustBeRemoved: false,
                hasBaggageLockers: true,
                fastTrackPrice: 119.0,
                recommendedArrivalMinutes: 120,
                recommendedArrivalMinutesHighSeason: 180,
                airportOpensAt: "04:30",
                specialNotes: "Bagage is gekoppeld aan de passagier: mis je je vlucht, dan wordt je ingecheckte koffer er automatisch afgehaald.",
                tips: [
                    "Minimaliseer handbagage-inhoud voor snellere security-controle",
                    "Beveiligde bagagelabels voorhanden",
                    "Zelf bagage labelen/inchecken mogelijk via self-service zuilen"
                ],
                warningMessages: [
                    "Wachttijden kunnen aanzienlijk zijn in piekperiodes"
                ],
                officialUrl: "https://www.schiphol.nl"
            ),
            Airport(
                id: "ein",
                iata: "EIN",
                name: "Eindhoven Airport",
                city: "Eindhoven",
                type: "Low-cost hub",
                airlineExamples: ["Transavia", "Ryanair", "Wizz Air", "TUI fly", "Corendon"],
                has3DCtScan: true,
                fluidsMustBeRemoved: false,
                electronicsOutOfBag: false,
                jewelryMustBeRemoved: false,
                hasBaggageLockers: nil,
                fastTrackPrice: nil,
                recommendedArrivalMinutes: 90,
                recommendedArrivalMinutesHighSeason: 120,
                airportOpensAt: "04:30",
                specialNotes: "Sterkste handhaving van handbagage-regels van alle Nederlandse luchthavens.",
                tips: [
                    "3D CT-scanners: je hoeft vloeistoffen, gels, laptops en andere elektronica niet uit je tas te halen bij security",
                    "Bagagemeter aan de gate: niet passende bagage kost €60-70 aan de gate (vs. €6-20 online)",
                    "Gatecontrole: Ryanair en Wizz Air controleren steekproefsgewijs gewicht aan de gate",
                    "Reserveer priority/cabinebagage liever online (€6-20) dan aan de gate (€60-70)"
                ],
                warningMessages: [
                    "Handbagage-regels worden hier het strengst gehandhaafd - voorkom de €60-70 gate-boete!"
                ],
                officialUrl: "https://www.eindhovenairport.com"
            ),
            Airport(
                id: "rtm",
                iata: "RTM",
                name: "Rotterdam The Hague Airport",
                city: "Rotterdam",
                type: "Regional",
                airlineExamples: ["Various airlines"],
                has3DCtScan: true,
                fluidsMustBeRemoved: false,
                electronicsOutOfBag: false,
                jewelryMustBeRemoved: false,
                hasBaggageLockers: nil,
                fastTrackPrice: 12.5,
                recommendedArrivalMinutes: 90,
                recommendedArrivalMinutesHighSeason: 120,
                airportOpensAt: nil,
                specialNotes: "Nieuwste securityapparatuur op deze luchthaven.",
                tips: [
                    "3D CT-scanners: vloeistoffen, gels, spuitbussen, laptop, tablet en overige elektronica hoeven niet uit de tas",
                    "Sieraden mogen om blijven tijdens de scan",
                    "Avond-inchecken: optioneel inchecken voor bagage de avond vóór vertrek (20:00-22:00 uur) voor ochtendvluchten"
                ],
                warningMessages: nil,
                officialUrl: "https://www.rotterdam-airport.com"
            ),
            Airport(
                id: "grq",
                iata: "GRQ",
                name: "Groningen Airport Eelde",
                city: "Groningen",
                type: "Small - Charters",
                airlineExamples: ["TUI", "Corendon", "Transavia"],
                has3DCtScan: nil,
                fluidsMustBeRemoved: nil,
                electronicsOutOfBag: nil,
                jewelryMustBeRemoved: nil,
                hasBaggageLockers: false,
                fastTrackPrice: nil,
                recommendedArrivalMinutes: 120,
                recommendedArrivalMinutesHighSeason: nil,
                airportOpensAt: nil,
                specialNotes: "Kleinste van de 5 grote Nederlandse luchthavens.",
                tips: [
                    "Geen bagagekluizen op de luchthaven",
                    "Check-in balies openen doorgaans 2,5-3 uur voor vertrek",
                    "Bagage 's ochtends afgeven en later terugkomen is niet mogelijk (veiligheidsreden)",
                    "Kinderwagens: aanmelden bij check-in, gebruik tot aan boarding, terugontvangst bij aankomst"
                ],
                warningMessages: [
                    "Samsung Galaxy Note 7 is expliciet verboden - zowel hand- als ruimbagage"
                ],
                officialUrl: "https://www.groningenairport.com"
            ),
            Airport(
                id: "mst",
                iata: "MST",
                name: "Maastricht Aachen Airport",
                city: "Maastricht",
                type: "Regional",
                airlineExamples: ["Turkish Airlines", "Emirates"],
                has3DCtScan: false,
                fluidsMustBeRemoved: true,
                electronicsOutOfBag: true,
                jewelryMustBeRemoved: true,
                hasBaggageLockers: nil,
                fastTrackPrice: nil,
                recommendedArrivalMinutes: 120,
                recommendedArrivalMinutesHighSeason: 150,
                airportOpensAt: nil,
                specialNotes: "Zelfservice bagage-drop zuilen beschikbaar.",
                tips: [
                    "Zelfservice bagage-drop: drie blauwe check-in zuilen bij binnenkomst",
                    "Millimetergolf-scanner: je moet wél alle elektronica groter dan smartphone los in de bak leggen, net als vloeistoffenzakje",
                    "Sieraden, riem en hoofddeksel moeten af voor de scanner",
                    "Check-in opent 2,5 uur voor vertrek, je hebt dan 1u45 om in te checken"
                ],
                warningMessages: nil,
                officialUrl: "https://www.maa.nl"
            ),
            Airport(
                id: "ley",
                iata: "LEY",
                name: "Lelystad Airport",
                city: "Lelystad",
                type: "Not yet commercial",
                airlineExamples: [],
                has3DCtScan: nil,
                fluidsMustBeRemoved: nil,
                electronicsOutOfBag: nil,
                jewelryMustBeRemoved: nil,
                hasBaggageLockers: nil,
                fastTrackPrice: nil,
                recommendedArrivalMinutes: nil,
                recommendedArrivalMinutesHighSeason: nil,
                airportOpensAt: nil,
                specialNotes: "Nog niet open voor commerciële passagiersvluchten.",
                tips: [
                    "Terminal is fysiek klaar",
                    "Opening voor vakantievluchten gepland voor oktober 2027",
                    "Status afhankelijk van natuurvergunning en aanpassing luchthavenbesluit"
                ],
                warningMessages: [
                    "Nog niet beschikbaar voor commerciële vluchten"
                ],
                officialUrl: nil
            )
        ]
    }

    private func mockEURules() -> EULuggageRules {
        EULuggageRules(
            fluidRule: EULuggageRules.FluidRule(
                title: "Vloeistoffen, gels en spuitbussen",
                description: "Alle vloeistoffen, gels en spuitbussen zijn onderworpen aan het 100ml-regel.",
                maxMlPerBottle: 100,
                maxTotalLiters: 1.0,
                examples: ["Tandpasta", "Shampoo", "Deodorant", "Parfum", "Zonnebrand"]
            ),
            powerBankRule: EULuggageRules.PowerBankRule(
                title: "Powerbanks en losse lithium-ion batterijen",
                maxWhWithoutPermission: 100,
                maxWhWithPermission: 160,
                maxUnitsWithPermission: 2,
                details: "Tot 100 Wh zonder toestemming toegestaan in handbagage. 100-160 Wh alleen met toestemming van de airline, max. 2 stuks. Boven 160 Wh verboden. Altijd in handbagage (niet in ruimbagage)."
            ),
            ecigaretteRule: "E-sigaretten/vapes: alleen in handbagage, max. 1 stuk per passagier, gebruik aan boord verboden.",
            sharpObjectsRule: "Scherpe voorwerpen: mesjes/scharen met lemmet/blad langer dan 6 cm niet toegestaan in handbagage (wel in ruimbagage).",
            prohibitedItems: [
                EULuggageRules.ProhibitedItem(name: "Vuurwapens (inclusief replica's/speelgoed)", category: "always"),
                EULuggageRules.ProhibitedItem(name: "Munitie", category: "always"),
                EULuggageRules.ProhibitedItem(name: "Explosieven", category: "always"),
                EULuggageRules.ProhibitedItem(name: "Vuurwerk", category: "always"),
                EULuggageRules.ProhibitedItem(name: "Corrosieve/bijtende chemische stoffen", category: "always")
            ]
        )
    }

    private func mockCustomsInfo() -> CustomsInfo {
        CustomsInfo(
            dutyfreeImportLimit: 430,
            landImportLimit: 300,
            tobacco: CustomsInfo.TobaccoLimits(
                cigarettes: 200,
                shaggingTobacco: 250,
                cigarillos: 100,
                cigars: 50
            ),
            alcohol: CustomsInfo.AlcoholLimits(
                strongSpirits: "1 liter (>22% alcohol)",
                sparklingWine: "2 liters (mousserende wijn, sherry, port)",
                notes: "Bij sterke drank (>18%) mogen twee personen samen alleen flessen van max. 1 liter belastingvrij meenemen."
            ),
            btw: "21% (Nederland)",
            cashDeclarationThreshold: 10000,
            restrictedItems: [
                "Drugs",
                "Wapens",
                "Beschermde dier-/plantensoorten",
                "Namaakartikelen"
            ]
        )
    }

    private func mockBaggageIssueInfo() -> BaggageIssueInfo {
        BaggageIssueInfo(
            immediateReporting: "Bij aankomst, vóór je de bagagehal verlaat, meld je een vermiste/beschadigde koffer bij de bagageservicebalie (in de aankomsthal, meestal bij de douane).",
            pirForm: "Je krijgt een PIR-formulier (Property Irregularity Report) met een dossiernummer waarmee je de status kunt volgen.",
            claims: [
                BaggageIssueInfo.Claim(
                    condition: "Beschadigde bagage",
                    daysToReport: 7,
                    daysToClaimAfterLoss: nil,
                    maxCompensationEur: 1860,
                    description: "Beschadigd bagage moet binnen 7 dagen na ontvangst gemeld worden."
                ),
                BaggageIssueInfo.Claim(
                    condition: "Vertraagde bagage",
                    daysToReport: 21,
                    daysToClaimAfterLoss: nil,
                    maxCompensationEur: 1860,
                    description: "Vertraagde bagage moet binnen 21 dagen na ontvangst gemeld worden. Je kunt noodzakelijke aankopen (toiletartikelen, kleding) declareren."
                ),
                BaggageIssueInfo.Claim(
                    condition: "Kwijtgeraakte bagage",
                    daysToReport: 21,
                    daysToClaimAfterLoss: 730,
                    maxCompensationEur: 1860,
                    description: "Pas na 21 dagen mag je bagage als 'kwijt' claimen (mag eerder als de maatschappij bevestigt). Claimtermijn tot 2 jaar."
                )
            ],
            baggageRedelivery: "De maatschappij moet teruggevonden bagage gratis op je huis-/verblijfadres afleveren — je hoeft er niet voor terug naar de luchthaven.",
            tips: [
                "Maak vóór vertrek een foto van je koffer + label (merk, kleur, kenmerken)",
                "Bewaar het claimtagnummer (bagagelabel)",
                "Niet elke maatschappij heeft een online formulier — bij Transavia, EasyJet, Vueling moet je verplicht fysiek naar de balie",
                "Bewaar bonnetjes van noodzakelijke aankopen bij vertraagde bagage"
            ]
        )
    }

    func airport(byIata iata: String) -> Airport? {
        airports.first { $0.iata == iata }
    }

    func airport(byId id: String) -> Airport? {
        airports.first { $0.id == id }
    }
}

// MARK: - Luchthavens voor routekeuze (vertrek → aankomst)

/// Compacte luchthaven voor het kiezen van een route zonder vluchtnummer.
///
/// Bewust los van `Airport` hierboven: dat model draait om Nederlandse
/// vertrekluchthavens met security-tips, wachttijden en openingstijden. Voor
/// "ik vlieg van AMS naar Zürich" is alleen de code, de stad en het land
/// nodig — en dan wel voor honderden bestemmingen in plaats van zes.
struct RouteAirport: Identifiable, Hashable {
    let iata: String
    let city: String
    let name: String
    let country: String

    var id: String { iata }

    /// "AMS · Amsterdam" — hoe de keuze in de UI wordt samengevat.
    var shortLabel: String { "\(iata) · \(city)" }

    /// Doorzoekbaar op code, stad, land én luchthavennaam, zodat zowel "ZRH"
    /// als "zurich" als "zwitserland" werkt.
    func matches(_ query: String) -> Bool {
        let q = query.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        guard !q.isEmpty else { return true }
        return [iata, city, name, country]
            .map { $0.folding(options: .diacriticInsensitive, locale: nil).lowercased() }
            .contains { $0.contains(q) }
    }
}

enum RouteAirports {
    /// Waar Nederlandse reizigers vertrekken — deze staan bovenaan de lijst.
    static let dutch: [RouteAirport] = [
        .init(iata: "AMS", city: "Amsterdam", name: "Schiphol", country: "Nederland"),
        .init(iata: "EIN", city: "Eindhoven", name: "Eindhoven Airport", country: "Nederland"),
        .init(iata: "RTM", city: "Rotterdam", name: "Rotterdam The Hague", country: "Nederland"),
        .init(iata: "GRQ", city: "Groningen", name: "Eelde", country: "Nederland"),
        .init(iata: "MST", city: "Maastricht", name: "Maastricht Aachen", country: "Nederland"),
        .init(iata: "LEY", city: "Lelystad", name: "Lelystad Airport", country: "Nederland"),
    ]

    /// Bestemmingen: Europa breed, plus de gangbare langeafstandsbestemmingen.
    static let international: [RouteAirport] = [
        // België, Duitsland, Luxemburg
        .init(iata: "BRU", city: "Brussel", name: "Zaventem", country: "België"),
        .init(iata: "CRL", city: "Charleroi", name: "Brussels South", country: "België"),
        .init(iata: "ANR", city: "Antwerpen", name: "Deurne", country: "België"),
        .init(iata: "DUS", city: "Düsseldorf", name: "Düsseldorf", country: "Duitsland"),
        .init(iata: "FRA", city: "Frankfurt", name: "Frankfurt am Main", country: "Duitsland"),
        .init(iata: "MUC", city: "München", name: "Franz Josef Strauss", country: "Duitsland"),
        .init(iata: "BER", city: "Berlijn", name: "Brandenburg", country: "Duitsland"),
        .init(iata: "HAM", city: "Hamburg", name: "Hamburg", country: "Duitsland"),
        .init(iata: "CGN", city: "Keulen", name: "Köln/Bonn", country: "Duitsland"),
        .init(iata: "STR", city: "Stuttgart", name: "Stuttgart", country: "Duitsland"),
        .init(iata: "LUX", city: "Luxemburg", name: "Findel", country: "Luxemburg"),

        // Verenigd Koninkrijk & Ierland
        .init(iata: "LHR", city: "Londen", name: "Heathrow", country: "Verenigd Koninkrijk"),
        .init(iata: "LGW", city: "Londen", name: "Gatwick", country: "Verenigd Koninkrijk"),
        .init(iata: "STN", city: "Londen", name: "Stansted", country: "Verenigd Koninkrijk"),
        .init(iata: "LTN", city: "Londen", name: "Luton", country: "Verenigd Koninkrijk"),
        .init(iata: "MAN", city: "Manchester", name: "Manchester", country: "Verenigd Koninkrijk"),
        .init(iata: "EDI", city: "Edinburgh", name: "Edinburgh", country: "Verenigd Koninkrijk"),
        .init(iata: "BHX", city: "Birmingham", name: "Birmingham", country: "Verenigd Koninkrijk"),
        .init(iata: "DUB", city: "Dublin", name: "Dublin", country: "Ierland"),

        // Frankrijk, Zwitserland, Oostenrijk
        .init(iata: "CDG", city: "Parijs", name: "Charles de Gaulle", country: "Frankrijk"),
        .init(iata: "ORY", city: "Parijs", name: "Orly", country: "Frankrijk"),
        .init(iata: "NCE", city: "Nice", name: "Côte d'Azur", country: "Frankrijk"),
        .init(iata: "LYS", city: "Lyon", name: "Saint-Exupéry", country: "Frankrijk"),
        .init(iata: "MRS", city: "Marseille", name: "Provence", country: "Frankrijk"),
        .init(iata: "TLS", city: "Toulouse", name: "Blagnac", country: "Frankrijk"),
        .init(iata: "BOD", city: "Bordeaux", name: "Mérignac", country: "Frankrijk"),
        .init(iata: "ZRH", city: "Zürich", name: "Kloten", country: "Zwitserland"),
        .init(iata: "GVA", city: "Genève", name: "Cointrin", country: "Zwitserland"),
        .init(iata: "BSL", city: "Basel", name: "EuroAirport", country: "Zwitserland"),
        .init(iata: "VIE", city: "Wenen", name: "Schwechat", country: "Oostenrijk"),
        .init(iata: "SZG", city: "Salzburg", name: "Salzburg", country: "Oostenrijk"),
        .init(iata: "INN", city: "Innsbruck", name: "Innsbruck", country: "Oostenrijk"),

        // Spanje & Portugal
        .init(iata: "BCN", city: "Barcelona", name: "El Prat", country: "Spanje"),
        .init(iata: "MAD", city: "Madrid", name: "Barajas", country: "Spanje"),
        .init(iata: "AGP", city: "Málaga", name: "Costa del Sol", country: "Spanje"),
        .init(iata: "ALC", city: "Alicante", name: "Alicante-Elche", country: "Spanje"),
        .init(iata: "PMI", city: "Palma de Mallorca", name: "Son Sant Joan", country: "Spanje"),
        .init(iata: "IBZ", city: "Ibiza", name: "Ibiza", country: "Spanje"),
        .init(iata: "VLC", city: "Valencia", name: "Valencia", country: "Spanje"),
        .init(iata: "SVQ", city: "Sevilla", name: "San Pablo", country: "Spanje"),
        .init(iata: "TFS", city: "Tenerife", name: "Tenerife Zuid", country: "Spanje"),
        .init(iata: "LPA", city: "Gran Canaria", name: "Gran Canaria", country: "Spanje"),
        .init(iata: "ACE", city: "Lanzarote", name: "Lanzarote", country: "Spanje"),
        .init(iata: "FUE", city: "Fuerteventura", name: "Fuerteventura", country: "Spanje"),
        .init(iata: "LIS", city: "Lissabon", name: "Humberto Delgado", country: "Portugal"),
        .init(iata: "OPO", city: "Porto", name: "Francisco Sá Carneiro", country: "Portugal"),
        .init(iata: "FAO", city: "Faro", name: "Faro", country: "Portugal"),
        .init(iata: "FNC", city: "Madeira", name: "Cristiano Ronaldo", country: "Portugal"),

        // Italië, Griekenland, Malta, Cyprus
        .init(iata: "FCO", city: "Rome", name: "Fiumicino", country: "Italië"),
        .init(iata: "MXP", city: "Milaan", name: "Malpensa", country: "Italië"),
        .init(iata: "BGY", city: "Milaan", name: "Bergamo", country: "Italië"),
        .init(iata: "VCE", city: "Venetië", name: "Marco Polo", country: "Italië"),
        .init(iata: "NAP", city: "Napels", name: "Capodichino", country: "Italië"),
        .init(iata: "FLR", city: "Florence", name: "Peretola", country: "Italië"),
        .init(iata: "BLQ", city: "Bologna", name: "Guglielmo Marconi", country: "Italië"),
        .init(iata: "CTA", city: "Catania", name: "Fontanarossa", country: "Italië"),
        .init(iata: "ATH", city: "Athene", name: "Eleftherios Venizelos", country: "Griekenland"),
        .init(iata: "SKG", city: "Thessaloniki", name: "Makedonia", country: "Griekenland"),
        .init(iata: "HER", city: "Kreta", name: "Heraklion", country: "Griekenland"),
        .init(iata: "RHO", city: "Rhodos", name: "Diagoras", country: "Griekenland"),
        .init(iata: "CFU", city: "Corfu", name: "Ioannis Kapodistrias", country: "Griekenland"),
        .init(iata: "JTR", city: "Santorini", name: "Santorini", country: "Griekenland"),
        .init(iata: "MLA", city: "Malta", name: "Luqa", country: "Malta"),
        .init(iata: "LCA", city: "Larnaca", name: "Larnaca", country: "Cyprus"),

        // Scandinavië, Baltische staten, IJsland
        .init(iata: "CPH", city: "Kopenhagen", name: "Kastrup", country: "Denemarken"),
        .init(iata: "ARN", city: "Stockholm", name: "Arlanda", country: "Zweden"),
        .init(iata: "GOT", city: "Göteborg", name: "Landvetter", country: "Zweden"),
        .init(iata: "OSL", city: "Oslo", name: "Gardermoen", country: "Noorwegen"),
        .init(iata: "BGO", city: "Bergen", name: "Flesland", country: "Noorwegen"),
        .init(iata: "HEL", city: "Helsinki", name: "Vantaa", country: "Finland"),
        .init(iata: "KEF", city: "Reykjavik", name: "Keflavík", country: "IJsland"),
        .init(iata: "RIX", city: "Riga", name: "Riga", country: "Letland"),
        .init(iata: "TLL", city: "Tallinn", name: "Lennart Meri", country: "Estland"),
        .init(iata: "VNO", city: "Vilnius", name: "Vilnius", country: "Litouwen"),

        // Midden- en Oost-Europa
        .init(iata: "PRG", city: "Praag", name: "Václav Havel", country: "Tsjechië"),
        .init(iata: "BUD", city: "Boedapest", name: "Ferenc Liszt", country: "Hongarije"),
        .init(iata: "WAW", city: "Warschau", name: "Chopin", country: "Polen"),
        .init(iata: "KRK", city: "Krakau", name: "Balice", country: "Polen"),
        .init(iata: "GDN", city: "Gdansk", name: "Lech Wałęsa", country: "Polen"),
        .init(iata: "OTP", city: "Boekarest", name: "Henri Coandă", country: "Roemenië"),
        .init(iata: "SOF", city: "Sofia", name: "Sofia", country: "Bulgarije"),
        .init(iata: "ZAG", city: "Zagreb", name: "Franjo Tuđman", country: "Kroatië"),
        .init(iata: "SPU", city: "Split", name: "Split", country: "Kroatië"),
        .init(iata: "DBV", city: "Dubrovnik", name: "Dubrovnik", country: "Kroatië"),
        .init(iata: "LJU", city: "Ljubljana", name: "Jože Pučnik", country: "Slovenië"),

        // Turkije, Midden-Oosten, Noord-Afrika
        .init(iata: "IST", city: "Istanbul", name: "Istanbul Airport", country: "Turkije"),
        .init(iata: "SAW", city: "Istanbul", name: "Sabiha Gökçen", country: "Turkije"),
        .init(iata: "AYT", city: "Antalya", name: "Antalya", country: "Turkije"),
        .init(iata: "DXB", city: "Dubai", name: "Dubai International", country: "VAE"),
        .init(iata: "AUH", city: "Abu Dhabi", name: "Zayed International", country: "VAE"),
        .init(iata: "DOH", city: "Doha", name: "Hamad International", country: "Qatar"),
        .init(iata: "TLV", city: "Tel Aviv", name: "Ben Gurion", country: "Israël"),
        .init(iata: "CAI", city: "Caïro", name: "Cairo International", country: "Egypte"),
        .init(iata: "HRG", city: "Hurghada", name: "Hurghada", country: "Egypte"),
        .init(iata: "RMF", city: "Marsa Alam", name: "Marsa Alam", country: "Egypte"),
        .init(iata: "RAK", city: "Marrakesh", name: "Menara", country: "Marokko"),
        .init(iata: "AGA", city: "Agadir", name: "Al Massira", country: "Marokko"),
        .init(iata: "CMN", city: "Casablanca", name: "Mohammed V", country: "Marokko"),
        .init(iata: "TUN", city: "Tunis", name: "Carthage", country: "Tunesië"),

        // Noord-Amerika
        .init(iata: "JFK", city: "New York", name: "John F. Kennedy", country: "Verenigde Staten"),
        .init(iata: "EWR", city: "New York", name: "Newark", country: "Verenigde Staten"),
        .init(iata: "BOS", city: "Boston", name: "Logan", country: "Verenigde Staten"),
        .init(iata: "IAD", city: "Washington", name: "Dulles", country: "Verenigde Staten"),
        .init(iata: "MIA", city: "Miami", name: "Miami International", country: "Verenigde Staten"),
        .init(iata: "MCO", city: "Orlando", name: "Orlando International", country: "Verenigde Staten"),
        .init(iata: "LAX", city: "Los Angeles", name: "Los Angeles Intl", country: "Verenigde Staten"),
        .init(iata: "SFO", city: "San Francisco", name: "San Francisco Intl", country: "Verenigde Staten"),
        .init(iata: "ORD", city: "Chicago", name: "O'Hare", country: "Verenigde Staten"),
        .init(iata: "LAS", city: "Las Vegas", name: "Harry Reid", country: "Verenigde Staten"),
        .init(iata: "YYZ", city: "Toronto", name: "Pearson", country: "Canada"),
        .init(iata: "YVR", city: "Vancouver", name: "Vancouver Intl", country: "Canada"),
        .init(iata: "CUN", city: "Cancún", name: "Cancún", country: "Mexico"),

        // Caribisch gebied & Zuid-Amerika
        .init(iata: "CUR", city: "Curaçao", name: "Hato", country: "Curaçao"),
        .init(iata: "AUA", city: "Aruba", name: "Reina Beatrix", country: "Aruba"),
        .init(iata: "BON", city: "Bonaire", name: "Flamingo", country: "Bonaire"),
        .init(iata: "SXM", city: "Sint Maarten", name: "Princess Juliana", country: "Sint Maarten"),
        .init(iata: "PBM", city: "Paramaribo", name: "Johan Adolf Pengel", country: "Suriname"),
        .init(iata: "PUJ", city: "Punta Cana", name: "Punta Cana", country: "Dominicaanse Republiek"),
        .init(iata: "GRU", city: "São Paulo", name: "Guarulhos", country: "Brazilië"),
        .init(iata: "EZE", city: "Buenos Aires", name: "Ezeiza", country: "Argentinië"),
        .init(iata: "LIM", city: "Lima", name: "Jorge Chávez", country: "Peru"),

        // Azië, Afrika, Oceanië
        .init(iata: "BKK", city: "Bangkok", name: "Suvarnabhumi", country: "Thailand"),
        .init(iata: "HKT", city: "Phuket", name: "Phuket", country: "Thailand"),
        .init(iata: "SIN", city: "Singapore", name: "Changi", country: "Singapore"),
        .init(iata: "DPS", city: "Bali", name: "Ngurah Rai", country: "Indonesië"),
        .init(iata: "CGK", city: "Jakarta", name: "Soekarno-Hatta", country: "Indonesië"),
        .init(iata: "KUL", city: "Kuala Lumpur", name: "Kuala Lumpur Intl", country: "Maleisië"),
        .init(iata: "HND", city: "Tokio", name: "Haneda", country: "Japan"),
        .init(iata: "NRT", city: "Tokio", name: "Narita", country: "Japan"),
        .init(iata: "ICN", city: "Seoul", name: "Incheon", country: "Zuid-Korea"),
        .init(iata: "HKG", city: "Hongkong", name: "Hong Kong Intl", country: "Hongkong"),
        .init(iata: "PVG", city: "Shanghai", name: "Pudong", country: "China"),
        .init(iata: "PEK", city: "Peking", name: "Capital", country: "China"),
        .init(iata: "DEL", city: "New Delhi", name: "Indira Gandhi", country: "India"),
        .init(iata: "BOM", city: "Mumbai", name: "Chhatrapati Shivaji", country: "India"),
        .init(iata: "CPT", city: "Kaapstad", name: "Cape Town Intl", country: "Zuid-Afrika"),
        .init(iata: "JNB", city: "Johannesburg", name: "O.R. Tambo", country: "Zuid-Afrika"),
        .init(iata: "NBO", city: "Nairobi", name: "Jomo Kenyatta", country: "Kenia"),
        .init(iata: "SYD", city: "Sydney", name: "Kingsford Smith", country: "Australië"),
        .init(iata: "MEL", city: "Melbourne", name: "Tullamarine", country: "Australië"),
        .init(iata: "AKL", city: "Auckland", name: "Auckland", country: "Nieuw-Zeeland"),
    ]

    static let all: [RouteAirport] = dutch + international

    static func find(iata: String) -> RouteAirport? {
        all.first { $0.iata.caseInsensitiveCompare(iata) == .orderedSame }
    }
}
