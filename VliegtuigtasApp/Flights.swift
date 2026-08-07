import SwiftUI
import MapKit
import UserNotifications

// MARK: - Model

/// Eén opgeslagen vlucht, met alle informatie die de flight-lookup API
/// teruggeeft — zodat de detailpagina alles kan tonen wat er bekend is.
struct SavedFlightRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var number: String
    var airlineName: String?
    var airlineSlug: String?
    var airlineLogoUrl: String?
    var flightIcao: String?
    var departure: Date
    var departureIata: String?
    var departureAirport: String?
    var arrivalIata: String?
    var arrivalAirport: String?
    var flightDate: String?      // ruwe datumstring uit de lookup, bijv. "2026-07-02"
    var status: String?          // scheduled | active | landed | cancelled | incident | diverted | delayed

    // Verrijkt via AviationstackClient (rechtstreeks, náást de backend-lookup
    // hierboven) — allemaal optioneel, dus bestaande opgeslagen vluchten
    // decoderen gewoon met deze velden op nil.
    var departureTerminal: String?
    var departureGate: String?
    var departureDelayMinutes: Int?
    var departureScheduled: Date?
    var departureEstimated: Date?
    var departureActual: Date?
    var arrivalTerminal: String?
    var arrivalGate: String?
    var arrivalBaggage: String?
    var arrivalDelayMinutes: Int?
    var arrivalScheduled: Date?
    var arrivalEstimated: Date?
    var arrivalActual: Date?
    var aircraftRegistration: String?
    var aircraftIcao24: String?
    var liveLatitude: Double?
    var liveLongitude: Double?
    var liveAltitude: Double?
    var liveSpeedKmh: Double?
    var liveDirection: Double?
    /// Eén keer opgehaald van Unsplash bij het opslaan — zelfde patroon als
    /// Trip.photoUrl, nooit automatisch ververst.
    var photoUrl: String?
    var photoAuthorName: String?
    var photoAuthorUrl: String?
    /// Wanneer de vluchtgegevens voor het laatst bij de bron zijn opgehaald.
    /// Optioneel, dus bestaande opgeslagen vluchten decoderen gewoon met nil.
    var lastRefreshed: Date?

    var hasRoute: Bool { departureIata != nil && arrivalIata != nil }

    var hasLivePosition: Bool { liveLatitude != nil && liveLongitude != nil }

    /// Vult dit record aan met de rijke Aviationstack-velden — bestaande
    /// velden (route, ICAO, status van het backend) blijven staan; hier komt
    /// alleen bij wat het backend niet doorgeeft.
    mutating func applyRichData(_ flight: AviationstackClient.AviationstackFlight) {
        departureTerminal = flight.departure?.terminal ?? departureTerminal
        departureGate = flight.departure?.gate ?? departureGate
        departureDelayMinutes = flight.departure?.delay ?? departureDelayMinutes
        departureScheduled = AviationstackClient.date(from: flight.departure?.scheduled) ?? departureScheduled
        departureEstimated = AviationstackClient.date(from: flight.departure?.estimated) ?? departureEstimated
        departureActual = AviationstackClient.date(from: flight.departure?.actual) ?? departureActual
        arrivalTerminal = flight.arrival?.terminal ?? arrivalTerminal
        arrivalGate = flight.arrival?.gate ?? arrivalGate
        arrivalBaggage = flight.arrival?.baggage ?? arrivalBaggage
        arrivalDelayMinutes = flight.arrival?.delay ?? arrivalDelayMinutes
        arrivalScheduled = AviationstackClient.date(from: flight.arrival?.scheduled) ?? arrivalScheduled
        arrivalEstimated = AviationstackClient.date(from: flight.arrival?.estimated) ?? arrivalEstimated
        arrivalActual = AviationstackClient.date(from: flight.arrival?.actual) ?? arrivalActual
        aircraftRegistration = flight.aircraft?.registration ?? aircraftRegistration
        aircraftIcao24 = flight.aircraft?.icao24 ?? aircraftIcao24
        if let live = flight.live, live.isGround != true {
            liveLatitude = live.latitude
            liveLongitude = live.longitude
            liveAltitude = live.altitude
            liveSpeedKmh = live.speedHorizontal
            liveDirection = live.direction
        } else {
            liveLatitude = nil
            liveLongitude = nil
        }
    }

    var routeLabel: String? {
        guard let dep = departureIata, let arr = arrivalIata else { return nil }
        return "\(dep) → \(arr)"
    }

    /// Nederlands label voor de vluchtstatus van Aviationstack.
    var statusLabel: String? {
        switch status {
        case "scheduled": return "Gepland"
        case "active":    return "In de lucht"
        case "landed":    return "Geland"
        case "cancelled": return "Geannuleerd"
        case "incident":  return "Incident"
        case "diverted":  return "Omgeleid"
        case "delayed":   return "Vertraagd"
        default:          return nil
        }
    }

    var statusColor: Color {
        switch status {
        case "active":                                       return Theme.green
        case "landed":                                       return Theme.textSecondary
        case "cancelled", "incident", "diverted", "delayed": return Theme.red
        default:                                             return Theme.sky
        }
    }

    var isPast: Bool { departure < Date() }

    private var daysUntilDeparture: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: departure)
        ).day ?? 0
    }

    var countdownLabel: String {
        if isPast { return "Vertrokken" }
        switch daysUntilDeparture {
        case 0:  return "Vandaag"
        case 1:  return "Morgen"
        default: return "Over \(daysUntilDeparture) dagen"
        }
    }
}

// MARK: - Vluchtwacht: automatisch verversen + melden bij wijzigingen

/// Houdt opgeslagen vluchten zelf actueel en waarschuwt bij een gatewijziging,
/// vertraging of annulering — zonder dat de gebruiker ergens hoeft te trekken
/// om te verversen.
///
/// Het verversritme loopt mee met de urgentie, en dat is hier niet alleen
/// netjes maar ook nodig: Aviationstack heeft een beperkt maandquotum. Een
/// vlucht over drie weken hoeft niet elk half uur opnieuw opgehaald te worden;
/// een vlucht over twee uur wel.
@MainActor
enum FlightWatcher {
    /// Buiten dit venster laten we een vlucht met rust.
    private static let horizon: TimeInterval = 48 * 3600

    /// Minimale tijd tussen twee verversingen van dezelfde vlucht.
    private static func minimumInterval(untilDeparture seconds: TimeInterval) -> TimeInterval {
        switch seconds {
        case ..<(6 * 3600):   return 30 * 60      // laatste 6 uur: elk half uur
        case ..<(24 * 3600):  return 2 * 3600     // vandaag/morgen: elke 2 uur
        default:              return 6 * 3600     // verder weg: elke 6 uur
        }
    }

    private static func isDue(_ flight: SavedFlightRecord, now: Date) -> Bool {
        let untilDeparture = flight.departure.timeIntervalSince(now)
        // Alleen vluchten die nog moeten vertrekken en binnen het venster
        // vallen. Net vertrokken vluchten volgen we nog kort, zodat een
        // aankomst-bagageband nog kan binnenkomen.
        guard untilDeparture > -(6 * 3600), untilDeparture < horizon else { return false }
        guard let last = flight.lastRefreshed else { return true }
        return now.timeIntervalSince(last) >= minimumInterval(untilDeparture: untilDeparture)
    }

    /// Ververst alle vluchten die eraan toe zijn. Veilig om vaak aan te roepen:
    /// zonder werk doet dit niets.
    static func refreshDueFlights() async {
        let now = Date()
        let due = FlightsStore.shared.flights.filter { isDue($0, now: now) }
        guard !due.isEmpty else { return }

        for flight in due {
            guard let rich = await AviationstackClient.lookup(
                iata: flight.number, near: flight.departure
            ) else {
                // Mislukte poging ook stempelen, anders blijven we het bij elke
                // app-start opnieuw proberen en loopt het quotum leeg.
                if var current = FlightsStore.shared.flights.first(where: { $0.id == flight.id }) {
                    current.lastRefreshed = now
                    FlightsStore.shared.upsert(current)
                }
                continue
            }

            guard var updated = FlightsStore.shared.flights.first(where: { $0.id == flight.id }) else { continue }
            let before = updated
            updated.applyRichData(rich)
            updated.status = rich.flightStatus ?? updated.status
            updated.lastRefreshed = now
            FlightsStore.shared.upsert(updated)
            notifyChanges(from: before, to: updated)
        }
    }

    // MARK: - Melden wat er veranderd is

    /// Alleen echte, voor de reiziger relevante wijzigingen melden. Geen melding
    /// bij het vullen van een veld dat eerst simpelweg onbekend was (behalve de
    /// bagageband, want die wíl je juist weten zodra hij bekend is).
    private static func notifyChanges(from old: SavedFlightRecord, to new: SavedFlightRecord) {
        let flightName = new.number

        if let newGate = new.departureGate, newGate != old.departureGate, old.departureGate != nil {
            notify(
                id: "vt_gate_\(new.id)_\(newGate)",
                title: "Gate gewijzigd · \(flightName)",
                body: "Je vertrekt nu van gate \(newGate)\(new.departureTerminal.map { " (terminal \($0))" } ?? "")."
            )
        }

        if let newTerminal = new.departureTerminal,
           newTerminal != old.departureTerminal, old.departureTerminal != nil {
            notify(
                id: "vt_terminal_\(new.id)_\(newTerminal)",
                title: "Terminal gewijzigd · \(flightName)",
                body: "Je vertrekt nu vanaf terminal \(newTerminal)."
            )
        }

        // Vertraging pas melden vanaf 10 minuten, en alleen als hij toeneemt —
        // anders krijg je een melding bij elke minuut ruis.
        let oldDelay = old.departureDelayMinutes ?? 0
        let newDelay = new.departureDelayMinutes ?? 0
        if newDelay >= 10, newDelay - oldDelay >= 10 {
            notify(
                id: "vt_delay_\(new.id)_\(newDelay)",
                title: "Vertraging · \(flightName)",
                body: "Je vlucht vertrekt ongeveer \(newDelay) minuten later dan gepland."
            )
        }

        if new.status != old.status, let status = new.status {
            switch status {
            case "cancelled":
                notify(id: "vt_status_\(new.id)_cancelled",
                       title: "Vlucht geannuleerd · \(flightName)",
                       body: "Neem contact op met je maatschappij voor een alternatief.")
            case "diverted":
                notify(id: "vt_status_\(new.id)_diverted",
                       title: "Vlucht omgeleid · \(flightName)",
                       body: "Je vlucht gaat naar een andere bestemming dan gepland.")
            default:
                break
            }
        }

        if let belt = new.arrivalBaggage, belt != old.arrivalBaggage {
            notify(
                id: "vt_belt_\(new.id)_\(belt)",
                title: "Bagageband bekend · \(flightName)",
                body: "Je koffers komen op band \(belt)."
            )
        }
    }

    /// Directe melding (geen planning): dit gaat over iets dat nú is veranderd.
    /// Dezelfde provisional-toestemming als NotificationPlanner, dus geen
    /// popup op een ongelegen moment.
    private static func notify(id: String, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .provisional]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            // Hier opnieuw ophalen in plaats van vangen: UNUserNotificationCenter
            // is niet Sendable, en vangen in deze closure geeft een
            // concurrency-waarschuwing die onder Swift 6 een fout wordt.
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            ))
        }
    }
}

// MARK: - Store (lokaal + iCloud, meerdere vluchten)

/// Beheert alle opgeslagen vluchten. De eerstvolgende vertrekkende vlucht
/// wordt automatisch gespiegeld naar SharedFlightStore, zodat widget, Apple
/// Watch, CarPlay, Wallet en Live Activity — die allemaal maar plek hebben
/// voor één glanceable vlucht — vanzelf de juiste tonen zonder dat die
/// plekken iets van "meerdere vluchten" hoeven te weten.
@MainActor
final class FlightsStore: ObservableObject {
    static let shared = FlightsStore()
    static let storageKey = "vt_saved_flights"

    @Published private(set) var flights: [SavedFlightRecord] = []

    var sorted: [SavedFlightRecord] { flights.sorted { $0.departure < $1.departure } }
    var next: SavedFlightRecord? { sorted.first { !$0.isPast } }

    private let defaults = UserDefaults.standard

    private init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([SavedFlightRecord].self, from: data) {
            flights = decoded
        } else if let legacy = SharedFlightStore.loadFlight() {
            // Migratie: de vroeger enkele opgeslagen vlucht wordt de eerste
            // vlucht in de nieuwe lijst.
            flights = [SavedFlightRecord(
                number: legacy.number,
                airlineName: legacy.airlineName,
                airlineSlug: legacy.airlineSlug,
                departure: legacy.departure,
                departureIata: legacy.route.departureIata,
                departureAirport: legacy.route.departureAirport,
                arrivalIata: legacy.route.arrivalIata,
                arrivalAirport: legacy.route.arrivalAirport
            )]
            persist(push: false)
        }
    }

    func upsert(_ flight: SavedFlightRecord) {
        if let index = flights.firstIndex(where: { $0.id == flight.id }) {
            flights[index] = flight
        } else {
            flights.append(flight)
        }
        persist()
    }

    func remove(_ flight: SavedFlightRecord) {
        flights.removeAll { $0.id == flight.id }
        persist()
    }

    func removeAll() {
        flights = []
        persist()
    }

    /// Vanuit iCloud overgenomen — alleen lokaal schrijven, niet terugpushen.
    func adopt(data: Data) {
        guard let decoded = try? JSONDecoder().decode([SavedFlightRecord].self, from: data) else { return }
        flights = decoded
        defaults.set(data, forKey: Self.storageKey)
        syncNextFlight(push: false)
    }

    private func persist(push: Bool = true) {
        guard let data = try? JSONEncoder().encode(flights) else { return }
        defaults.set(data, forKey: Self.storageKey)
        if push { CloudSync.shared.pushFlightList(data) }
        syncNextFlight(push: push)
    }

    /// Spiegelt de eerstvolgende vlucht naar SharedFlightStore. `push`
    /// bepaalt of dit ook naar iCloud gaat (echte gebruikersactie) of alleen
    /// lokaal blijft (overgenomen ván iCloud — anders ontstaat schrijf-pingpong).
    private func syncNextFlight(push: Bool) {
        if let next {
            let route = SharedFlightStore.Route(
                departureIata: next.departureIata, departureAirport: next.departureAirport,
                arrivalIata: next.arrivalIata, arrivalAirport: next.arrivalAirport
            )
            if push {
                SharedFlightStore.saveFlight(
                    number: next.number, airlineName: next.airlineName,
                    airlineSlug: next.airlineSlug, departure: next.departure, route: route
                )
            } else {
                SharedFlightStore.adoptFlight(
                    number: next.number, airlineName: next.airlineName,
                    airlineSlug: next.airlineSlug, departure: next.departure, route: route
                )
            }
        } else if push {
            SharedFlightStore.clearFlight()
        } else {
            SharedFlightStore.adoptClearedFlight()
        }
        FlightLiveActivityManager.shared.sync()
    }
}

// MARK: - Sectie voor het profiel: lijst + toevoegen

/// Toont alle opgeslagen vluchten inline (zelfde opzet als "Mijn tassen"):
/// elke vlucht een rij die naar de detailpagina leidt, plus een knop om
/// een nieuwe vlucht toe te voegen.
struct MyFlightsSection: View {
    @ObservedObject private var store = FlightsStore.shared
    @State private var selectedFlightId: UUID?
    @State private var showAddFlight = false

    var body: some View {
        VStack(spacing: 10) {
            if store.flights.isEmpty {
                emptyState
            }

            ForEach(store.sorted) { flight in
                Button {
                    selectedFlightId = flight.id
                } label: {
                    FlightRow(flight: flight)
                }
                .buttonStyle(.plain)
            }

            Button {
                showAddFlight = true
            } label: {
                Label("Vlucht toevoegen", systemImage: "plus")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.navy.opacity(0.07))
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .navigationDestination(item: $selectedFlightId) { id in
            FlightDetailView(flightId: id)
        }
        .sheet(isPresented: $showAddFlight) {
            AddFlightSheet()
        }
    }

    /// Vriendelijke lege staat: legt kort uit wat je hier wint, in plaats van
    /// alleen een kale "toevoegen"-knop.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.sky)
                .accessibilityHidden(true)
            Text("Nog geen vlucht opgeslagen")
                .font(.frutiger(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Bewaar je vlucht en de aftelling tot vertrek verschijnt op je widget, smartwatch en lockscreen.")
                .font(.frutiger(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
    }
}

private struct FlightRow: View {
    let flight: SavedFlightRecord

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(flight.isPast ? Theme.textSecondary.opacity(0.10) : Theme.sky.opacity(0.12))
                if let photoUrl = flight.photoUrl {
                    AuthorisedImage(urlString: photoUrl, fill: true)
                } else {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 17))
                        .foregroundStyle(flight.isPast ? Theme.textSecondary : Theme.sky)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(flight.number)
                        .font(.frutiger(size: 15, weight: .bold))
                    if FlightsStore.shared.next?.id == flight.id {
                        Text("VOLGENDE")
                            .font(.frutiger(size: 8, weight: .black))
                            .foregroundStyle(Theme.navy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.yellow)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(flight.countdownLabel)
                .font(.frutiger(size: 11, weight: .bold))
                .foregroundStyle(flight.isPast ? Theme.textSecondary : Theme.navy)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .opacity(flight.isPast ? 0.6 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var subtitle: String {
        var parts: [String] = []
        if let route = flight.routeLabel { parts.append(route) }
        else if let airline = flight.airlineName { parts.append(airline) }
        parts.append(Self.dateFormatter.string(from: flight.departure))
        return parts.joined(separator: " · ")
    }
}

// MARK: - Vlucht toevoegen

/// Zoek een vluchtnummer op (zelfde bron als de kaart op Home) en bewaar
/// hem als nieuwe vlucht, met of zonder geslaagde match.
struct AddFlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flightStore = FlightStore()
    @State private var number = ""
    // Standaard: morgen om 12:00 (een neutrale reistijd), niet "morgen om de
    // huidige klok-tijd" — dat laatste liet het net lijken alsof de app de
    // huidige tijd invulde.
    @State private var departure: Date = {
        let base = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
    }()
    @State private var saved = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vluchtnummer")
                            .font(.frutiger(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.textSecondary)
                                .font(.system(size: 15))
                            TextField("bijv. KL1234 of FR7542", text: $number)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .submitLabel(.search)
                                .onSubmit(lookupNow)
                                .font(.frutiger(size: 15))
                            if flightStore.isLoading {
                                ProgressView().tint(Theme.sky).scaleEffect(0.8)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        // We zoeken vanzelf zodra je typt: geen "Zoek"-knop
                        // nodig, en de datum vullen we aan uit de match.
                        Text("Route, maatschappij en vertrekdatum worden automatisch opgehaald zodra we je vlucht herkennen.")
                            .font(.frutiger(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let result = flightStore.result {
                        lookupResultCard(result)
                    }

                    if let err = flightStore.error {
                        Label(err, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.red)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Vertrek")
                                .font(.frutiger(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            if flightStore.result != nil {
                                Label("Exacte tijd ingevuld", systemImage: "wand.and.stars")
                                    .font(.frutiger(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.green)
                            }
                        }
                        DatePicker("", selection: $departure, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Text("De exacte vertrektijd wordt automatisch opgehaald. Pas 'm aan als je afwijkt.")
                            .font(.frutiger(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Button {
                        save()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: saved ? "checkmark" : "plus.square.on.square")
                            Text(saved ? "Toegevoegd" : "Vlucht toevoegen")
                                .font(.frutiger(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(saved ? AnyShapeStyle(Theme.green) : AnyShapeStyle(Theme.inkGradient))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(saved)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Vlucht toevoegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
            .onChange(of: number) { _, newValue in
                scheduleAutoLookup(for: newValue)
            }
            .onChange(of: flightStore.result?.flightDate) { _, newDate in
                applyLookedUpDate(newDate)
            }
        }
    }

    private func lookupResultCard(_ result: FlightLookupResponse) -> some View {
        HStack(spacing: 10) {
            if let airline = result.resolvedAirline, airline.bestLogoUrl != nil {
                AuthorisedImage(urlString: airline.bestLogoUrl).frame(width: 28, height: 20)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(result.resolvedAirline?.name ?? result.rawAirlineName ?? "Onbekende maatschappij")
                    .font(.frutiger(size: 14, weight: .semibold))
                if let route = [result.departureIata, result.arrivalIata].compactMap({ $0 }).isEmpty ? nil
                    : "\(result.departureIata ?? "—") → \(result.arrivalIata ?? "—")" {
                    Text(route)
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if let status = result.statusLabel {
                Text(status)
                    .font(.frutiger(size: 10, weight: .bold))
                    .foregroundStyle(Theme.sky)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.sky.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Theme.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func lookupNow() {
        searchTask?.cancel()
        let t = number.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        Task {
            await flightStore.lookup(t)
            await applyRichDeparture(iata: flightStore.result?.flightNumber ?? t)
        }
    }

    /// Zoekt vanzelf, kort na het typen — geen "Zoek"-knop nodig. Te korte
    /// invoer annuleert een lopende zoekopdracht en wist een oud resultaat.
    private func scheduleAutoLookup(for value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 4 else {
            flightStore.result = nil
            flightStore.error = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await flightStore.lookup(trimmed)
            guard !Task.isCancelled else { return }
            await applyRichDeparture(iata: flightStore.result?.flightNumber ?? trimmed)
        }
    }

    /// Vult het exacte vertrek-tíjdstip in via Aviationstack (Pro). Een
    /// vluchtnummer vertrekt elke dag op dezelfde klok-tijd, dus we plakken
    /// alléén die tijd op de door de gebruiker gekozen reisdatum — de datum
    /// blijft van de gebruiker (Aviationstack free kent alleen de occurrence
    /// van vandaag, dus de datum daaruit overnemen zou juist fout zijn).
    ///
    /// Haalt de exacte vertrektijd op bij Aviationstack. Let op: dat quotum is
    /// beperkt (100/maand op het gratis plan) en werd eerder afgeschermd met
    /// Pro; nu iedereen erbij kan, is dit de plek om te bewaken als het
    /// quotum knelt.
    private func applyRichDeparture(iata: String) async {
        guard let rich = await AviationstackClient.lookup(iata: iata, near: departure),
              let scheduledISO = rich.departure?.scheduled,
              let (hour, minute) = Self.wallClockTime(fromISO: scheduledISO)
        else { return }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: departure)
        comps.hour = hour
        comps.minute = minute
        guard let combined = cal.date(from: comps) else { return }
        // Clamp naar "nu" zodat de DatePicker (ondergrens Date()...) een
        // net-verstreken tijdstip niet stilletjes terugklemt.
        withAnimation(.spring(response: 0.3)) { departure = max(combined, .now) }
    }

    /// Leest het wall-clock-tijdstip ("...T14:20:00...") rechtstreeks uit de
    /// ISO-string i.p.v. uit een geparste Date: Aviationstack drukt lokale
    /// vertrektijden soms met een +00:00-offset uit, waardoor het uur zou
    /// verschuiven als je 'm eerst naar een absolute Date converteert.
    private static func wallClockTime(fromISO iso: String) -> (hour: Int, minute: Int)? {
        guard let tIndex = iso.firstIndex(of: "T") else { return nil }
        let timePart = iso[iso.index(after: tIndex)...].prefix(5)   // "14:20"
        let parts = timePart.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return (h, m)
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    /// Backend-`flight_date` alléén vooruit toepassen. De backend (die
    /// Aviationstack server-side gebruikt) geeft voor een dagelijks
    /// vluchtnummer de occurrence van vandáág terug — niet de reisdatum die de
    /// gebruiker bedoelt. Vroeger klemde deze functie de picker daardoor naar
    /// "vandaag" (de kern van de gemelde bug). Nu verschuiven we de datum
    /// alleen als de lookup een látere dag kent dan de al gekozen datum; een
    /// gelijke of eerdere dag negeren we, zodat de gekozen reisdatum blijft
    /// staan.
    private func applyLookedUpDate(_ raw: String?) {
        guard let raw, let parsed = Self.isoDateFormatter.date(from: raw) else { return }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: parsed)
        let time = cal.dateComponents([.hour, .minute], from: departure)
        comps.hour = time.hour
        comps.minute = time.minute
        guard let combined = cal.date(from: comps) else { return }
        guard cal.startOfDay(for: combined) > cal.startOfDay(for: departure) else { return }
        withAnimation(.spring(response: 0.3)) { departure = max(combined, .now) }
    }

    private func save() {
        let result = flightStore.result
        let trimmedNumber = number.trimmingCharacters(in: .whitespaces).uppercased()
        let flight = SavedFlightRecord(
            number: result?.flightNumber ?? (trimmedNumber.isEmpty ? "Mijn vlucht" : trimmedNumber),
            airlineName: result?.resolvedAirline?.name ?? result?.rawAirlineName,
            airlineSlug: result?.resolvedAirline?.slug,
            airlineLogoUrl: result?.resolvedAirline?.bestLogoUrl ?? result?.airlineLogoUrl,
            flightIcao: result?.flightIcao,
            departure: departure,
            departureIata: result?.departureIata,
            departureAirport: result?.departureAirport,
            arrivalIata: result?.arrivalIata,
            arrivalAirport: result?.arrivalAirport,
            flightDate: result?.flightDate,
            status: result?.status
        )
        FlightsStore.shared.upsert(flight)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }

        // Verrijking op de achtergrond — de "toegevoegd"-animatie hoeft hier
        // niet op te wachten, zelfde fire-and-forget-patroon als de
        // Unsplash-tripfoto in TripWizardView.createTrip().
        let flightId = flight.id
        let iata = flight.number
        let targetDate = flight.departure
        let photoQuery = flight.arrivalAirport ?? flight.airlineName
        Task { @MainActor in
            if let rich = await AviationstackClient.lookup(iata: iata, near: targetDate) {
                guard var updated = FlightsStore.shared.flights.first(where: { $0.id == flightId }) else { return }
                updated.applyRichData(rich)
                updated.lastRefreshed = Date()
                FlightsStore.shared.upsert(updated)
            }
        }
        if let photoQuery {
            Task { @MainActor in
                guard let photo = await UnsplashClient.searchPhoto(query: photoQuery) else { return }
                guard var updated = FlightsStore.shared.flights.first(where: { $0.id == flightId }) else { return }
                updated.photoUrl = photo.regularUrl
                updated.photoAuthorName = photo.authorName
                updated.photoAuthorUrl = photo.authorProfileUrl
                FlightsStore.shared.upsert(updated)
            }
        }
    }
}

// MARK: - Vlucht detailpagina

private var flightDetailStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

/// Alles wat we van een vlucht weten, op één premium pagina: boardingpass-
/// achtige route, status, countdown en een link naar de bagageregels.
struct FlightDetailView: View {
    let flightId: UUID

    @EnvironmentObject private var airlineStore: AirlineStore
    @ObservedObject private var store = FlightsStore.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logoLoader = ImageLoader()
    @State private var brandTint: Color?
    @State private var isRefreshing = false
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    @State private var showAirline: Airline?

    private var flight: SavedFlightRecord? { store.flights.first { $0.id == flightId } }
    private var accent: Color { brandTint ?? Theme.sky }

    private var matchedAirline: Airline? {
        guard let slug = flight?.airlineSlug else { return nil }
        return airlineStore.airlines.first { $0.slug == slug }
    }

    var body: some View {
        Group {
            if let flight {
                ZStack(alignment: .top) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            hero(flight)
                                // Bij het openen van een vlucht meteen kijken of
                                // er nieuwe gate-/vertragingsinfo is. De wacht
                                // throttelt zelf, dus dit is niet duur.
                                .task { await FlightWatcher.refreshDueFlights() }
                            content(flight)
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .padding(.bottom, 40)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .background(Color(.systemGroupedBackground))

                    HStack {
                        FloatingBackButton { dismiss() }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, flightDetailStatusBarHeight + 10)
                }
                .onAppear {
                    if let url = flight.airlineLogoUrl { logoLoader.load(url) }
                }
                .onReceive(logoLoader.$image) { image in
                    guard let color = image?.brandColor else { return }
                    withAnimation(.easeInOut(duration: 0.5)) { brandTint = Color(uiColor: color) }
                }
            } else {
                // Verwijderd (bijv. via een ander apparaat) terwijl je hier keek.
                ContentUnavailableView("Vlucht niet meer beschikbaar", systemImage: "airplane")
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $showAirline) { airline in
            AirlineDetailView(airline: airline)
        }
    }

    // MARK: - Hero

    private func hero(_ flight: SavedFlightRecord) -> some View {
        ZStack(alignment: .bottom) {
            if let photoUrl = flight.photoUrl {
                AuthorisedImage(urlString: photoUrl, fill: true)
                    .frame(height: 230 + flightDetailStatusBarHeight)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Color(.systemGroupedBackground)],
                            startPoint: .center, endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: [accent.opacity(0.18), Color(.systemGroupedBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 230 + flightDetailStatusBarHeight)
            }

            if let authorName = flight.photoAuthorName,
               let authorUrl = flight.photoAuthorUrl.flatMap({ URL(string: $0 + "?utm_source=vliegtuigtas&utm_medium=referral") }) {
                Link("Foto: \(authorName) / Unsplash", destination: authorUrl)
                    .font(.frutiger(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.25), in: Capsule())
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, flightDetailStatusBarHeight + 4)
            }

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                        )
                    if flight.airlineLogoUrl != nil {
                        AuthorisedImage(urlString: flight.airlineLogoUrl)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "airplane")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.sky)
                    }
                }

                VStack(spacing: 4) {
                    Text(flight.number)
                        .font(.frutiger(size: 26, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let airline = flight.airlineName {
                        Text(airline)
                            .font(.frutiger(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(flight.countdownLabel)
                        .font(.frutiger(size: 12, weight: .bold))
                        .foregroundStyle(flight.isPast ? Theme.textSecondary : Theme.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(flight.isPast ? Theme.textSecondary.opacity(0.12) : Theme.yellow)
                        .clipShape(Capsule())

                    if let label = flight.statusLabel {
                        Text(label)
                            .font(.frutiger(size: 12, weight: .bold))
                            .foregroundStyle(flight.statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(flight.statusColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ flight: SavedFlightRecord) -> some View {
        VStack(spacing: 16) {
            if flight.hasRoute {
                FlightBoardingPassCard(flight: flight)
                FlightStatusTimeline(flight: flight)
                if flight.hasLivePosition {
                    LiveFlightMapCard(flight: flight)
                }
                if flight.aircraftRegistration != nil || flight.aircraftIcao24 != nil {
                    AircraftInfoChip(flight: flight)
                }
                // Aankomstdag: de exacte arrivalScheduled uit Aviationstack als
                // die bekend is; anders de (door de gebruiker gekozen)
                // vertrekdatum als benadering van de aankomstdag.
                DestinationWeatherCard(
                    airportName: flight.arrivalAirport,
                    iata: flight.arrivalIata,
                    arrivalDate: flight.arrivalScheduled ?? flight.departure
                )
            }

            detailsCard(flight)

            if let airline = matchedAirline {
                Button {
                    showAirline = airline
                } label: {
                    HStack(spacing: 8) {
                        AirlineLogo(airline: airline, size: 22)
                        Text("Bekijk bagageregels van \(airline.name)")
                            .font(.frutiger(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.navy)
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    refreshStatus(flight)
                } label: {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView().tint(Theme.navy).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Vernieuw status")
                    }
                    .font(.frutiger(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.navy.opacity(0.07))
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing || flight.number.isEmpty)

                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 44, height: 44)
                        .background(Theme.navy.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Vlucht aanpassen")

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.red)
                        .frame(width: 44, height: 44)
                        .background(Theme.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Text("Vluchtinformatie is een indicatie. Controleer altijd de officiële status bij je maatschappij.")
                .font(.frutiger(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showEdit) {
            FlightEditSheet(flight: flight)
        }
        .confirmationDialog(
            "Vlucht verwijderen?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Verwijder deze vlucht", role: .destructive) {
                store.remove(flight)
                dismiss()
            }
            Button("Annuleer", role: .cancel) {}
        }
    }

    private func detailsCard(_ flight: SavedFlightRecord) -> some View {
        VStack(spacing: 0) {
            detailRow(icon: "calendar", label: "Vertrek", value: formattedDeparture(flight.departure))
            if let icao = flight.flightIcao {
                Divider().padding(.leading, 44)
                detailRow(icon: "number", label: "ICAO-code", value: icao)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.navy)
                .frame(width: 20)
            Text(label)
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.frutiger(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 12)
    }

    private static let departureFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func formattedDeparture(_ date: Date) -> String {
        Self.departureFormatter.string(from: date)
    }

    private func refreshStatus(_ flight: SavedFlightRecord) {
        isRefreshing = true
        Task {
            if let result = try? await APIClient.shared.flightLookup(number: flight.number) {
                var updated = flight
                updated.airlineName = result.resolvedAirline?.name ?? result.rawAirlineName ?? updated.airlineName
                updated.airlineSlug = result.resolvedAirline?.slug ?? updated.airlineSlug
                updated.airlineLogoUrl = result.resolvedAirline?.bestLogoUrl ?? result.airlineLogoUrl ?? updated.airlineLogoUrl
                updated.flightIcao = result.flightIcao ?? updated.flightIcao
                updated.departureIata = result.departureIata ?? updated.departureIata
                updated.departureAirport = result.departureAirport ?? updated.departureAirport
                updated.arrivalIata = result.arrivalIata ?? updated.arrivalIata
                updated.arrivalAirport = result.arrivalAirport ?? updated.arrivalAirport
                updated.flightDate = result.flightDate ?? updated.flightDate
                updated.status = result.status ?? updated.status
                if let rich = await AviationstackClient.lookup(iata: flight.number, near: flight.departure) {
                    updated.applyRichData(rich)
                }
                // Stempelen, zodat de vluchtwacht niet meteen opnieuw ophaalt.
                updated.lastRefreshed = Date()
                store.upsert(updated)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isRefreshing = false
        }
    }
}

/// Boardingpass-achtige routekaart: grote IATA-codes, luchthavennamen en een
/// geperforeerde scheidingslijn, met het vliegtuigje ertussen.
private struct FlightBoardingPassCard: View {
    let flight: SavedFlightRecord

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                endpoint(
                    code: flight.departureIata, airport: flight.departureAirport, alignment: .leading,
                    terminal: flight.departureTerminal, gate: flight.departureGate,
                    scheduled: flight.departureScheduled, actualOrEstimated: flight.departureActual ?? flight.departureEstimated,
                    delayMinutes: flight.departureDelayMinutes
                )
                VStack(spacing: 3) {
                    Image(systemName: "airplane")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.sky)
                    perforatedLine
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                endpoint(
                    code: flight.arrivalIata, airport: flight.arrivalAirport, alignment: .trailing,
                    terminal: flight.arrivalTerminal, gate: flight.arrivalGate,
                    scheduled: flight.arrivalScheduled, actualOrEstimated: flight.arrivalActual ?? flight.arrivalEstimated,
                    delayMinutes: flight.arrivalDelayMinutes
                )
            }
            .padding(18)

            // Aftelstrip onderaan de kaart, zoals luchthaven-apps die tonen:
            // één regel die zegt hoeveel tijd je nog hebt, plus de bagageband
            // zodra die bekend is.
            if let strip = countdownStrip {
                HStack(spacing: 8) {
                    Image(systemName: strip.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.navy)
                    Text(strip.text)
                        .font(.frutiger(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                    if let belt = flight.arrivalBaggage {
                        HStack(spacing: 4) {
                            Text("Band")
                                .font(.frutiger(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                            Text(belt)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.skyLight)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    /// "4u 3m voor vertrek" — of de fase waarin de vlucht zit als vertrek al
    /// geweest is.
    private var countdownStrip: (icon: String, text: String)? {
        let interval = flight.departure.timeIntervalSinceNow
        if interval > 0 {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            if hours >= 24 {
                let days = hours / 24
                return ("clock", days == 1 ? "Morgen vertrek" : "Nog \(days) dagen tot vertrek")
            }
            return ("clock", hours > 0 ? "\(hours)u \(minutes)m voor vertrek" : "\(minutes)m voor vertrek")
        }
        if let label = flight.statusLabel {
            return ("airplane", label)
        }
        return ("airplane", "Vertrokken")
    }

    private var perforatedLine: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { _ in
                Circle().fill(Theme.textSecondary.opacity(0.25)).frame(width: 3, height: 3)
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.timeStyle = .short
        return f
    }()

    private func endpoint(
        code: String?, airport: String?, alignment: HorizontalAlignment,
        terminal: String?, gate: String?,
        scheduled: Date?, actualOrEstimated: Date?, delayMinutes: Int?
    ) -> some View {
        // Opbouw zoals professionele luchthaven-apps die aanhouden: de plaats
        // klein bovenaan, de tíjd als blikvanger, daaronder de status, en pas
        // dan de praktische velden. Wie naar zijn vlucht kijkt wil eerst weten
        // hoe laat en of het op tijd is — niet welke IATA-code erbij hoort.
        let delayed = (delayMinutes ?? 0) > 0
        return VStack(alignment: alignment, spacing: 5) {
            HStack(spacing: 5) {
                if let airport {
                    Text(airport)
                        .font(.frutiger(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                if let code {
                    Text(code)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if let scheduled {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Self.timeFormatter.string(from: delayed ? (actualOrEstimated ?? scheduled) : scheduled))
                        .font(.system(size: 26, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    if delayed, actualOrEstimated != nil {
                        Text(Self.timeFormatter.string(from: scheduled))
                            .font(.frutiger(size: 12, weight: .semibold))
                            .strikethrough()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            } else {
                Text(code ?? "—")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
            }

            // Statuspil, zoals het groene "Op tijd" op een vertrekbord.
            if scheduled != nil {
                StatusPill(
                    text: delayed ? "+\(delayMinutes ?? 0) min" : "Op tijd",
                    tone: delayed ? .negative : .positive
                )
            }

            // Praktische velden onder elkaar met een label ervoor — de gate
            // krijgt een geel pilletje omdat dat het getal is waar je op de
            // luchthaven naar zoekt.
            if let terminal {
                FactLine(label: "Terminal", value: terminal, alignment: alignment)
            }
            if let gate {
                FactLine(label: "Gate", value: gate, highlighted: true, alignment: alignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

}

// MARK: - Vlucht aanpassen

/// Een opgeslagen vlucht was alleen te verwijderen. Een verkeerd overgetypt
/// vluchtnummer of een verschoven vertrektijd betekende dus: weggooien en
/// opnieuw invoeren. Hier corrigeer je wat er mis is.
private struct FlightEditSheet: View {
    let flight: SavedFlightRecord

    @ObservedObject private var store = FlightsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var number: String
    @State private var departure: Date
    @State private var from: RouteAirport?
    @State private var to: RouteAirport?
    @State private var pickingFrom = false
    @State private var pickingTo = false

    init(flight: SavedFlightRecord) {
        self.flight = flight
        _number = State(initialValue: flight.number)
        _departure = State(initialValue: flight.departure)
        _from = State(initialValue: flight.departureIata.flatMap { RouteAirports.find(iata: $0) })
        _to = State(initialValue: flight.arrivalIata.flatMap { RouteAirports.find(iata: $0) })
    }

    private var canSave: Bool {
        !number.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vlucht") {
                    TextField("Vluchtnummer of naam", text: $number)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    DatePicker("Vertrek", selection: $departure,
                               displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Button { pickingFrom = true } label: {
                        routeRow(label: "Van", airport: from)
                    }
                    Button { pickingTo = true } label: {
                        routeRow(label: "Naar", airport: to)
                    }
                } header: {
                    Text("Route")
                } footer: {
                    Text("De route bepaalt wat er op je widget, Apple Watch en in CarPlay staat.")
                }
            }
            .navigationTitle("Vlucht aanpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bewaar") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $pickingFrom) {
                AirportPickerSheet(title: "Van welke luchthaven?", selection: $from)
            }
            .sheet(isPresented: $pickingTo) {
                AirportPickerSheet(title: "Waar vlieg je heen?", selection: $to)
            }
        }
    }

    private func routeRow(label: String, airport: RouteAirport?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(airport?.shortLabel ?? "Kies")
                .foregroundStyle(airport == nil ? Theme.textSecondary : Theme.navy)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func save() {
        var updated = flight
        updated.number = number.trimmingCharacters(in: .whitespaces)
        updated.departure = departure
        updated.departureIata = from?.iata
        updated.departureAirport = from.map { "\($0.name), \($0.city)" }
        updated.arrivalIata = to?.iata
        updated.arrivalAirport = to.map { "\($0.name), \($0.city)" }
        // Handmatig gewijzigd, dus de opgehaalde tijden kloppen mogelijk niet
        // meer. Stempel wissen zodat de vluchtwacht opnieuw ophaalt.
        updated.lastRefreshed = nil
        store.upsert(updated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Status-tijdlijn

/// Horizontale voortgangsbalk door de vier vluchtfases — vervangt de kale
/// "ruwe status"-tekst met iets dat in één oogopslag te lezen is.
private struct FlightStatusTimeline: View {
    let flight: SavedFlightRecord

    private enum Phase: Int, CaseIterable {
        case scheduled, departed, inAir, landed

        var label: String {
            switch self {
            case .scheduled: return "Gepland"
            case .departed:  return "Vertrokken"
            case .inAir:     return "In de lucht"
            case .landed:    return "Geland"
            }
        }

        var icon: String {
            switch self {
            case .scheduled: return "clock"
            case .departed:  return "airplane.departure"
            case .inAir:     return "airplane"
            case .landed:    return "airplane.arrival"
            }
        }
    }

    /// Aviationstack kent geen apart "departed"-fase (alleen scheduled/
    /// active/landed/...) — bij "active" tonen we 'm als voorbij vertrokken
    /// én onderweg, dus de balk vult tot en met "In de lucht".
    private var currentPhase: Phase {
        switch flight.status {
        case "active":    return .inAir
        case "landed":    return .landed
        default:          return .scheduled
        }
    }

    private var isProblematic: Bool {
        ["cancelled", "incident", "diverted"].contains(flight.status)
    }

    var body: some View {
        VStack(spacing: 10) {
            if isProblematic, let label = flight.statusLabel {
                Label(label, systemImage: "exclamationmark.triangle.fill")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 0) {
                    ForEach(Phase.allCases, id: \.rawValue) { phase in
                        phaseView(phase)
                        if phase != Phase.allCases.last {
                            Rectangle()
                                .fill(phase.rawValue < currentPhase.rawValue ? Theme.navy : Theme.textSecondary.opacity(0.2))
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func phaseView(_ phase: Phase) -> some View {
        let reached = phase.rawValue <= currentPhase.rawValue
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(reached ? Theme.navy : Theme.textSecondary.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: phase.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(reached ? .white : Theme.textSecondary)
            }
            Text(phase.label)
                .font(.frutiger(size: 9, weight: .semibold))
                .foregroundStyle(reached ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Vliegtuiginfo

private struct AircraftInfoChip: View {
    let flight: SavedFlightRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.sky)
            VStack(alignment: .leading, spacing: 1) {
                Text("Vliegtuig")
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Text([flight.aircraftRegistration, flight.aircraftIcao24].compactMap { $0 }.joined(separator: " · "))
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Live positie

/// Compact, niet-interactief kaartje met de actuele positie — alleen
/// zichtbaar bij een vlucht die nu in de lucht is. Het "wow"-element dat een
/// vlucht-tracker modern maakt.
private struct LiveFlightMapCard: View {
    let flight: SavedFlightRecord

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = flight.liveLatitude, let lon = flight.liveLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        if let coordinate {
            VStack(alignment: .leading, spacing: 0) {
                Map(initialPosition: .region(
                    MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4))
                )) {
                    Annotation("", coordinate: coordinate) {
                        Image(systemName: "airplane")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Theme.navy, in: Circle())
                            .rotationEffect(.degrees((flight.liveDirection ?? 0) - 90))
                    }
                }
                .disabled(true)
                .frame(height: 160)

                HStack(spacing: 16) {
                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                        .font(.frutiger(size: 11, weight: .bold))
                        .foregroundStyle(Theme.green)
                    if let altitude = flight.liveAltitude {
                        Text("\(Int(altitude.rounded())) m hoogte")
                    }
                    if let speed = flight.liveSpeedKmh {
                        Text("\(Int(speed.rounded())) km/u")
                    }
                    Spacer()
                }
                .font(.frutiger(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(12)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
