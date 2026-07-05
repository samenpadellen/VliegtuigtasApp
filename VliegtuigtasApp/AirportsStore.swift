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
