import SwiftUI
import LocalAuthentication

// MARK: - Vergrendeling voor verborgen reizen

/// Toegang tot verborgen reizen loopt via de vergrendeling van het toestel
/// zelf (Face ID, Touch ID of toegangscode). Geen eigen pincode: die zou een
/// tweede geheim introduceren dat wij moeten bewaren, terwijl iOS dit al
/// veiliger doet dan wij kunnen.
enum HiddenTripsLock {
    /// Vraagt om authenticatie. Zonder biometrie of code op het toestel is er
    /// niets om achter te verbergen; dan geven we netjes `false` terug in
    /// plaats van de reizen zomaar te tonen.
    static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Gebruik toegangscode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Toon je verborgen reizen"
            )
        } catch {
            return false
        }
    }

    /// Of er überhaupt een vergrendeling op het toestel staat. Zonder dat heeft
    /// verbergen weinig zin, en dat zeggen we liever eerlijk.
    static var isDeviceProtected: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}

// MARK: - Model

/// Soort reis. Bepaalt de sfeer in de wizard én — belangrijker — welke spullen
/// er extra op de paklijst komen. Zonder dat effect zou het een extra stap zijn
/// die alleen maar klikken kost.
enum TripStyle: String, Codable, CaseIterable, Identifiable {
    case strand, stad, natuur, wintersport, zakelijk, festival

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strand:      return "Strand"
        case .stad:        return "Stedentrip"
        case .natuur:      return "Natuur"
        case .wintersport: return "Wintersport"
        case .zakelijk:    return "Zakelijk"
        case .festival:    return "Festival"
        }
    }

    var icon: String {
        switch self {
        case .strand:      return "beach.umbrella.fill"
        case .stad:        return "building.2.fill"
        case .natuur:      return "mountain.2.fill"
        case .wintersport: return "snowflake"
        case .zakelijk:    return "briefcase.fill"
        case .festival:    return "music.note"
        }
    }

    /// Eén regel sfeer, zodat de keuze niet alleen een icoontje is.
    var tagline: String {
        switch self {
        case .strand:      return "Zon, zee en weinig kleren"
        case .stad:        return "Musea, terrasjes en veel lopen"
        case .natuur:      return "Wandelen en buiten slapen"
        case .wintersport: return "Piste, kou en dikke lagen"
        case .zakelijk:    return "Netjes voor de dag komen"
        case .festival:    return "Camping, muziek en modder"
        }
    }

    /// Extra items bovenop de basispaklijst.
    var extraItems: [PackingItem] {
        switch self {
        case .strand:
            return [
                PackingItem(name: "Zwemkleding", category: "Kleding", quantity: 2),
                PackingItem(name: "Strandhanddoek", category: "Kleding", quantity: 1),
                PackingItem(name: "Slippers", category: "Kleding", quantity: 1),
                PackingItem(name: "Zonnebril", category: "Overig", quantity: 1),
                PackingItem(name: "Aftersun", category: "Toiletries", quantity: 1),
            ]
        case .stad:
            return [
                PackingItem(name: "Comfortabele wandelschoenen", category: "Kleding", quantity: 1),
                PackingItem(name: "Dagrugzak", category: "Overig", quantity: 1),
                PackingItem(name: "Nette outfit voor uit eten", category: "Kleding", quantity: 1),
            ]
        case .natuur:
            return [
                PackingItem(name: "Wandelschoenen", category: "Kleding", quantity: 1),
                PackingItem(name: "Waterfles", category: "Overig", quantity: 1),
                PackingItem(name: "Zaklamp of hoofdlamp", category: "Elektronica", quantity: 1),
                PackingItem(name: "EHBO-setje", category: "Overig", quantity: 1),
                PackingItem(name: "Insectenspray", category: "Toiletries", quantity: 1),
            ]
        case .wintersport:
            return [
                PackingItem(name: "Skijas en skibroek", category: "Kleding", quantity: 1),
                PackingItem(name: "Thermokleding", category: "Kleding", quantity: 2),
                PackingItem(name: "Handschoenen en muts", category: "Kleding", quantity: 1),
                PackingItem(name: "Skibril", category: "Overig", quantity: 1),
                PackingItem(name: "Lippenbalsem met factor", category: "Toiletries", quantity: 1),
            ]
        case .zakelijk:
            return [
                PackingItem(name: "Nette schoenen", category: "Kleding", quantity: 1),
                PackingItem(name: "Overhemden of blouses", category: "Kleding", quantity: 2),
                PackingItem(name: "Laptop + oplader", category: "Elektronica", quantity: 1),
                PackingItem(name: "Visitekaartjes", category: "Documenten", quantity: 1),
            ]
        case .festival:
            return [
                PackingItem(name: "Regenponcho", category: "Kleding", quantity: 1),
                PackingItem(name: "Oordoppen", category: "Overig", quantity: 1),
                PackingItem(name: "Laarzen", category: "Kleding", quantity: 1),
                PackingItem(name: "Natte doekjes", category: "Toiletries", quantity: 1),
                PackingItem(name: "Extra powerbank", category: "Elektronica", quantity: 1),
            ]
        }
    }
}

/// Hoeveel bagage je meeneemt op een reis — bepaalt welke extra paklijst-
/// items de generator toevoegt (vloeistoffenzakje vs. volle toiletflessen).
enum LuggageType: String, Codable, CaseIterable, Identifiable {
    case carryOnOnly, checkedOnly, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .carryOnOnly: return "Alleen handbagage"
        case .checkedOnly: return "Alleen ruimbagage"
        case .both:        return "Handbagage + ruimbagage"
        }
    }

    var icon: String {
        switch self {
        case .carryOnOnly: return "bag.fill"
        case .checkedOnly: return "suitcase.rolling.fill"
        case .both:        return "suitcase.cart.fill"
        }
    }
}

/// Eén item op de paklijst, binnen een categorie ("Kleding", "Toiletries",
/// ...). `category` is bewust een losse string en geen gesloten enum: zo kan
/// de generator nieuwe categorieën toevoegen zonder overal cases te raken.
struct PackingItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var category: String
    var quantity: Int
    var isChecked: Bool = false
}

/// Eén geplande reis: naam, data en een eigen paklijst. Puur additief naast
/// FlightsStore — een Trip mag bestaan zonder ooit een vlucht of tas te
/// koppelen, en heeft geen eigen "glanceable surface" (widget/watch/Live
/// Activity) nodig zoals de eerstvolgende vlucht die wel heeft.
struct Trip: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var destination: String?
    var startDate: Date
    var endDate: Date
    var luggageType: LuggageType
    /// Optioneel: bestaande opgeslagen reizen decoderen gewoon met nil.
    var style: TripStyle?
    /// Zelf omschreven reistype, door Pim omgezet naar een naam ("Duikreis")
    /// en bijpassende spullen. Staat los van `style`: precies één van beide is
    /// gevuld.
    var customStyleLabel: String?
    var isPinned: Bool = false
    /// Verborgen reizen verdwijnen overal uit beeld — lijsten, Start, paspoort
    /// en de aftelling. Ze zijn alleen te zien achter een apparaatvergrendeling
    /// (Face ID / Touch ID / toegangscode), zodat iemand die even je telefoon
    /// vasthoudt een verrassingsreis niet ziet staan.
    var isHidden: Bool = false
    /// Optioneel → SavedFlightRecord.id / SavedBag.id. Wordt lazy opgezocht
    /// in de views (net als BagFitCard dat doet met een Airline), nooit
    /// gedupliceerd opgeslagen.
    var linkedFlightId: UUID?
    var linkedBagId: UUID?
    var packingItems: [PackingItem] = []
    /// Eén keer opgehaald van Unsplash bij het aanmaken (zie
    /// TripWizardView.createTrip) — nooit automatisch ververst, zodat een
    /// eenmaal gekozen foto niet steeds wisselt.
    var photoUrl: String?
    var photoAuthorName: String?
    var photoAuthorUrl: String?

    /// Hoe dit reistype heet, ongeacht of het een vast type of een eigen type
    /// van Pim is.
    var styleLabel: String? { style?.label ?? customStyleLabel }

    var days: Int {
        let cal = Calendar.current
        let d = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: startDate),
            to: cal.startOfDay(for: endDate)
        ).day ?? 0
        return max(1, d + 1)
    }

    var isPast: Bool { endDate < Date() }
    var isOngoing: Bool { !isPast && startDate <= Date() }

    private var daysUntilStart: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: startDate)
        ).day ?? 0
    }

    var countdownLabel: String {
        if isPast { return "Geweest" }
        if isOngoing { return "Onderweg" }
        switch daysUntilStart {
        case 0:  return "Vandaag"
        case 1:  return "Morgen"
        default: return "Over \(daysUntilStart) dagen"
        }
    }

    var progress: (checked: Int, total: Int) {
        (packingItems.filter(\.isChecked).count, packingItems.count)
    }
}

// MARK: - Reisklaar-score

/// Combineert paklijst-voortgang, tas-fit en paspoortgeldigheid tot één
/// percentage + concrete actiepunten. Puur — geen store-toegang: views
/// resolven bag-fit/paspoort zelf (zelfde filosofie als de lazy resolutie
/// van linkedFlightId/linkedBagId) en geven het resultaat hier binnen.
struct TripReadiness {
    let packingPercent: Double   // 0...1
    let bagFitOK: Bool?          // nil = nog geen tas/maatschappij bekend
    let passportOK: Bool?        // nil = geen paspoort-vervaldatum ingevuld

    /// Paklijst weegt het zwaarst; een paspoortprobleem domineert het cijfer
    /// (een niet-geldig paspoort maakt de reis alsnog onklaar, hoe goed er
    /// ook is ingepakt) en een tas die niet past trekt een vaste straf af.
    var overallPercent: Int {
        var score = packingPercent
        if bagFitOK == false { score -= 0.15 }
        if passportOK == false { score = min(score, 0.3) }
        return Int((max(0, min(1, score))) * 100)
    }

    var actionItems: [String] {
        var items: [String] = []
        if passportOK == false {
            items.append("Check je paspoort — geldigheid is mogelijk te kort voor deze reis")
        }
        if bagFitOK == false {
            items.append("Je tas past niet in de cabine bij deze maatschappij")
        }
        if packingPercent < 1 {
            items.append("Nog niet alles ingepakt")
        }
        return items
    }
}

// MARK: - Deterministische paklijst-generator

/// Simpel, deterministisch sjabloon — geen AI/weer, alleen categorie ×
/// hoeveelheid geschaald met de reisduur. Bewust bescheiden gehouden; wordt
/// één keer aangeroepen bij het afronden van de wizard en daarna nooit meer
/// automatisch herhaald, zodat een aangevinkte/aangepaste lijst niet
/// overschreven wordt.
func generatePackingList(
    days: Int,
    luggageType: LuggageType,
    style: TripStyle? = nil,
    customItems: [String] = []
) -> [PackingItem] {
    let d = max(1, min(days, 21))   // cap: een lange reis genereert geen 90 t-shirts

    var items: [PackingItem] = [
        // Kleding — schaalt mee met de reisduur, met een plafond
        PackingItem(name: "T-shirts", category: "Kleding", quantity: min(d, 7)),
        PackingItem(name: "Onderbroeken", category: "Kleding", quantity: min(d + 1, 8)),
        PackingItem(name: "Paar sokken", category: "Kleding", quantity: min(d + 1, 8)),
        PackingItem(name: "Broeken of rokken", category: "Kleding", quantity: max(1, d / 3)),
        PackingItem(name: "Trui of vest", category: "Kleding", quantity: d > 3 ? 2 : 1),
        PackingItem(name: "Pyjama", category: "Kleding", quantity: 1),
        PackingItem(name: "Regenjas", category: "Kleding", quantity: 1),

        // Toiletries — vast, ook een weekendje weg heeft dezelfde basis nodig
        PackingItem(name: "Tandenborstel & tandpasta", category: "Toiletries", quantity: 1),
        PackingItem(name: "Deodorant", category: "Toiletries", quantity: 1),
        PackingItem(name: "Zonnebrandcrème", category: "Toiletries", quantity: 1),
        PackingItem(name: "Reisformaat toiletartikelen", category: "Toiletries", quantity: 1),

        // Documenten — vast
        PackingItem(name: "Paspoort of ID-kaart", category: "Documenten", quantity: 1),
        PackingItem(name: "Boarding passes", category: "Documenten", quantity: 1),
        PackingItem(name: "Reisverzekering", category: "Documenten", quantity: 1),
        PackingItem(name: "Creditcard of contant geld", category: "Documenten", quantity: 1),

        // Elektronica — vast
        PackingItem(name: "Telefoon + oplader", category: "Elektronica", quantity: 1),
        PackingItem(name: "Powerbank", category: "Elektronica", quantity: 1),
        PackingItem(name: "Stekkeradapter", category: "Elektronica", quantity: 1),
        PackingItem(name: "Oordopjes of koptelefoon", category: "Elektronica", quantity: 1),
    ]

    switch luggageType {
    case .carryOnOnly:
        items.append(PackingItem(name: "Vloeistoffenzakje (max 100 ml per flesje)", category: "Toiletries", quantity: 1))
    case .checkedOnly, .both:
        items.append(PackingItem(name: "Toiletartikelen (volle flessen)", category: "Toiletries", quantity: 1))
        items.append(PackingItem(name: "Extra paar schoenen", category: "Kleding", quantity: 1))
    }

    // Stijl-specifieke spullen erbij: dit is wat de keuze in de wizard
    // daadwerkelijk oplevert.
    if let style {
        items.append(contentsOf: style.extraItems)
    }

    // Eigen reistype van Pim: zijn spullen komen in een eigen categorie, zodat
    // je ziet welk deel van de lijst uit jouw omschrijving voortkomt.
    for name in customItems {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        items.append(PackingItem(name: trimmed, category: "Voor jouw reis", quantity: 1))
    }

    return items
}

/// Vaste weergavevolgorde voor categorieën — alles wat niet in dit lijstje
/// staat (bijv. een zelf toegevoegd item) komt er gewoon achteraan.
let packingCategoryOrder = ["Kleding", "Toiletries", "Documenten", "Elektronica"]

// MARK: - Store (lokaal + iCloud)

/// Beheert alle opgeslagen reizen: UserDefaults als bron, iCloud als sync —
/// zelfde opzet als BagCollectionStore. Geen SharedFlightStore-achtige
/// spiegeling nodig: reizen hebben geen widget/watch/Live Activity-oppervlak.
@MainActor
final class TripsStore: ObservableObject {
    static let shared = TripsStore()
    static let storageKey = "vt_saved_trips"

    @Published private(set) var trips: [Trip] = []

    /// Álle reizen, ook verborgen. Alleen gebruiken achter authenticatie.
    var sortedIncludingHidden: [Trip] { trips.sorted { $0.startDate < $1.startDate } }

    /// De standaardweergave: verborgen reizen zitten hier bewust niet in, zodat
    /// geen enkel scherm ze per ongeluk toont.
    var sorted: [Trip] { sortedIncludingHidden.filter { !$0.isHidden } }
    var pinned: [Trip] { sorted.filter(\.isPinned) }
    var upcoming: [Trip] { sorted.filter { !$0.isPinned && !$0.isPast } }
    var past: [Trip] { sorted.filter { !$0.isPinned && $0.isPast } }
    /// Eerstvolgende reis, ongeacht pin-status — dit is wat de widget toont.
    var next: Trip? { sorted.first { !$0.isPast } }

    var hidden: [Trip] { sortedIncludingHidden.filter(\.isHidden) }
    var hasHiddenTrips: Bool { trips.contains(where: \.isHidden) }

    func setHidden(_ hidden: Bool, tripId: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripId }) else { return }
        trips[index].isHidden = hidden
        persist()
    }

    private let defaults = UserDefaults.standard

    private init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = decoded
        }
    }

    func upsert(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        } else {
            trips.append(trip)
        }
        persist()
    }

    func remove(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        persist()
    }

    func removeAll() {
        trips = []
        persist()
    }

    /// Eén checklist-item omzetten zonder dat de view zelf met
    /// arrays/indexen hoeft te knoeien.
    /// Eigen item toevoegen. Dubbele namen worden genegeerd (hoofdletter-
    /// ongevoelig), zodat Pim-suggesties en handmatige invoer elkaar niet
    /// dubbel op de lijst zetten.
    @discardableResult
    func addItem(tripId: UUID, name: String, category: String = "Eigen items", quantity: Int = 1) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let ti = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        let exists = trips[ti].packingItems.contains {
            $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        guard !exists else { return false }
        trips[ti].packingItems.append(
            PackingItem(name: trimmed, category: category, quantity: max(1, quantity))
        )
        persist()
        return true
    }

    func removeItem(tripId: UUID, itemId: UUID) {
        guard let ti = trips.firstIndex(where: { $0.id == tripId }) else { return }
        trips[ti].packingItems.removeAll { $0.id == itemId }
        persist()
    }

    func toggleItem(tripId: UUID, itemId: UUID) {
        guard let ti = trips.firstIndex(where: { $0.id == tripId }),
              let ii = trips[ti].packingItems.firstIndex(where: { $0.id == itemId }) else { return }
        trips[ti].packingItems[ii].isChecked.toggle()
        persist()
    }

    /// Vanuit iCloud overgenomen — alleen lokaal schrijven, niet terugpushen.
    func adopt(data: Data) {
        guard let decoded = try? JSONDecoder().decode([Trip].self, from: data) else { return }
        trips = decoded
        defaults.set(data, forKey: Self.storageKey)
        SharedTripStore.mirror(next)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        defaults.set(data, forKey: Self.storageKey)
        CloudSync.shared.pushTripList(data)
        SharedTripStore.mirror(next)
    }
}

// MARK: - App Group-spiegel voor de widget

/// Spiegelt de eerstvolgende reis naar de App Group, zodat de widget (ander
/// proces, geen toegang tot UserDefaults.standard) 'm kan lezen. Geen
/// push/adopt-onderscheid nodig zoals bij SharedFlightStore: dit is een pure
/// lokale cache voor de widget, niet zelf een iCloud-sync-pad — dat doet
/// CloudSync's .tripList-blob al voor de hele lijst.
enum SharedTripStore {
    private static var suite: UserDefaults? { UserDefaults(suiteName: SharedFlightStore.suiteName) }

    private enum Key {
        static let name = "vt_shared_trip_name"
        static let destination = "vt_shared_trip_destination"
        static let start = "vt_shared_trip_start"
    }

    static func mirror(_ trip: Trip?) {
        guard let suite else { return }
        if let trip {
            suite.set(trip.name, forKey: Key.name)
            suite.set(trip.destination, forKey: Key.destination)
            suite.set(trip.startDate.timeIntervalSince1970, forKey: Key.start)
        } else {
            suite.removeObject(forKey: Key.name)
            suite.removeObject(forKey: Key.destination)
            suite.removeObject(forKey: Key.start)
        }
    }
}
