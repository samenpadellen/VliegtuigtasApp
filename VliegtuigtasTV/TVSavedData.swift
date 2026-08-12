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
    /// seedDummyDataForTesting) komt hier nooit vanzelf aan. Zet dezelfde
    /// voorbeeldreis/-vlucht rechtstreeks lokaal klaar, puur om het bord
    /// te kunnen zien — overschrijft nooit al aanwezige (echt gesyncte) data.
    private func seedDummyDataForTesting() {
        guard cloud.data(forKey: "vt_saved_trips") == nil,
              cloud.data(forKey: "vt_saved_flights") == nil else { return }

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: 5, to: .now) ?? .now
        let end = cal.date(byAdding: .day, value: 9, to: .now) ?? .now
        let departure = cal.date(bySettingHour: 9, minute: 15, second: 0, of: start) ?? start

        let trip = TVTrip(name: "Rome", destination: "Rome, Italië", startDate: start, endDate: end)
        let flight = TVFlight(
            number: "KL1595", airlineName: "KLM", airlineSlug: "klm",
            departure: departure, departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
            arrivalIata: "FCO", arrivalAirport: "Rome Fiumicino"
        )
        if let tripData = try? JSONEncoder().encode([trip]) {
            cloud.set(tripData, forKey: "vt_saved_trips")
        }
        if let flightData = try? JSONEncoder().encode([flight]) {
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
