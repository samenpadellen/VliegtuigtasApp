#if canImport(CarPlay) && !targetEnvironment(macCatalyst)
import CarPlay
import UIKit
import Foundation

// MARK: - Data (los van de @MainActor-stores: rechtstreeks uit UserDefaults)

/// De CarPlay-scene draait in het app-proces, dus dezelfde UserDefaults en
/// dezelfde JSON als de app. We lezen bewust rechtstreeks i.p.v. de
/// @MainActor-stores aan te raken, zodat het bouwen van templates synchroon
/// en zonder actor-hops kan.
private enum CarPlayData {
    // Vaste UserDefaults-sleutels — dezelfde als FlightsStore/TripsStore/
    // BagCollectionStore.storageKey, hier als literal zodat de nonisolated
    // CarPlay-code niet de @MainActor-store-constanten hoeft aan te raken.
    private enum Key {
        static let flights = "vt_saved_flights"
        static let trips = "vt_saved_trips"
        static let bags = "vt_saved_bags"
    }

    static func flights() -> [SavedFlightRecord] {
        guard let data = UserDefaults.standard.data(forKey: Key.flights),
              let decoded = try? JSONDecoder().decode([SavedFlightRecord].self, from: data) else { return [] }
        return decoded.sorted { $0.departure < $1.departure }
    }

    static func upcomingFlights() -> [SavedFlightRecord] {
        flights().filter { !$0.isPast }
    }

    /// Verborgen reizen blijven ook in de auto verborgen. Zonder dit filter
    /// verscheen een verrassingsreis alsnog op het scherm in de auto — juist
    /// een plek waar iemand anders meekijkt.
    static func trips() -> [Trip] {
        guard let data = UserDefaults.standard.data(forKey: Key.trips),
              let decoded = try? JSONDecoder().decode([Trip].self, from: data) else { return [] }
        return decoded
            .filter { !$0.isHidden }
            .sorted { $0.startDate < $1.startDate }
    }

    static func nextTrip() -> Trip? {
        trips().first { !$0.isPast }
    }

    static func bags() -> [SavedBag] {
        guard let data = UserDefaults.standard.data(forKey: Key.bags),
              let decoded = try? JSONDecoder().decode([SavedBag].self, from: data) else { return [] }
        return decoded
    }

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.unitsStyle = .full
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EEE d MMM · HH:mm"
        return f
    }()
}

// MARK: - Scene delegate

/// CarPlay-driving-task app: onderweg naar de luchthaven je vlucht, reis en
/// tassen op één plek — glanceable én navigeerbaar. Een tabbalk met drie
/// tabs (Reis · Vluchten · Tassen), waar je op een vlucht kunt tikken voor
/// de volledige details (terminal, gate, status). Alles read-only en
/// zelf-verversend; geen netwerkverkeer vanuit de auto (dat gebeurt in de
/// app, hier tonen we de laatst bekende gegevens).
///
/// Gebruikt het entitlement `com.apple.developer.carplay-driving-task`.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    private var tripTemplate: CPInformationTemplate?
    private var flightsTemplate: CPListTemplate?
    private var bagsTemplate: CPInformationTemplate?
    private var refreshTimer: Timer?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(makeTabBar(), animated: true, completion: nil)

        // Live bijwerken: als de gebruiker in de app een vlucht/reis/tas
        // wijzigt (of iCloud-sync binnenkomt) verspringt UserDefaults, en de
        // countdown veroudert vanzelf — daarom ook een minuut-timer.
        NotificationCenter.default.addObserver(
            self, selector: #selector(dataDidChange),
            name: UserDefaults.didChangeNotification, object: nil
        )
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshContents()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        NotificationCenter.default.removeObserver(self)
        refreshTimer?.invalidate()
        refreshTimer = nil
        // Een al geplande refresh mag niet meer vuren nadat de auto is
        // losgekoppeld.
        NSObject.cancelPreviousPerformRequests(
            withTarget: self, selector: #selector(refreshContents), object: nil
        )
        self.interfaceController = nil
    }

    @objc private func dataDidChange() {
        // UserDefaults.didChangeNotification wordt niet gegarandeerd op de
        // hoofdthread gepost — iCloud-sync schrijft bijvoorbeeld vanaf een
        // achtergrondqueue. `perform(_:afterDelay:)` plant op de rúnloop van de
        // huidige thread, en die heeft een achtergrondthread meestal niet: de
        // refresh ging dan verloren en CarPlay bleef oude gegevens tonen.
        // Daarom eerst expliciet naar de hoofdthread, waar ook de
        // template-updates thuishoren.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Coalesce een reeks schrijfacties naar één refresh.
            NSObject.cancelPreviousPerformRequests(
                withTarget: self, selector: #selector(self.refreshContents), object: nil
            )
            self.perform(#selector(self.refreshContents), with: nil, afterDelay: 0.3)
        }
    }

    // MARK: - Tabbalk

    private func makeTabBar() -> CPTabBarTemplate {
        let trip = makeTripTemplate()
        trip.tabTitle = "Reis"
        trip.tabImage = UIImage(systemName: "suitcase.rolling.fill")
        tripTemplate = trip

        let flights = makeFlightsTemplate()
        flights.tabTitle = "Vluchten"
        flights.tabImage = UIImage(systemName: "airplane.departure")
        flightsTemplate = flights

        let bags = makeBagsTemplate()
        bags.tabTitle = "Tassen"
        bags.tabImage = UIImage(systemName: "bag.fill")
        bagsTemplate = bags

        return CPTabBarTemplate(templates: [trip, flights, bags])
    }

    @objc private func refreshContents() {
        tripTemplate?.items = tripItems()
        flightsTemplate?.updateSections(flightSections())
        bagsTemplate?.items = bagItems()
    }

    // MARK: - Tab 1: Reis (samenvatting)

    private func makeTripTemplate() -> CPInformationTemplate {
        CPInformationTemplate(title: "Volgende reis", layout: .leading, items: tripItems(), actions: [])
    }

    private func tripItems() -> [CPInformationItem] {
        var items: [CPInformationItem] = []

        if let trip = CarPlayData.nextTrip() {
            var detail = trip.countdownLabel
            if let dest = trip.destination, !dest.isEmpty { detail += " · \(dest)" }
            items.append(CPInformationItem(title: trip.name, detail: detail))

            let p = trip.progress
            if p.total > 0 {
                items.append(CPInformationItem(
                    title: "Paklijst",
                    detail: p.checked == p.total ? "Alles ingepakt ✓" : "\(p.checked)/\(p.total) ingepakt"
                ))
            }
        }

        if let flight = CarPlayData.upcomingFlights().first {
            let relative = CarPlayData.relativeFormatter.localizedString(for: flight.departure, relativeTo: Date())
            var detail = "Vertrek \(relative)"
            if let route = flight.routeLabel { detail += " · \(route)" }
            items.append(CPInformationItem(title: "Vlucht \(flight.number)", detail: detail))
            if let gate = flight.departureGate {
                let terminal = flight.departureTerminal.map { "Terminal \($0) · " } ?? ""
                items.append(CPInformationItem(title: "Gate", detail: "\(terminal)Gate \(gate)"))
            }
        }

        if items.isEmpty {
            items.append(CPInformationItem(
                title: "Nog niets gepland",
                detail: "Voeg een reis of vlucht toe in de Vliegtuigtas-app."
            ))
        }
        return items
    }

    // MARK: - Tab 2: Vluchten (lijst → detail)

    private func makeFlightsTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "Vluchten", sections: flightSections())
        template.emptyViewSubtitleVariants = ["Zoek je vluchtnummer op in de Vliegtuigtas-app."]
        return template
    }

    private func flightSections() -> [CPListSection] {
        let flights = CarPlayData.upcomingFlights()
        guard !flights.isEmpty else { return [] }

        let items: [CPListItem] = flights.map { flight in
            let relative = CarPlayData.relativeFormatter.localizedString(for: flight.departure, relativeTo: Date())
            var detail = "Vertrek \(relative)"
            if let route = flight.routeLabel { detail += " · \(route)" }
            if let statusLabel = flight.statusLabel { detail += " · \(statusLabel)" }

            let item = CPListItem(text: flight.number, detailText: detail)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.interfaceController?.pushTemplate(
                    self?.makeFlightDetail(flight) ?? CPInformationTemplate(title: flight.number, layout: .leading, items: [], actions: []),
                    animated: true, completion: nil
                )
                completion()
            }
            return item
        }
        return [CPListSection(items: items)]
    }

    private func makeFlightDetail(_ flight: SavedFlightRecord) -> CPInformationTemplate {
        var items: [CPInformationItem] = []

        if let route = flight.routeLabel {
            items.append(CPInformationItem(title: "Route", detail: route))
        }
        items.append(CPInformationItem(
            title: "Vertrek",
            detail: CarPlayData.timeFormatter.string(from: flight.departure)
        ))

        var depDetail: [String] = []
        if let t = flight.departureTerminal { depDetail.append("Terminal \(t)") }
        if let g = flight.departureGate { depDetail.append("Gate \(g)") }
        if let delay = flight.departureDelayMinutes, delay > 0 { depDetail.append("+\(delay) min vertraging") }
        if !depDetail.isEmpty {
            items.append(CPInformationItem(title: "Bij vertrek", detail: depDetail.joined(separator: " · ")))
        }

        var arrDetail: [String] = []
        if let t = flight.arrivalTerminal { arrDetail.append("Terminal \(t)") }
        if let g = flight.arrivalGate { arrDetail.append("Gate \(g)") }
        if let b = flight.arrivalBaggage { arrDetail.append("Bagageband \(b)") }
        if !arrDetail.isEmpty {
            items.append(CPInformationItem(title: "Bij aankomst", detail: arrDetail.joined(separator: " · ")))
        }

        if let status = flight.statusLabel {
            items.append(CPInformationItem(title: "Status", detail: status))
        }
        if let airline = flight.airlineName {
            items.append(CPInformationItem(title: "Maatschappij", detail: airline))
        }

        return CPInformationTemplate(title: flight.number, layout: .twoColumn, items: items, actions: [])
    }

    // MARK: - Tab 3: Tassen

    private func makeBagsTemplate() -> CPInformationTemplate {
        CPInformationTemplate(title: "Mijn tassen", layout: .leading, items: bagItems(), actions: [])
    }

    private func bagItems() -> [CPInformationItem] {
        let bags = CarPlayData.bags()
        guard !bags.isEmpty else {
            return [CPInformationItem(
                title: "Nog geen tassen",
                detail: "Voeg je tassen toe in de app en zie hier of alles mee mag."
            )]
        }
        return bags.map { bag in
            CPInformationItem(title: bag.name, detail: "\(bag.dimsLabel) · \(bag.weight.formatted()) kg")
        }
    }
}
#endif
