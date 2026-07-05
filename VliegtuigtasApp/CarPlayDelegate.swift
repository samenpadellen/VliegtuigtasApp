#if canImport(CarPlay) && !targetEnvironment(macCatalyst)
import CarPlay
import Foundation

/// CarPlay: onderweg naar de luchthaven in één oogopslag je vlucht en je
/// tassenstatus — geen bediening nodig, puur glanceable informatie.
///
/// ⚠️ Vereist het door Apple toegekende entitlement
/// `com.apple.developer.carplay-driving-task`. Aanvragen via
/// https://developer.apple.com/contact/carplay/ (categorie: driving task).
/// Tot die toekenning is deze scene inert: de code schaadt niets en de
/// App Store negeert de declaratie zonder entitlement.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(makeRootTemplate(), animated: true, completion: nil)      
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Template

    private func makeRootTemplate() -> CPTemplate {
        var items: [CPInformationItem] = []

        // Vlucht: nummer, route en aftelling
        if let flight = SharedFlightStore.loadFlight() {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "nl_NL")
            let relative = formatter.localizedString(for: flight.departure, relativeTo: Date())

            var title = flight.number
            if let route = flight.routeLabel { title += "  ·  \(route)" }
            items.append(CPInformationItem(
                title: title,
                detail: "Vertrek \(relative)" + (flight.airlineName.map { " · \($0)" } ?? "")
            ))
        } else {
            items.append(CPInformationItem(
                title: "Geen vlucht opgeslagen",
                detail: "Zoek je vluchtnummer op in de app voor de aftelling."
            ))
        }

        // Tassen: aantal + namen (rechtstreeks uit UserDefaults, zodat we
        // hier geen MainActor-store hoeven aan te raken)
        let bags = Self.savedBags()
        if bags.isEmpty {
            items.append(CPInformationItem(
                title: "Nog geen tassen toegevoegd",
                detail: "Voeg je tassen toe in de app en zie hier of alles mee mag."
            ))
        } else {
            let names = bags.prefix(3).map(\.name).joined(separator: ", ")
            items.append(CPInformationItem(
                title: bags.count == 1 ? "1 tas aan boord" : "\(bags.count) tassen aan boord",
                detail: names + (bags.count > 3 ? " en meer" : "")
            ))
        }

        items.append(CPInformationItem(
            title: "Veilige reis ✈︎",
            detail: "Check je handbagage vóór vertrek in de Vliegtuigtas-app."
        ))

        return CPInformationTemplate(
            title: "Vliegtuigtas",
            layout: .leading,
            items: items,
            actions: []
        )
    }

    /// Tassen lezen zonder de @MainActor-store: zelfde sleutel, zelfde JSON.
    private static func savedBags() -> [SavedBag] {
        guard let data = UserDefaults.standard.data(forKey: BagCollectionStore.storageKey),
              let bags = try? JSONDecoder().decode([SavedBag].self, from: data) else { return [] }
        return bags
    }
}
#endif
