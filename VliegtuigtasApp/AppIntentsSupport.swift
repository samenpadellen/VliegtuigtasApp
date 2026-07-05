import AppIntents
import CoreSpotlight
import SwiftUI
import UIKit

// MARK: - AirlineEntity

/// Vliegmaatschappij als App Entity: bruikbaar als parameter in Shortcuts,
/// Siri ("bagageregels van Ryanair") en — op iOS 18+ — vindbaar via Spotlight.
struct AirlineEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Vliegmaatschappij"
    static var defaultQuery = AirlineEntityQuery()

    /// Slug uit de Vliegtuigtas-database (stabiel, ook als de naam wijzigt).
    var id: String
    var name: String
    var flagEmoji: String?

    init(airline: Airline) {
        id = airline.slug
        name = airline.name
        flagEmoji = airline.flagEmoji
    }

    var displayRepresentation: DisplayRepresentation {
        if let flagEmoji {
            return DisplayRepresentation(
                title: "\(name)",
                subtitle: "\(flagEmoji) Bagageregels",
                image: .init(systemName: "airplane")
            )
        }
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "Bagageregels",
            image: .init(systemName: "airplane")
        )
    }
}

@available(iOS 18.0, *)
extension AirlineEntity: IndexedEntity {}

struct AirlineEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [AirlineEntity] {
        let airlines = try await APIClient.shared.airlines()
        return airlines.filter { identifiers.contains($0.slug) }.map(AirlineEntity.init)
    }

    func entities(matching string: String) async throws -> [AirlineEntity] {
        let airlines = try await APIClient.shared.airlines()
        return airlines
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(AirlineEntity.init)
    }

    func suggestedEntities() async throws -> [AirlineEntity] {
        let airlines = try await APIClient.shared.airlines()
        return airlines
            .sorted { ($0.sortOrder ?? .max, $0.name) < ($1.sortOrder ?? .max, $1.name) }
            .prefix(10)
            .map(AirlineEntity.init)
    }
}

private func resolveAirline(_ entity: AirlineEntity) async throws -> Airline {
    let airlines = try await APIClient.shared.airlines()
    guard let airline = airlines.first(where: { $0.slug == entity.id }) else {
        throw VliegtuigtasIntentError.airlineNotFound
    }
    return airline
}

enum VliegtuigtasIntentError: Error, CustomLocalizedStringResourceConvertible {
    case airlineNotFound
    case bagNotFound
    case noDataConnection

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .airlineNotFound:  return "Deze maatschappij staat niet in de Vliegtuigtas-database."
        case .bagNotFound:      return "Deze tas staat niet meer in je profiel. Voeg hem opnieuw toe in de app."
        case .noDataConnection: return "De bagageregels konden niet worden opgehaald. Controleer je internetverbinding."
        }
    }
}

// MARK: - Intent: handbagage checken

struct CheckBagIntent: AppIntent {
    static var title: LocalizedStringResource = "Check mijn handbagage"
    static var description = IntentDescription(
        "Controleert of jouw tas als handbagage past bij een vliegmaatschappij.",
        categoryName: "Bagagecheck"
    )

    @Parameter(title: "Maatschappij")
    var airline: AirlineEntity

    @Parameter(title: "Lengte (cm)")
    var lengte: Double

    @Parameter(title: "Breedte (cm)")
    var breedte: Double

    @Parameter(title: "Diepte (cm)")
    var diepte: Double

    @Parameter(title: "Gewicht (kg)")
    var gewicht: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Check een tas van \(\.$lengte) × \(\.$breedte) × \(\.$diepte) cm en \(\.$gewicht) kg bij \(\.$airline)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let result: CheckResponse
        do {
            result = try await APIClient.shared.check(
                airlineSlug: airline.id,
                length: lengte, width: breedte, depth: diepte, weight: gewicht
            )
        } catch {
            throw VliegtuigtasIntentError.noDataConnection
        }
        APIClient.shared.sendEvent("bag_check", path: "/intent/check")

        let dialog = IntentDialog(stringLiteral: "\(result.verdictTitle) \(result.verdictMessage)")
        return .result(dialog: dialog, view: CheckResultSnippet(airlineName: airline.name, result: result))
    }
}

// MARK: - Intent: bagageregels opvragen

struct BagageRegelsIntent: AppIntent {
    static var title: LocalizedStringResource = "Bagageregels opzoeken"
    static var description = IntentDescription(
        "Toont de handbagageregels van een vliegmaatschappij.",
        categoryName: "Bagagecheck"
    )

    @Parameter(title: "Maatschappij")
    var airline: AirlineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Toon de bagageregels van \(\.$airline)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let resolved = try await resolveAirline(airline)

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

        return .result(
            dialog: IntentDialog(stringLiteral: spoken),
            view: AirlineRulesSnippet(airline: resolved)
        )
    }
}

// MARK: - Intent: opgeslagen vlucht

struct MijnVluchtIntent: AppIntent {
    static var title: LocalizedStringResource = "Wanneer vertrekt mijn vlucht?"
    static var description = IntentDescription(
        "Vertelt wanneer je opgeslagen vlucht vertrekt.",
        categoryName: "Vlucht"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let flight = SharedFlightStore.loadFlight() else {
            return .result(dialog: "Je hebt nog geen vlucht opgeslagen. Zoek een vluchtnummer op in de app en zet hem in de widget.")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        let relative = formatter.localizedString(for: flight.departure, relativeTo: Date())

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "nl_NL")
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        var text = "Vlucht \(flight.number)"
        if let airlineName = flight.airlineName {
            text += " met \(airlineName)"
        }
        if let dep = flight.route.departureAirport, let arr = flight.route.arrivalAirport {
            text += " van \(dep) naar \(arr)"
        }
        text += " vertrekt \(relative), op \(dateFormatter.string(from: flight.departure))."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

// MARK: - Intent: checker openen in de app

struct OpenCheckerIntent: AppIntent {
    static var title: LocalizedStringResource = "Open de bagagecheck"
    static var description = IntentDescription(
        "Opent Vliegtuigtas op het checkscherm, eventueel met een maatschappij voorgeselecteerd.",
        categoryName: "Bagagecheck"
    )
    static let openAppWhenRun = true

    @Parameter(title: "Maatschappij")
    var airline: AirlineEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Hergebruikt de bestaande widget-deeplink zodat app-navigatie op
        // één plek blijft (ContentView.onOpenURL). openAppWhenRun zorgt dat
        // de app al op de voorgrond staat wanneer dit draait; OpenURLIntent
        // zou netter zijn maar vereist iOS 18 (app-target is 17.6).
        var urlString = "vliegtuigtas://check"
        if let slug = airline?.id {
            urlString += "?airline=\(slug)"
        }
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        return .result()
    }
}

// MARK: - SavedBagEntity (jouw eigen tassen als Siri-parameter)

/// Opgeslagen tas als App Entity: "Hey Siri, past mijn rode trolley bij KLM?"
/// werkt hiermee letterlijk — Siri herkent je eigen tasnamen als parameter.
struct SavedBagEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mijn tas"
    static var defaultQuery = SavedBagEntityQuery()

    var id: String
    var name: String
    var dimsLabel: String
    var weight: Double

    init(bag: SavedBag) {
        id = bag.id.uuidString
        name = bag.name
        dimsLabel = bag.dimsLabel
        weight = bag.weight
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(dimsLabel) · \(weight.formatted()) kg",
            image: .init(systemName: "suitcase.rolling.fill")
        )
    }
}

struct SavedBagEntityQuery: EntityStringQuery {
    @MainActor
    private func allBags() -> [SavedBag] { BagCollectionStore.shared.bags }

    func entities(for identifiers: [String]) async throws -> [SavedBagEntity] {
        await allBags()
            .filter { identifiers.contains($0.id.uuidString) }
            .map(SavedBagEntity.init)
    }

    func entities(matching string: String) async throws -> [SavedBagEntity] {
        await allBags()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(SavedBagEntity.init)
    }

    func suggestedEntities() async throws -> [SavedBagEntity] {
        await allBags().map(SavedBagEntity.init)
    }
}

// MARK: - Intent: past mijn eigen tas?

struct CheckSavedBagIntent: AppIntent {
    static var title: LocalizedStringResource = "Past mijn eigen tas?"
    static var description = IntentDescription(
        "Checkt of een van je opgeslagen tassen mee mag bij een vliegmaatschappij.",
        categoryName: "Bagagecheck"
    )

    @Parameter(title: "Tas")
    var bag: SavedBagEntity

    @Parameter(title: "Maatschappij")
    var airline: AirlineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Check of \(\.$bag) mee mag bij \(\.$airline)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let resolved = try await resolveAirline(airline)
        guard let savedBag = await MainActor.run(body: {
            BagCollectionStore.shared.bags.first { $0.id.uuidString == bag.id }
        }) else {
            throw VliegtuigtasIntentError.bagNotFound
        }

        let fit = BagAirlineFit.evaluate(bag: savedBag, airline: resolved)
        let spoken: String
        if fit.allowedInCabin {
            spoken = fit.underSeat == true && fit.cabinBag != true
                ? "Ja: \(savedBag.name) mag mee bij \(resolved.name), onder de stoel."
                : "Ja: \(savedBag.name) mag mee in de cabine bij \(resolved.name)."
        } else if fit.withinWeight == false {
            spoken = "\(savedBag.name) is te zwaar voor de cabine bij \(resolved.name) (max \(Int(fit.maxWeightKg ?? 0)) kg): inchecken als ruimbagage."
        } else {
            spoken = "\(savedBag.name) past niet in de cabine bij \(resolved.name): inchecken als ruimbagage."
        }

        return .result(
            dialog: IntentDialog(stringLiteral: spoken),
            view: SavedBagFitSnippet(bagName: savedBag.name, airlineName: resolved.name, fit: fit)
        )
    }
}

// MARK: - Intent: vlucht toevoegen via Siri

struct VluchtToevoegenIntent: AppIntent {
    static var title: LocalizedStringResource = "Vlucht toevoegen"
    static var description = IntentDescription(
        "Slaat een vlucht op in Vliegtuigtas: de aftelling verschijnt op je widget, smartwatch en lockscreen.",
        categoryName: "Vlucht"
    )

    @Parameter(title: "Vluchtnummer")
    var vluchtnummer: String

    @Parameter(title: "Vertrek")
    var vertrek: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Voeg vlucht \(\.$vluchtnummer) toe met vertrek op \(\.$vertrek)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard UserSession.shared.hasAccount else {
            return .result(dialog: "Vluchten opslaan werkt met een profiel. Maak er gratis één aan in de app, dan sync je vlucht ook naar je widget en smartwatch.")
        }

        let number = vluchtnummer.trimmingCharacters(in: .whitespaces).uppercased()
        // Best effort: de lookup verrijkt de vlucht met route en maatschappij,
        // maar zonder netwerk slaan we het nummer + vertrek gewoon kaal op.
        let lookup = try? await APIClient.shared.flightLookup(number: number)

        let record = SavedFlightRecord(
            number: lookup?.flightNumber ?? number,
            airlineName: lookup?.resolvedAirline?.name ?? lookup?.rawAirlineName,
            airlineSlug: lookup?.resolvedAirline?.slug,
            airlineLogoUrl: lookup?.resolvedAirline?.bestLogoUrl ?? lookup?.airlineLogoUrl,
            flightIcao: lookup?.flightIcao,
            departure: vertrek,
            departureIata: lookup?.departureIata,
            departureAirport: lookup?.departureAirport,
            arrivalIata: lookup?.arrivalIata,
            arrivalAirport: lookup?.arrivalAirport,
            flightDate: lookup?.flightDate,
            status: lookup?.status
        )
        await MainActor.run { FlightsStore.shared.upsert(record) }

        var text = "Vlucht \(record.number)"
        if let airlineName = record.airlineName { text += " met \(airlineName)" }
        if let route = record.routeLabel { text += " (\(route))" }
        text += " staat erin. De aftelling loopt mee op je widget."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

// MARK: - Intent: inpak-alarm zetten (AppEnum als parameter)

/// Bestaande alarmsoorten als AppEnum: Siri en Shortcuts tonen ze als
/// nette keuzelijst met Nederlandse labels.
extension PackingAlarmKind: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Reismoment"

    static var caseDisplayRepresentations: [PackingAlarmKind: DisplayRepresentation] = [
        .checkBag: DisplayRepresentation(title: "Koffer controleren", image: .init(systemName: "checkmark.shield.fill")),
        .buyBag:   DisplayRepresentation(title: "Nieuwe koffer aanschaffen", image: .init(systemName: "bag.fill")),
        .pack:     DisplayRepresentation(title: "Inpakken", image: .init(systemName: "suitcase.rolling.fill")),
        .dropOff:  DisplayRepresentation(title: "Koffer afgeven of ophalen", image: .init(systemName: "person.2.fill"))
    ]
}

struct ZetInpakAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Zet een inpak-alarm"
    static var description = IntentDescription(
        "Zet een alarm voor een reismoment: inpakken, je koffer controleren of afgeven.",
        categoryName: "Vlucht"
    )

    @Parameter(title: "Reismoment")
    var moment: PackingAlarmKind

    @Parameter(title: "Wanneer")
    var wanneer: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Zet een alarm voor \(\.$moment) op \(\.$wanneer)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let departure = SharedFlightStore.loadFlight()?.departure
        let date = wanneer ?? moment.defaultDate(departure: departure)
        guard date > .now else {
            return .result(dialog: "Dat moment is al geweest. Kies een tijdstip in de toekomst.")
        }

        let result = await PackingAlarmScheduler.schedule(kind: moment, at: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let what = result == .alarm ? "Alarm" : "Herinnering"
        return .result(dialog: IntentDialog(stringLiteral:
            "\(what) gezet: \(moment.title.lowercased()) op \(formatter.string(from: date))."
        ))
    }
}

// MARK: - Snippet views (resultaatkaarten in Siri/Shortcuts)

private struct SavedBagFitSnippet: View {
    let bagName: String
    let airlineName: String
    let fit: BagAirlineFit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: fit.allowedInCabin ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(fit.allowedInCabin ? Theme.green : Theme.red)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bagName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(airlineName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.navy)
                }
                Spacer()
            }

            HStack(spacing: 14) {
                fitBadge("Onder de stoel", fit.underSeat)
                fitBadge("Bagagevak", fit.cabinBag)
                if fit.maxWeightKg != nil {
                    fitBadge("Gewicht", fit.withinWeight)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fitBadge(_ label: String, _ status: Bool?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status == true ? "checkmark.circle.fill"
                    : (status == false ? "xmark.circle.fill" : "minus.circle"))
                .font(.system(size: 11))
                .foregroundStyle(status == true ? Theme.green
                    : (status == false ? Theme.red : Theme.textSecondary))
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

private struct CheckResultSnippet: View {
    let airlineName: String
    let result: CheckResponse

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.verdictColor(result.verdict))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.verdictTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(result.verdictMessage)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(airlineName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.navy)
            }
            Spacer()
        }
        .padding(16)
    }

    private var iconName: String {
        switch result.verdict {
        case .ok:      return "checkmark.seal.fill"
        case .warning: return "questionmark.circle.fill"
        case .fail:    return "xmark.seal.fill"
        }
    }
}

private struct AirlineRulesSnippet: View {
    let airline: Airline

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let flag = airline.flagEmoji { Text(flag) }
                Text(airline.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }

            ForEach((airline.variants ?? []).prefix(3)) { variant in
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.variantName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.navy)
                    HStack(spacing: 12) {
                        if variant.smallLCm != nil {
                            Label(variant.smallDimString, systemImage: "backpack")
                        }
                        if variant.includesLargeBag == true, variant.largeLCm != nil {
                            Label(variant.largeDimString, systemImage: "bag")
                        }
                        if let kg = variant.maxWeightKg {
                            Label("\(Int(kg)) kg", systemImage: "scalemass")
                        }
                    }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - App Shortcuts (Siri-zinnen, Shortcuts-app, Spotlight)

struct VliegtuigtasShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckBagIntent(),
            phrases: [
                "Check mijn tas met \(.applicationName)",
                "Controleer mijn handbagage met \(.applicationName)",
                "Past mijn tas met \(.applicationName)"
            ],
            shortTitle: "Check handbagage",
            systemImageName: "checkmark.shield.fill"
        )
        AppShortcut(
            intent: BagageRegelsIntent(),
            phrases: [
                "Bagageregels in \(.applicationName)",
                "Bagageregels van \(\.$airline) in \(.applicationName)",
                "Wat mag mee bij \(\.$airline) volgens \(.applicationName)"
            ],
            shortTitle: "Bagageregels",
            systemImageName: "list.clipboard"
        )
        AppShortcut(
            intent: MijnVluchtIntent(),
            phrases: [
                "Wanneer vertrekt mijn vlucht volgens \(.applicationName)",
                "Mijn vlucht in \(.applicationName)"
            ],
            shortTitle: "Mijn vlucht",
            systemImageName: "airplane.departure"
        )
        AppShortcut(
            intent: OpenCheckerIntent(),
            phrases: [
                "Open de bagagecheck in \(.applicationName)"
            ],
            shortTitle: "Open checker",
            systemImageName: "arrow.up.forward.app"
        )
        AppShortcut(
            intent: CheckSavedBagIntent(),
            phrases: [
                "Past mijn \(\.$bag) volgens \(.applicationName)",
                "Mag mijn \(\.$bag) mee volgens \(.applicationName)",
                "Check mijn eigen tas in \(.applicationName)"
            ],
            shortTitle: "Past mijn tas?",
            systemImageName: "suitcase.rolling.fill"
        )
        AppShortcut(
            intent: VluchtToevoegenIntent(),
            phrases: [
                "Voeg een vlucht toe aan \(.applicationName)",
                "Nieuwe vlucht in \(.applicationName)"
            ],
            shortTitle: "Vlucht toevoegen",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: ZetInpakAlarmIntent(),
            phrases: [
                "Zet een inpak-alarm met \(.applicationName)",
                "Herinner me aan het inpakken met \(.applicationName)"
            ],
            shortTitle: "Inpak-alarm",
            systemImageName: "alarm.fill"
        )
    }
}

// MARK: - Donaties (Spotlight + parameterized Siri-zinnen)

enum IntentDonations {
    /// Aanroepen zodra de maatschappijenlijst geladen is: indexeert entities in
    /// Spotlight (iOS 18+) en laat Siri de zinnen met maatschappijnamen leren.
    static func airlinesLoaded(_ airlines: [Airline]) {
        Task.detached(priority: .background) {
            if #available(iOS 18.0, *) {
                try? await CSSearchableIndex.default()
                    .indexAppEntities(airlines.map(AirlineEntity.init))
            }
            VliegtuigtasShortcuts.updateAppShortcutParameters()
        }
    }
}
