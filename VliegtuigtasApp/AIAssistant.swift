import Foundation
import SwiftUI
import WidgetKit

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Beschikbaarheid

/// Apple's on-device model (FoundationModels) vereist iOS 26 én een toestel
/// met Apple Intelligence. De app draait vanaf iOS 17.6, dus alle AI-features
/// zijn optioneel en verdwijnen stilletjes als het model er niet is.
@available(iOS 26.0, *)
enum AIAvailability {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Nederlandse uitleg waarom het model (nog) niet beschikbaar is.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Dit toestel ondersteunt Apple Intelligence niet."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Zet Apple Intelligence aan in Instellingen om de AI-assistent te gebruiken."
        case .unavailable(.modelNotReady):
            return "Het AI-model wordt nog gedownload. Probeer het straks opnieuw."
        case .unavailable:
            return "De AI-assistent is momenteel niet beschikbaar."
        }
    }
}

// MARK: - Regels als promptcontext

extension Airline {
    /// Compacte, feitelijke samenvatting van de bagageregels — als grounding
    /// voor het taalmodel zodat het niet zelf maten verzint.
    var aiRulesSummary: String {
        var lines: [String] = ["Maatschappij: \(name)"]
        if let l = personalItemLCm, let w = personalItemWCm, let d = personalItemDCm {
            lines.append("Persoonlijk item (onder de stoel): \(Int(l)) × \(Int(w)) × \(Int(d)) cm")
        }
        for variant in variants ?? [] {
            var parts: [String] = ["Tickettype '\(variant.variantName)':"]
            if variant.smallLCm != nil {
                parts.append("klein item \(variant.smallDimString)")
            }
            if variant.includesLargeBag == true, variant.largeLCm != nil {
                parts.append("grote handbagage \(variant.largeDimString)")
            } else if variant.includesLargeBag == false {
                parts.append("geen grote handbagage inbegrepen")
            }
            if let kg = variant.maxWeightKg {
                parts.append("max. \(Int(kg)) kg")
                if variant.weightRule == "combined" {
                    parts.append("(gewicht geldt voor alle stukken samen)")
                }
            }
            if let price = variant.priceIndicationEur {
                parts.append("prijsindicatie €\(Int(price))")
            }
            if variant.includesCheckedBag == true {
                var ruim = "incl. ruimbagage"
                if let kg = variant.checkedBagWeightKg { ruim += " (\(Int(kg)) kg)" }
                parts.append(ruim)
            }
            if variant.seatSelectionIncluded == true {
                parts.append("stoelkeuze inbegrepen")
            }
            if let notes = variant.notes, !notes.isEmpty {
                parts.append("(\(notes))")
            }
            lines.append(parts.joined(separator: " "))
        }
        if let included = checkedBagIncluded {
            lines.append("Ruimbagage standaard inbegrepen: \(included ? "ja" : "nee")")
        }
        if let kg = checkedBagMaxWeightKg {
            lines.append("Ruimbagage max. gewicht: \(Int(kg)) kg")
        }
        if let price = checkedBagPriceFromEur {
            lines.append("Ruimbagage vanaf €\(Int(price))")
        }
        if let fee = overweightFeePerKgEur {
            lines.append("Overgewicht: €\(Int(fee)) per kg")
        }
        if let fee = oversizeFeeEur {
            lines.append("Te grote tas bij de gate: €\(Int(fee))")
        }
        if let price = priorityBoardingPriceEur {
            lines.append("Priority boarding: €\(Int(price))")
        }
        if let alliance, !alliance.isEmpty {
            lines.append("Alliantie: \(alliance)")
        }
        if let url = baggagePolicyUrl {
            lines.append("Officiële bagagepagina: \(url)")
        }
        if let notes = extraNotes, !notes.isEmpty {
            lines.append("Let op: \(notes)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Tool: bagageregels opzoeken

/// Laat het model gecontroleerde feiten opvragen uit de Vliegtuigtas-database
/// in plaats van te gokken. Het model roept deze tool zelf aan wanneer een
/// vraag over een specifieke maatschappij gaat.
@available(iOS 26.0, *)
struct AirlineRulesTool: Tool {
    let name = "bagageregels"
    let description = """
    Zoekt de actuele handbagage- en ruimbagageregels van een vliegmaatschappij \
    op in de Vliegtuigtas-database. Gebruik deze tool altijd wanneer de vraag \
    over een specifieke maatschappij gaat.
    """

    let airlines: [Airline]

    @Generable
    struct Arguments {
        @Guide(description: "De naam van de vliegmaatschappij, bijvoorbeeld Ryanair, KLM of easyJet")
        var maatschappij: String
    }

    func call(arguments: Arguments) async throws -> String {
        let query = arguments.maatschappij.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = airlines.first {
            $0.name.localizedCaseInsensitiveContains(query)
                || query.localizedCaseInsensitiveContains($0.name)
        }
        guard let airline = match else {
            let known = airlines.map(\.name).joined(separator: ", ")
            return "Geen maatschappij gevonden voor '\(query)'. Beschikbare maatschappijen: \(known)."
        }
        return airline.aiRulesSummary
    }
}

// MARK: - Tool: luchthaven-info

/// Gecureerde praktische kennis over de vertrek-luchthavens die Nederlandse
/// en Belgische reizigers het meest gebruiken. Bewust tijdloos geformuleerd
/// (geen actuele wachttijden), zodat de feiten niet verouderen.
@available(iOS 26.0, *)
struct AirportInfoTool: Tool {
    let name = "luchthavenInfo"
    let description = """
    Praktische informatie over vertrek-luchthavens: security, CT-scanners, \
    vloeistoffenregels, watertappunten en welke maatschappijen er vooral \
    vliegen. Gebruik deze tool bij vragen over een luchthaven of vliegveld.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Naam of IATA-code van de luchthaven, bijvoorbeeld Schiphol, Eindhoven of AMS")
        var luchthaven: String
    }

    private static let airports: [(names: [String], info: String)] = [
        (["schiphol", "ams", "amsterdam"], """
        Schiphol (AMS): grootste hub van Nederland; thuisbasis KLM en Transavia. \
        Moderne CT-scanners bij security: vloeistoffen en elektronica mogen in de \
        tas blijven, maar de 100 ml-regel geldt onverminderd. Watertappunten na \
        security. Advies: 2 uur van tevoren (Schengen), 3 uur (intercontinentaal). \
        Zelf bagage droppen kan bij de self-service kiosken.
        """),
        (["eindhoven", "ein"], """
        Eindhoven Airport (EIN): basis van Ryanair, Transavia en Wizz Air — \
        maatschappijen die streng op handbagagemaat controleren; verwacht \
        maatcontrole bij de gate. CT-scanners aanwezig (spullen in de tas laten, \
        100 ml-regel geldt). Compacte terminal: 2 uur van tevoren is ruim.
        """),
        (["rotterdam", "rtm", "den haag"], """
        Rotterdam The Hague Airport (RTM): klein en snel; vooral Transavia. \
        Korte loopafstanden, security doorgaans vlot; 1,5–2 uur van tevoren volstaat meestal.
        """),
        (["brussel", "zaventem", "bru", "brussels"], """
        Brussels Airport / Zaventem (BRU): hub van Brussels Airlines; CT-scanners \
        bij security (tas mag dicht blijven, 100 ml-regel geldt). Advies: 2 uur \
        (Schengen), 3 uur (intercontinentaal).
        """),
        (["charleroi", "crl", "brussels south"], """
        Brussels South Charleroi (CRL): grote Ryanair-basis — strenge maatcontrole \
        bij de gate, priority-rij voor grote handbagage. Reken op drukte bij security; 2 uur van tevoren.
        """),
        (["düsseldorf", "dusseldorf", "dus"], """
        Düsseldorf (DUS): grootste luchthaven nabij Oost-Nederland; veel Eurowings. \
        Duitse security kan strenger controleren op losse elektronica; 100 ml-regel geldt. 2 uur van tevoren.
        """),
        (["weeze", "nrn", "niederrhein"], """
        Weeze/Niederrhein (NRN): Ryanair-basis vlak over de grens bij Nijmegen. \
        Kleine terminal, strenge Ryanair-maatcontrole bij de gate; 2 uur van tevoren is ruim.
        """),
        (["maastricht", "mst", "aachen"], """
        Maastricht Aachen Airport (MST): kleine luchthaven, vooral vakantievluchten \
        (o.a. Corendon en Ryanair). Snel door security; 1,5–2 uur van tevoren volstaat.
        """)
    ]

    func call(arguments: Arguments) async throws -> String {
        let query = arguments.luchthaven
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let match = Self.airports.first(where: { entry in
            entry.names.contains { query.contains($0) || $0.contains(query) }
        }) {
            return match.info
        }
        let known = "Schiphol, Eindhoven, Rotterdam, Brussel-Zaventem, Charleroi, Düsseldorf, Weeze, Maastricht"
        return "Geen specifieke informatie over '\(arguments.luchthaven)'. Wel beschikbaar: \(known). Algemeen geldt in de EU overal de 100 ml-regel, ook bij CT-scanners."
    }
}

// MARK: - Tool: echte tas-check uitvoeren

/// Laat Pim de officiële servercheck draaien, midden in het gesprek.
/// "Past mijn tas bij Ryanair?" wordt zo een écht antwoord met het echte
/// oordeel, niet een schatting van het taalmodel.
@available(iOS 26.0, *)
struct BagCheckTool: Tool {
    let name = "checkTas"
    let description = """
    Voert de officiële Vliegtuigtas-check uit: controleert of een tas met \
    opgegeven afmetingen en gewicht als handbagage past bij een maatschappij. \
    Gebruik deze tool wanneer de gebruiker wil weten of een specifieke tas \
    (bijvoorbeeld zijn eigen tas) past.
    """

    let airlines: [Airline]

    @Generable
    struct Arguments {
        @Guide(description: "Naam van de vliegmaatschappij, bijvoorbeeld Ryanair of KLM")
        var maatschappij: String
        @Guide(description: "Lengte/hoogte van de tas in centimeters")
        var lengteCm: Double
        @Guide(description: "Breedte van de tas in centimeters")
        var breedteCm: Double
        @Guide(description: "Diepte van de tas in centimeters")
        var diepteCm: Double
        @Guide(description: "Gewicht van de tas in kilogram")
        var gewichtKg: Double
    }

    func call(arguments: Arguments) async throws -> String {
        let query = arguments.maatschappij.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let airline = airlines.first(where: {
            $0.name.localizedCaseInsensitiveContains(query)
                || query.localizedCaseInsensitiveContains($0.name)
        }) else {
            return "Geen maatschappij gevonden voor '\(query)'."
        }
        do {
            let result = try await APIClient.shared.check(
                airlineSlug: airline.slug,
                length: arguments.lengteCm, width: arguments.breedteCm,
                depth: arguments.diepteCm, weight: arguments.gewichtKg
            )
            APIClient.shared.sendEvent("bag_check", path: "/pim/check")
            var text = "Officiële check bij \(airline.name): \(result.verdictTitle) \(result.verdictMessage)"
            if let variant = result.variant {
                text += " (tarief \(variant.variantName))"
            }
            return text
        } catch {
            return "De check kon niet worden uitgevoerd (geen verbinding). Baseer je antwoord op de bagageregels en zeg erbij dat de officiële check nu niet lukte."
        }
    }
}

// MARK: - Chat-assistent

@available(iOS 26.0, *)
@MainActor
final class BagageAssistent: ObservableObject {
    struct ChatMessage: Identifiable, Equatable {
        enum Role { case user, assistant }
        let id = UUID()
        let role: Role
        let text: String
    }

    @Published var messages: [ChatMessage] = []
    @Published var isThinking = false
    @Published var error: String?
    /// Maatschappij die in het gesprek ter sprake kwam — de UI toont er
    /// een actieknop bij ("Check je tas bij …").
    @Published var suggestedAirline: Airline?

    /// Contextbewuste vervolgvragen, afgeleid van het laatste antwoord.
    @Published var followUps: [String] = [
        "Wat mag mee bij Ryanair?",
        "Hoe vroeg moet ik op Schiphol zijn?",
        "Hoeveel vloeistof mag mee?"
    ]

    private let session: LanguageModelSession
    private let airlines: [Airline]

    init(airlines: [Airline]) {
        self.airlines = airlines

        // Persoonlijke context: Pim kent jouw tas en vlucht, zodat
        // "past mijn tas?" direct beantwoord kan worden.
        var personalContext = ""
        if let dims = CloudSync.shared.savedBagDims() {
            personalContext += """
            \nDe eigen tas van de gebruiker (eerder gecheckt): \
            \(Int(dims.length)) × \(Int(dims.width)) × \(Int(dims.depth)) cm, \
            \(dims.weight) kg. Als de gebruiker het over 'mijn tas' heeft, \
            gebruik deze maten met de tool 'checkTas'.
            """
        }
        if let flight = SharedFlightStore.loadFlight() {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "nl_NL")
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
            personalContext += """
            \nDe opgeslagen vlucht van de gebruiker: \(flight.number)\
            \(flight.airlineName.map { " met \($0)" } ?? "") op \
            \(fmt.string(from: flight.departure)). Bij vragen over 'mijn vlucht' \
            gaat het hierover; gebruik die maatschappij als er geen andere wordt genoemd.
            """
        }

        session = LanguageModelSession(
            tools: [
                AirlineRulesTool(airlines: airlines),
                BagCheckTool(airlines: airlines),
                AirportInfoTool()
            ],
            instructions: personalContext + """
            Je bent Purser Pim, de bagage-assistent van Vliegtuigtas, een Nederlandse app \
            die reizigers helpt met handbagageregels van vliegmaatschappijen. Je bent \
            vriendelijk en behulpzaam, zoals een purser aan boord. Antwoord altijd in het \
            Nederlands, kort en concreet (maximaal een paar zinnen). Gebruik de tool \
            'bagageregels' voor vragen over een specifieke maatschappij en baseer maten, \
            gewichten en prijzen uitsluitend op die tooluitvoer. Gebruik de tool 'checkTas' \
            wanneer de gebruiker wil weten of een concrete tas past — dat is de officiële \
            check en telt zwaarder dan je eigen inschatting. Gebruik de tool \
            'luchthavenInfo' bij vragen over een vliegveld (security, scanners, \
            hoe vroeg aanwezig zijn). Als iets niet in de data \
            staat, zeg dat eerlijk en verwijs naar de officiële site van de maatschappij. \
            Beantwoord alleen vragen over reizen, bagage en vliegen.

            Actuele EU-securityregels (2026) die je mag gebruiken: vloeistoffen max. \
            100 ml per verpakking in één doorzichtig hersluitbaar zakje van 1 liter \
            (etiketinhoud telt, geldt ook voor mascara, deodorant, haarlak en smeerbaar \
            eten); de 100 ml-regel is sinds 1 september 2024 overal in de EU weer \
            standaard, ook bij CT-scanners. Powerbanks horen in de handbagage, nooit in \
            het ruim: tot 100 Wh vrij, 100–160 Wh alleen met toestemming (max. 2), boven \
            160 Wh verboden. Vast eten mag; vloeibaar/smeerbaar eten valt onder 100 ml. \
            Medicijnen en baby-/dieetvoeding mogen boven 100 ml mits apart aangemeld, \
            medicijnen in originele verpakking. Toegestaan: nagelschaartje (blad < 6 cm), \
            pincet, nagelknipper, elektrisch scheerapparaat, wegwerpmesjes, lege drinkfles. \
            Verboden in de cabine: scharen met lemmet > 6 cm en messen (mogen wel in het \
            ruim), wapens en namaakwapens, vuurwerk, knuppels, tasers/stroomstootwapens, \
            hoverboards (ook zonder accu); één kleine aansteker mag alleen óp het lichaam.
            """
        )
    }

    /// Laadt het model alvast zodat het eerste antwoord sneller komt.
    func prewarm() {
        session.prewarm()
    }

    func ask(_ question: String) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isThinking else { return }

        messages.append(ChatMessage(role: .user, text: q))
        isThinking = true
        error = nil
        do {
            let response = try await session.respond(to: q)
            messages.append(ChatMessage(role: .assistant, text: response.content))
            updateContext(question: q, answer: response.content)
        } catch {
            self.error = "Het model kon deze vraag niet beantwoorden. Probeer het anders te formuleren."
        }
        isThinking = false
    }

    /// Leidt uit vraag + antwoord af waar het gesprek over gaat: welke
    /// maatschappij (voor de actieknop) en welke vervolgvragen logisch zijn.
    private func updateContext(question: String, answer: String) {
        let text = question + " " + answer
        let lower = text.lowercased()

        if let match = airlines.first(where: { text.localizedCaseInsensitiveContains($0.name) }) {
            suggestedAirline = match
        }

        var suggestions: [String] = []

        // Onderwerp-specifieke verdieping
        if lower.contains("vloeistof") || lower.contains("100 ml") || lower.contains("zakje") {
            suggestions.append("Gelden er uitzonderingen voor medicijnen?")
            suggestions.append("Telt make-up ook als vloeistof?")
        }
        if lower.contains("powerbank") || lower.contains("batterij") || lower.contains("accu") {
            suggestions.append("Hoeveel powerbanks mogen mee?")
            suggestions.append("Mag mijn laptop in het ruim?")
        }
        if lower.contains("ruimbagage") || lower.contains("inchecken") || lower.contains("ruim ") {
            suggestions.append("Wat kost overgewicht?")
        }
        let airports = ["schiphol", "eindhoven", "rotterdam", "zaventem", "charleroi", "düsseldorf", "weeze", "maastricht", "luchthaven", "vliegveld"]
        if airports.contains(where: lower.contains) {
            suggestions.append("Hoe vroeg moet ik er zijn?")
            suggestions.append("Kan ik mijn fles bijvullen na security?")
        }

        // Maatschappij-specifiek doorpakken
        if let airline = suggestedAirline {
            if CloudSync.shared.savedBagDims() != nil {
                suggestions.insert("Past mijn tas bij \(airline.name)?", at: 0)
            }
            suggestions.append("Wat kost ruimbagage bij \(airline.name)?")
            suggestions.append("Hoe streng is \(airline.name) bij de gate?")
        }

        if suggestions.isEmpty {
            suggestions = ["En ruimbagage?", "Wat mag niet mee?", "Wat kost een extra tas?"]
        }

        // Dedupliceren (volgorde behouden), niet herhalen wat net gevraagd is,
        // en maximaal drie tonen.
        var seen = Set<String>()
        followUps = suggestions.filter { suggestion in
            guard !seen.contains(suggestion),
                  !question.localizedCaseInsensitiveContains(suggestion.dropLast()) else { return false }
            seen.insert(suggestion)
            return true
        }
        followUps = Array(followUps.prefix(3))
    }
}

// MARK: - Pakadvies (guided generation)

@available(iOS 26.0, *)
@Generable
struct PakAdvies: Equatable {
    @Guide(description: "Korte, vriendelijke titel van het advies in het Nederlands")
    var titel: String

    @Guide(description: "Concrete, praktische paktips in het Nederlands, afgestemd op de bagageregels van deze maatschappij", .count(4))
    var tips: [String]

    @Guide(description: "De belangrijkste waarschuwing of valkuil bij deze maatschappij, één zin in het Nederlands")
    var waarschuwing: String
}

@available(iOS 26.0, *)
@MainActor
final class PakAdviesModel: ObservableObject {
    @Published var advies: PakAdvies?
    @Published var isLoading = false
    @Published var error: String?

    func generate(for airline: Airline) async {
        guard advies == nil, !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let session = LanguageModelSession(
                instructions: """
                Je bent de pak-assistent van Vliegtuigtas. Je geeft reizigers praktisch \
                pakadvies voor hun handbagage, volledig in het Nederlands. Baseer je \
                uitsluitend op de aangeleverde bagageregels; verzin geen maten of prijzen.
                """
            )
            let response = try await session.respond(
                to: """
                Geef pakadvies voor een reiziger die vliegt met \(airline.name). \
                Dit zijn de actuele bagageregels:

                \(airline.aiRulesSummary)
                """,
                generating: PakAdvies.self
            )
            advies = response.content
            if let tip = response.content.tips.first {
                PimTipCache.save(tip: tip, airlineName: airline.name)
            }
        } catch {
            self.error = "Kon geen advies genereren. Probeer het later opnieuw."
        }
        isLoading = false
    }
}

#endif

// MARK: - Widget-cache voor Pim's tip van de dag

/// De "Purser Pim" widget kan geen eigen taalmodel-sessie starten (te zwaar
/// voor een timeline provider), dus we bewaren hier de laatste écht door Pim
/// gegenereerde tip. De widget toont die tip als hij niet te oud is, en valt
/// anders terug op een statische rotatie — zo is er altijd content, en is
/// die content zo vaak mogelijk echt van Pim.
enum PimTipCache {
    static let suiteName = "group.com.vliegtuigtas.app"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    static func save(tip: String, airlineName: String) {
        guard let d = defaults else { return }
        d.set(tip, forKey: "vt_shared_pim_tip")
        d.set(airlineName, forKey: "vt_shared_pim_tip_airline")
        d.set(Date().timeIntervalSince1970, forKey: "vt_shared_pim_tip_stamp")
        WidgetCenter.shared.reloadTimelines(ofKind: "PurserPimWidget")
    }
}
