import SwiftUI
import WidgetKit

@main
struct VliegtuigtasWatchApp: App {
    @StateObject private var airlineStore = AirlineStore()
    @StateObject private var bagStore = WatchBagStore.shared

    init() { AppFont.register() }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(airlineStore)
                .environmentObject(bagStore)
                .onAppear {
                    WatchFlightSync.shared.start()
                }
        }
    }
}

/// Haalt de opgeslagen vlucht van de iPhone binnen via de gedeelde iCloud
/// key-value store en zet hem in de App Group, zodat de wijzerplaat-widget
/// erbij kan. Zelfde sleutelnamen als op iOS.
final class WatchFlightSync {
    static let shared = WatchFlightSync()

    private let cloud = NSUbiquitousKeyValueStore.default
    private let group = UserDefaults(suiteName: "group.com.vliegtuigtas.app")
    private var started = false

    private init() {}

    func start() {
        guard !started else {
            cloud.synchronize()
            adopt()
            return
        }
        started = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        cloud.synchronize()
        adopt()
    }

    @objc private func cloudChanged(_ note: Notification) {
        adopt()
    }

    private func adopt() {
        guard let group else { return }
        let number = cloud.string(forKey: "vt_shared_flight_number") ?? ""
        let departure = cloud.double(forKey: "vt_shared_flight_departure")

        if !number.isEmpty, departure > 0 {
            group.set(number, forKey: "vt_shared_flight_number")
            group.set(cloud.string(forKey: "vt_shared_flight_airline"), forKey: "vt_shared_flight_airline")
            group.set(departure, forKey: "vt_shared_flight_departure")
            group.set(cloud.string(forKey: "vt_shared_flight_dep_iata"), forKey: "vt_shared_flight_dep_iata")
            group.set(cloud.string(forKey: "vt_shared_flight_arr_iata"), forKey: "vt_shared_flight_arr_iata")
        } else {
            ["vt_shared_flight_number", "vt_shared_flight_airline", "vt_shared_flight_departure",
             "vt_shared_flight_dep_iata", "vt_shared_flight_arr_iata"]
                .forEach { group.removeObject(forKey: $0) }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
