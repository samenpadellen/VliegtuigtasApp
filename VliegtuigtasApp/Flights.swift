import SwiftUI

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

    var hasRoute: Bool { departureIata != nil && arrivalIata != nil }

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
                    .frame(width: 44, height: 44)
                Image(systemName: "airplane.departure")
                    .font(.system(size: 17))
                    .foregroundStyle(flight.isPast ? Theme.textSecondary : Theme.sky)
            }
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

    private var subtitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "nl_NL")
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        var parts: [String] = []
        if let route = flight.routeLabel { parts.append(route) }
        else if let airline = flight.airlineName { parts.append(airline) }
        parts.append(fmt.string(from: flight.departure))
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
    @State private var departure = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
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
                            if flightStore.result?.flightDate != nil {
                                Label("Automatisch ingevuld", systemImage: "wand.and.stars")
                                    .font(.frutiger(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.green)
                            }
                        }
                        DatePicker("", selection: $departure, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Text("Tijd is een indicatie: pas 'm aan als je exacte vertrektijd afwijkt.")
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
                        .background(saved ? AnyShapeStyle(Theme.green) : AnyShapeStyle(Theme.navyGradient))
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
        Task { await flightStore.lookup(t) }
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
        }
    }

    /// Vult de vertrekdatum aan uit de match — de dag komt uit de lookup,
    /// het tijdstip (niet beschikbaar via de API) blijft wat er al stond
    /// staan, of de standaardtijd als dit de eerste match is.
    private func applyLookedUpDate(_ raw: String?) {
        guard let raw else { return }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let parsed = iso.date(from: raw) else { return }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: parsed)
        let time = cal.dateComponents([.hour, .minute], from: departure)
        comps.hour = time.hour
        comps.minute = time.minute
        // Een looked-up datum in het verleden (herhalend vluchtnummer, andere
        // dag) negeren we: dan weet de gebruiker het zelf beter dan de API.
        if let combined = cal.date(from: comps), combined > .now {
            withAnimation(.spring(response: 0.3)) { departure = combined }
        }
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
            LinearGradient(
                colors: [accent.opacity(0.18), Color(.systemGroupedBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 230 + flightDetailStatusBarHeight)

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
            if let raw = flight.flightDate {
                Divider().padding(.leading, 44)
                detailRow(icon: "airplane.circle", label: "Vluchtdatum (API)", value: raw)
            }
            if let status = flight.status {
                Divider().padding(.leading, 44)
                detailRow(icon: "dot.radiowaves.left.and.right", label: "Ruwe status", value: status)
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

    private func formattedDeparture(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "nl_NL")
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
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
            HStack(alignment: .center, spacing: 12) {
                endpoint(code: flight.departureIata, airport: flight.departureAirport, alignment: .leading)
                VStack(spacing: 3) {
                    Image(systemName: "airplane")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.sky)
                    perforatedLine
                }
                .frame(maxWidth: .infinity)
                endpoint(code: flight.arrivalIata, airport: flight.arrivalAirport, alignment: .trailing)
            }
            .padding(18)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var perforatedLine: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { _ in
                Circle().fill(Theme.textSecondary.opacity(0.25)).frame(width: 3, height: 3)
            }
        }
    }

    private func endpoint(code: String?, airport: String?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code ?? "—")
                .font(.frutiger(size: 26, weight: .black))
                .foregroundStyle(Theme.navy)
                .kerning(1)
            if let airport {
                Text(airport)
                    .font(.frutiger(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}
