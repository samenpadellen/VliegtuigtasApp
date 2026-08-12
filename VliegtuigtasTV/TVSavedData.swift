import Foundation

/// Minimale, alleen-lezen spiegel van Trip/SavedFlightRecord (hoofdapp),
/// puur voor weergave op het tvOS-vertrekbord — geen eigen opslag- of
/// wijzigingslogica, dus bewust niet de echte TripsStore/FlightsStore
/// hergebruikt (die slepen Theme.swift-afhankelijke views en haptics mee die
/// niet op tvOS bestaan). Decodeert dezelfde iCloud-blobs die de hoofdapp al
/// synchroniseert (NSUbiquitousKeyValueStore, keys "vt_saved_trips" en
/// "vt_saved_flights") — Codable negeert onbekende/ontbrekende velden, dus
/// deze mogen gerust een subset van de echte velden bevatten.
struct TVTrip: Codable, Identifiable {
    var id = UUID()
    var name: String
    var destination: String?
    var startDate: Date
    var endDate: Date
    var isHidden: Bool = false

    var isPast: Bool { endDate < Date() }

    var daysUntilStart: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: startDate)
        ).day ?? 0
    }
}

struct TVFlight: Codable, Identifiable {
    var id = UUID()
    var number: String
    var airlineName: String?
    var airlineSlug: String?
    var departure: Date
    var departureIata: String?
    var departureAirport: String?
    var arrivalIata: String?
    var arrivalAirport: String?

    var isPast: Bool { departure < Date() }
}

/// Leest de door de telefoon-app gesynchroniseerde reis/vlucht rechtstreeks
/// uit iCloud — geen eigen sync-protocol nodig zoals CloudSync.swift op
/// iOS (dat is voor twee-richtingsverkeer; het tv-scherm schrijft nooit
/// terug, dus is een simpele, verse lezing bij elke refresh voldoende.
@MainActor
final class TVSavedData: ObservableObject {
    static let shared = TVSavedData()

    @Published private(set) var nextTrip: TVTrip?
    @Published private(set) var nextFlight: TVFlight?
    @Published private(set) var lastUpdated = Date()

    private let cloud = NSUbiquitousKeyValueStore.default
    private var started = false

    private init() {}

    func start() {
        guard !started else { refresh(); return }
        started = true
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        #if DEBUG
        seedDummyDataForTesting()
        #endif
        cloud.synchronize()
        refresh()
    }

    #if DEBUG
    /// Tijdelijke testhulp: de Simulator heeft geen ingelogd iCloud-account,
    /// dus de echte sync vanaf de telefoon (zie VliegtuigtasApp.swift'
    /// seedDummyDataForTesting, dezelfde vijf reis/vlucht-paren) komt hier
    /// nooit vanzelf aan. Zet diezelfde voorbeelddata rechtstreeks lokaal
    /// klaar, puur om het bord te kunnen zien — overschrijft nooit al
    /// aanwezige (echt gesyncte) data.
    private func seedDummyDataForTesting() {
        guard cloud.data(forKey: "vt_saved_trips") == nil,
              cloud.data(forKey: "vt_saved_flights") == nil else { return }

        let cal = Calendar.current
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: .now) ?? .now }
        func at(_ date: Date, _ hour: Int, _ minute: Int) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        }

        let trips = [
            TVTrip(name: "Rome", destination: "Rome, Italië", startDate: days(5), endDate: days(9)),
            TVTrip(name: "Barcelona", destination: "Barcelona, Spanje", startDate: days(15), endDate: days(19)),
            TVTrip(name: "Lissabon", destination: "Lissabon, Portugal", startDate: days(30), endDate: days(35)),
            TVTrip(name: "Londen", destination: "Londen, Verenigd Koninkrijk", startDate: days(-20), endDate: days(-16)),
            TVTrip(name: "New York", destination: "New York, Verenigde Staten", startDate: days(60), endDate: days(70))
        ]
        let flights = [
            TVFlight(number: "KL1595", airlineName: "KLM", airlineSlug: "klm",
                     departure: at(days(5), 9, 15), departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                     arrivalIata: "FCO", arrivalAirport: "Rome Fiumicino"),
            TVFlight(number: "VY8438", airlineName: "Vueling", airlineSlug: "vueling",
                     departure: at(days(15), 7, 40), departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                     arrivalIata: "BCN", arrivalAirport: "Barcelona El Prat"),
            TVFlight(number: "TP653", airlineName: "TAP Air Portugal", airlineSlug: "tap-air-portugal",
                     departure: at(days(30), 11, 5), departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                     arrivalIata: "LIS", arrivalAirport: "Lissabon Humberto Delgado"),
            TVFlight(number: "BA430", airlineName: "British Airways", airlineSlug: "british-airways",
                     departure: at(days(-20), 8, 30), departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                     arrivalIata: "LHR", arrivalAirport: "Londen Heathrow"),
            TVFlight(number: "KL643", airlineName: "KLM", airlineSlug: "klm",
                     departure: at(days(60), 13, 20), departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                     arrivalIata: "JFK", arrivalAirport: "New York JFK")
        ]

        if let tripData = try? JSONEncoder().encode(trips) {
            cloud.set(tripData, forKey: "vt_saved_trips")
        }
        if let flightData = try? JSONEncoder().encode(flights) {
            cloud.set(flightData, forKey: "vt_saved_flights")
        }
    }
    #endif

    func refresh() {
        cloud.synchronize()

        if let data = cloud.data(forKey: "vt_saved_trips"),
           let trips = try? JSONDecoder().decode([TVTrip].self, from: data) {
            nextTrip = trips
                .filter { !$0.isHidden && !$0.isPast }
                .sorted { $0.startDate < $1.startDate }
                .first
        } else {
            nextTrip = nil
        }

        if let data = cloud.data(forKey: "vt_saved_flights"),
           let flights = try? JSONDecoder().decode([TVFlight].self, from: data) {
            nextFlight = flights
                .filter { !$0.isPast }
                .sorted { $0.departure < $1.departure }
                .first
        } else {
            nextFlight = nil
        }

        lastUpdated = Date()
    }
}
