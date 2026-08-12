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
        cloud.synchronize()
        refresh()
    }

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
