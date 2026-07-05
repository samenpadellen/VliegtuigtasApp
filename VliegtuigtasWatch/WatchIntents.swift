import AppIntents
import Foundation

// MARK: - App Intents op de Watch
//
// Siri op je pols: "Wat mag mee bij Ryanair?" en "Wanneer vertrekt mijn
// vlucht?" werken rechtstreeks op de Apple Watch, zonder iPhone erbij.
// De watch-app compileert Models/APIClient/AirlineStore al mee, dus de
// regels komen uit dezelfde bron als op iOS.

// MARK: Entity

struct WatchAirlineEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Vliegmaatschappij"
    static var defaultQuery = WatchAirlineQuery()

    var id: String   // slug
    var name: String

    init(airline: Airline) {
        id = airline.slug
        name = airline.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: "airplane"))
    }
}

struct WatchAirlineQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [WatchAirlineEntity] {
        let airlines = try await APIClient.shared.airlines()
        return airlines.filter { identifiers.contains($0.slug) }.map(WatchAirlineEntity.init)
    }

    func entities(matching string: String) async throws -> [WatchAirlineEntity] {
        let airlines = try await APIClient.shared.airlines()
        return airlines
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(WatchAirlineEntity.init)
    }

    func suggestedEntities() async throws -> [WatchAirlineEntity] {
        let airlines = try await APIClient.shared.airlines()
        return airlines
            .sorted { ($0.sortOrder ?? .max, $0.name) < ($1.sortOrder ?? .max, $1.name) }
            .prefix(8)
            .map(WatchAirlineEntity.init)
    }
}

// MARK: Intent: bagageregels op je pols

struct WatchBagageRegelsIntent: AppIntent {
    static var title: LocalizedStringResource = "Bagageregels opzoeken"
    static var description = IntentDescription(
        "Vertelt de handbagageregels van een vliegmaatschappij, direct op je pols.",
        categoryName: "Bagagecheck"
    )

    @Parameter(title: "Maatschappij")
    var airline: WatchAirlineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Toon de bagageregels van \(\.$airline)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let airlines = try await APIClient.shared.airlines()
        guard let resolved = airlines.first(where: { $0.slug == airline.id }) else {
            return .result(dialog: "Deze maatschappij staat niet in de Vliegtuigtas-database.")
        }

        var spoken = "Bij \(resolved.name)"
        if let variant = resolved.variants?.first {
            if variant.smallLCm != nil {
                spoken += " mag een klein item van \(variant.smallDimString) mee"
            }
            if variant.includesLargeBag == true, variant.largeLCm != nil {
                spoken += " en grote handbagage van \(variant.largeDimString)"
            }
            if let kg = variant.maxWeightKg {
                spoken += ", maximaal \(Int(kg)) kg"
            }
            spoken += " (tarief \(variant.variantName))."
        } else {
            spoken += " zijn geen bagageregels bekend."
        }
        return .result(dialog: IntentDialog(stringLiteral: spoken))
    }
}

// MARK: Intent: mijn vlucht op je pols

struct WatchMijnVluchtIntent: AppIntent {
    static var title: LocalizedStringResource = "Wanneer vertrekt mijn vlucht?"
    static var description = IntentDescription(
        "Vertelt wanneer je opgeslagen vlucht vertrekt, direct op je pols.",
        categoryName: "Vlucht"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Dezelfde App Group-sleutels die WatchFlightSync vanuit iCloud vult.
        let suite = UserDefaults(suiteName: "group.com.vliegtuigtas.app")
        guard let number = suite?.string(forKey: "vt_shared_flight_number"), !number.isEmpty,
              let stamp = suite?.double(forKey: "vt_shared_flight_departure"), stamp > 0 else {
            return .result(dialog: "Je hebt nog geen vlucht opgeslagen. Doe dat in de iPhone-app, dan sync hij vanzelf naar je Watch.")
        }
        let departure = Date(timeIntervalSince1970: stamp)

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        let relative = formatter.localizedString(for: departure, relativeTo: Date())

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "nl_NL")
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        var text = "Vlucht \(number)"
        if let airlineName = suite?.string(forKey: "vt_shared_flight_airline"), !airlineName.isEmpty {
            text += " met \(airlineName)"
        }
        text += " vertrekt \(relative), op \(dateFormatter.string(from: departure))."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

// MARK: App Shortcuts (Siri-zinnen op watchOS)

struct WatchVliegtuigtasShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WatchBagageRegelsIntent(),
            phrases: [
                "Bagageregels in \(.applicationName)",
                "Bagageregels van \(\.$airline) in \(.applicationName)",
                "Wat mag mee bij \(\.$airline) volgens \(.applicationName)"
            ],
            shortTitle: "Bagageregels",
            systemImageName: "list.clipboard"
        )
        AppShortcut(
            intent: WatchMijnVluchtIntent(),
            phrases: [
                "Wanneer vertrekt mijn vlucht volgens \(.applicationName)",
                "Mijn vlucht in \(.applicationName)"
            ],
            shortTitle: "Mijn vlucht",
            systemImageName: "airplane.departure"
        )
    }
}
