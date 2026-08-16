import SwiftUI

// MARK: - Lijst: Mijn reizen

/// Tabroot voor "Reizen": vastgezette reizen, aankomende reizen en (gedimd)
/// afgelopen reizen — zelfde opzet als MyFlightsSection maar dan met eigen
/// paklijst per reis.
/// De Reizen-tab bundelt alles wat je vóór vertrek regelt: je reizen met hun
/// paklijst, je opgeslagen vluchten en de inpak-alarmen. "Mijn vluchten" stond
/// tot 3.0.0 in het profiel — een reisfunctie verstopt tussen de instellingen.
struct TripsListView: View {
    @ObservedObject private var store = TripsStore.shared
    @State private var selectedTripId: UUID?
    @State private var showWizard = false
    @State private var showAlarms = false
    @State private var showDepartureReminder = false
    @State private var hiddenUnlocked = false
    @State private var lockFailed = false
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoomNamespace

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                tripsBlock
                flightsBlock
                alarmsCard
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.base)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reizen")
        .navigationDestination(item: $selectedTripId) { id in
            TripDetailView(tripId: id)
                .zoomDestination(id: id, in: zoomNamespace)
        }
        .sheet(isPresented: $showWizard) {
            TripWizardView()
        }
        .sheet(isPresented: $showAlarms) {
            PackingAlarmsSheet()
        }
        .sheet(isPresented: $showDepartureReminder) {
            DepartureReminderSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Zodra de app naar de achtergrond gaat, gaat het slot er weer op.
        // Anders blijft een ontgrendelde lijst open staan zodra je je telefoon
        // even uit handen geeft — precies het scenario waar dit voor bedoeld is.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { hiddenUnlocked = false }
        }
    }

    /// De reis die er nú toe doet: een vastgezette reis wint, anders de
    /// eerstvolgende. Die krijgt de grote kaart; de rest blijft compact.
    private var heroTrip: Trip? { store.pinned.first ?? store.next }

    /// Aankomende reizen minus de hero — die staat al groot bovenaan.
    private var otherUpcoming: [Trip] {
        (store.pinned + store.upcoming).filter { $0.id != heroTrip?.id }
    }

    private var tripsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Mijn reizen")

            if store.trips.isEmpty {
                emptyState
            } else {
                if let heroTrip {
                    TripHeroCard(trip: heroTrip) { selectedTripId = heroTrip.id }
                        .zoomSource(id: heroTrip.id, in: zoomNamespace)
                } else {
                    // Wél reizen gemaakt, maar allemaal geweest. Zonder dit
                    // sprong het scherm van de kop "Mijn reizen" recht naar
                    // "Herinneringen" — alsof er iets ontbrak.
                    noUpcomingCard
                }

                if !otherUpcoming.isEmpty {
                    section(title: "Daarna", trips: otherUpcoming)
                }

                if !store.past.isEmpty {
                    memoriesStrip
                }

                hiddenTripsSection
            }

            Button {
                showWizard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Nieuwe reis plannen")
                        .font(.frutiger(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.base)
                .background(Theme.inkGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
        }
    }

    /// Verborgen reizen: alleen zichtbaar ná authenticatie met Face ID, Touch ID
    /// of de toegangscode van het toestel. De sectie verschijnt alleen als je
    /// daadwerkelijk iets verborgen hebt — anders verraadt de knop zelf al dat
    /// er iets te verbergen valt.
    @ViewBuilder
    private var hiddenTripsSection: some View {
        if store.hasHiddenTrips {
            VStack(alignment: .leading, spacing: 10) {
                if hiddenUnlocked {
                    HStack {
                        Text("VERBORGEN")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .kerning(1.1)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button {
                            withAnimation(.snappy) { hiddenUnlocked = false }
                        } label: {
                            Label("Verberg weer", systemImage: "eye.slash")
                                .font(.frutiger(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.navy)
                        }
                    }

                    ForEach(store.hidden) { trip in
                        Button {
                            selectedTripId = trip.id
                        } label: {
                            TripRow(trip: trip)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                store.setHidden(false, tripId: trip.id)
                            } label: {
                                Label("Weer tonen", systemImage: "eye")
                            }
                        }
                    }
                } else {
                    Button {
                        unlockHiddenTrips()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                            Text("Verborgen reizen")
                                .font(.frutiger(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text("Ontgrendel")
                                .font(.frutiger(size: 12, weight: .bold))
                                .foregroundStyle(Theme.navy)
                        }
                        .padding(Theme.Spacing.base)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }
                    .buttonStyle(.plain)

                    if lockFailed {
                        Text(HiddenTripsLock.isDeviceProtected
                             ? "Ontgrendelen is geannuleerd."
                             : "Stel een toegangscode of Face ID in op je iPhone om verborgen reizen te kunnen bekijken.")
                            .font(.frutiger(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func unlockHiddenTrips() {
        Task {
            let ok = await HiddenTripsLock.authenticate()
            withAnimation(.snappy) {
                hiddenUnlocked = ok
                lockFailed = !ok
            }
        }
    }

    /// Je hebt gereisd, maar er staat niets nieuws gepland. Geen lege staat
    /// (je bent geen nieuwe gebruiker), maar wel een duidelijke stand van zaken
    /// plus de logische volgende stap.
    private var noUpcomingCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.yellow)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Geen reis gepland")
                    .font(.frutiger(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(lastTripLine)
                    .font(.frutiger(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    /// Verwijst naar je laatste reis, zodat de kaart persoonlijk aanvoelt in
    /// plaats van een standaardmelding.
    private var lastTripLine: String {
        // `past` loopt van oud naar nieuw; we willen de meest recente reis.
        guard let last = recentMemories.first else {
            return "Plan je volgende reis en je paklijst staat zo klaar."
        }
        let destination = last.destination ?? last.name
        return "Sinds \(destination) staat er niets nieuws op de planning."
    }

    /// Herinneringen nieuwste eerst: `store.past` loopt van oud naar nieuw,
    /// en je laatste reis wil je vooraan zien staan.
    private var recentMemories: [Trip] { store.past.reversed() }

    /// Afgelopen reizen als herinneringen: een horizontale strook fotokaarten
    /// in plaats van vergrijsde lijstrijen. Wat je hebt gedaan verdient een
    /// betere plek dan "Eerder" onderaan met 60% opacity.
    private var memoriesStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HERINNERINGEN")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .kerning(1.1)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(store.past.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentMemories) { trip in
                        Button {
                            selectedTripId = trip.id
                        } label: {
                            MemoryCard(trip: trip)
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
                .padding(.vertical, Theme.Spacing.xxs)
            }
        }
    }

    private var flightsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mijn vluchten")
            MyFlightsSection()

            Button {
                showDepartureReminder = true
            } label: {
                Label("Geen vluchtnummer? Zet een vertrekreminder",
                      systemImage: "bell.badge.fill")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.navy.opacity(0.07))
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
        }
    }

    /// Inpak-alarmen hingen als sheet achter de Home-feed; hier staan ze naast
    /// de reis waar ze bij horen.
    private var alarmsCard: some View {
        Button {
            showAlarms = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.yellow)
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Inpak-alarmen")
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Word op tijd herinnerd aan je koffer")
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.Spacing.base)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.pressableCard)
    }

    private func section(title: String, trips: [Trip]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.frutiger(size: 13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)

            ForEach(trips) { trip in
                Button {
                    selectedTripId = trip.id
                } label: {
                    TripRow(trip: trip)
                }
                .buttonStyle(.plain)
                .zoomSource(id: trip.id, in: zoomNamespace)
                .contextMenu {
                    Button {
                        var updated = trip
                        updated.isPinned.toggle()
                        store.upsert(updated)
                    } label: {
                        Label(trip.isPinned ? "Losmaken" : "Vastzetten",
                              systemImage: trip.isPinned ? "pin.slash" : "pin")
                    }
                    Button {
                        store.setHidden(!trip.isHidden, tripId: trip.id)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label(trip.isHidden ? "Weer tonen" : "Verberg deze reis",
                              systemImage: trip.isHidden ? "eye" : "eye.slash")
                    }
                }
            }
        }
    }

    /// Lege staat als uitnodiging in plaats van een mededeling: laat zien wát
    /// een reis oplevert, niet dat er niets is.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Illustratie boven de tekst: een leeg scherm met alleen woorden
            // voelt als een foutmelding, niet als een uitnodiging.
            AirportScene(height: 140)

            VStack(alignment: .leading, spacing: 6) {
                Text("Plan je eerste reis")
                    .font(.frutiger(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("In vier vragen staat je paklijst klaar, afgestemd op waar je heen gaat en hoe lang.")
                    .font(.frutiger(size: 13))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                emptyPerk(icon: "checklist", text: "Paklijst op maat van je reissoort")
                emptyPerk(icon: "timer", text: "Aftelling en voortgang tot vertrek")
                emptyPerk(icon: "book.closed.fill", text: "Komt na afloop in je reispaspoort")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.base)
        .background(Theme.inkGradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    private func emptyPerk(icon: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 22, height: 22)
                .background(Theme.yellow, in: Circle())
            Text(text)
                .font(.frutiger(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Voortgangskaart voor de bucket list. Staat sinds 3.0.0 bovenaan "Jouw
/// reiswereld" in de Meer-hub: één plek voor bucket list en paspoort, met de
/// voortgang meteen zichtbaar in plaats van achter een tegel.
///
/// De landenfoto's staan als overlappende, cirkelvormige "stempels" — dat
/// verwijst naar het reispaspoort verderop in dezelfde sectie — met een
/// voortgangsbalk voor het percentage van de wereld dat je al bezocht hebt.
struct BucketListPreviewCard: View {
    @ObservedObject private var store = BucketListStore.shared
    @ObservedObject private var photoCache = CountryPhotoCache.shared
    let action: () -> Void

    private var highlighted: [Country] {
        Array((store.visitedCountries + allCountries.filter { store.status(for: $0) == .wantToVisit }).prefix(5))
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Jouw bucket list")
                            .font(.frutiger(size: 14, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(store.visitedCount)/\(allCountries.count) landen · \(store.visitedContinents.count) continenten")
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                if !highlighted.isEmpty {
                    HStack(spacing: -14) {
                        ForEach(Array(highlighted.enumerated()), id: \.element.id) { index, country in
                            ZStack {
                                Circle().fill(Theme.navy.opacity(0.08))
                                if let photoUrl = photoCache.photo(for: country)?.url {
                                    AuthorisedImage(urlString: photoUrl, fill: true)
                                } else {
                                    Text(country.flagEmoji).font(.system(size: 20))
                                }
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2.5))
                            .zIndex(Double(highlighted.count - index))
                        }
                        Spacer()
                    }
                }

                worldProgressBar
            }
            .padding(Theme.Spacing.base)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var worldProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.navy.opacity(0.08))
                Capsule().fill(Theme.yellow)
                    .frame(width: max(6, geo.size.width * store.percentWorld / 100))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Reis aanpassen

/// Een reis was tot nu toe alleen te verwijderen. Een verkeerde datum of een
/// typefout in de naam betekende dus: weggooien en opnieuw beginnen, inclusief
/// je afgevinkte paklijst. Hier pas je aan wat er mis is en blijft de rest staan.
private struct TripEditSheet: View {
    let trip: Trip

    @ObservedObject private var store = TripsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var luggageType: LuggageType
    @State private var style: TripStyle?
    @State private var isHidden: Bool

    init(trip: Trip) {
        self.trip = trip
        _name = State(initialValue: trip.name)
        _destination = State(initialValue: trip.destination ?? "")
        _startDate = State(initialValue: trip.startDate)
        _endDate = State(initialValue: trip.endDate)
        _luggageType = State(initialValue: trip.luggageType)
        _style = State(initialValue: trip.style)
        _isHidden = State(initialValue: trip.isHidden)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reis") {
                    TextField("Naam", text: $name)
                    TextField("Bestemming", text: $destination)
                }

                Section("Data") {
                    DatePicker("Vertrek", selection: $startDate, displayedComponents: .date)
                    DatePicker("Terug", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section("Bagage") {
                    Picker("Bagage", selection: $luggageType) {
                        ForEach(LuggageType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }

                Section {
                    Picker("Soort reis", selection: $style) {
                        Text("Geen").tag(TripStyle?.none)
                        ForEach(TripStyle.allCases) { option in
                            Text(option.label).tag(TripStyle?.some(option))
                        }
                    }
                } header: {
                    Text("Soort reis")
                } footer: {
                    // Eerlijk zijn over wat er níét gebeurt: we laten de
                    // paklijst met rust, want daar staan afvinkjes en eigen
                    // items van de gebruiker in.
                    Text(trip.customStyleLabel != nil
                         ? "Deze reis heeft een eigen type van Pim: \(trip.customStyleLabel!). Kies je hier iets, dan vervangt dat de naam. Je paklijst blijft ongewijzigd."
                         : "Aanpassen verandert alleen de naam van het reistype. Je paklijst blijft zoals hij is.")
                }

                Section {
                    Toggle("Verberg deze reis", isOn: $isHidden)
                } footer: {
                    Text(isHidden
                         ? "Verborgen reizen zijn nergens zichtbaar — ook niet op je widget of in de auto — en alleen te openen achter Face ID."
                         : "Handig voor een verrassing die niemand mag zien.")
                }
            }
            .navigationTitle("Reis aanpassen")
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
        }
    }

    private func save() {
        var updated = trip
        updated.name = name.trimmingCharacters(in: .whitespaces)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespaces)
        updated.destination = trimmedDestination.isEmpty ? nil : trimmedDestination
        updated.startDate = startDate
        updated.endDate = endDate
        updated.luggageType = luggageType
        updated.isHidden = isHidden
        // Kiest de gebruiker een vast type, dan vervalt het eigen type van Pim —
        // anders zouden er twee namen naast elkaar bestaan.
        updated.style = style
        if style != nil { updated.customStyleLabel = nil }
        store.upsert(updated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Eigen reistype door Pim

/// Je omschrijft je reis in eigen woorden, Pim maakt er een type van met een
/// naam en bijpassende spullen. Je ziet eerst wat hij voorstelt en beslist dan
/// pas of je het gebruikt.
@available(iOS 26.0, *)
private struct EigenReisstijlSheet: View {
    /// naam, tagline, items
    let onUse: (String, String, [String]) -> Void

    @StateObject private var model = EigenReisstijlModel()
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @FocusState private var focused: Bool

    private let voorbeelden = [
        "Duiken op de Malediven",
        "Roadtrip met de kinderen",
        "Wandelweek in Noorwegen",
        "Bruiloft in Italië"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Omschrijf je reis in je eigen woorden. Pim maakt er een type van en zet de bijbehorende spullen op je paklijst.")
                        .font(.frutiger(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Bijv. duiken op de Malediven", text: $description, axis: .vertical)
                        .font(.frutiger(size: 16))
                        .lineLimit(1...3)
                        .focused($focused)
                        .padding(Theme.Spacing.base)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .strokeBorder(Theme.ink.opacity(0.08), lineWidth: 1)
                        )

                    if model.stijl == nil && !model.isLoading {
                        // Voorbeelden helpen op weg: een leeg tekstveld met een
                        // AI erachter is voor veel mensen een blokkade.
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(voorbeelden, id: \.self) { voorbeeld in
                                    Button {
                                        description = voorbeeld
                                        focused = false
                                    } label: {
                                        Text(voorbeeld)
                                            .font(.frutiger(size: 12, weight: .semibold))
                                            .foregroundStyle(Theme.navy)
                                            .padding(.horizontal, Theme.Spacing.md)
                                            .padding(.vertical, Theme.Spacing.sm)
                                            .background(Theme.skyLight)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Button {
                        focused = false
                        Task { await model.generate(from: description) }
                    } label: {
                        HStack(spacing: 8) {
                            PurserPimCap(size: 20)
                            Text(model.stijl == nil ? "Vraag het Pim" : "Probeer opnieuw")
                                .font(.frutiger(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.base)
                        .background(canAsk ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Color(.systemGray4)))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAsk)

                    if model.isLoading {
                        HStack(spacing: 10) {
                            ProgressView().tint(Theme.sky)
                            Text("Pim denkt na over je reis…")
                                .font(.frutiger(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.sm)
                    }

                    if let stijl = model.stijl {
                        resultCard(stijl)
                    }

                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.red)
                    }
                }
                .padding(Theme.Spacing.base)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Eigen reistype")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
        }
    }

    private var canAsk: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isLoading
    }

    private func resultCard(_ stijl: EigenReisstijl) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(stijl.naam)
                    .font(.frutiger(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(stijl.tagline)
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("KOMT OP JE PAKLIJST")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .kerning(0.8)
                    .foregroundStyle(Theme.textSecondary)
                ForEach(stijl.items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.green)
                        Text(item)
                            .font(.frutiger(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            Button {
                onUse(stijl.naam, stijl.tagline, stijl.items)
                dismiss()
            } label: {
                Text("Gebruik dit type")
                    .font(.frutiger(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.base)
                    .background(Theme.yellow)
                    .foregroundStyle(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.base)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

// MARK: - Pims paklijst-suggesties

/// Pim noemt spullen die bij déze reis passen en nog niet op de lijst staan.
/// Elke suggestie is los toe te voegen — de gebruiker houdt de regie, Pim
/// vult alleen aan.
@available(iOS 26.0, *)
private struct PimPaklijstSheet: View {
    let trip: Trip
    @StateObject private var model = PaklijstAdviesModel()
    @ObservedObject private var store = TripsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var added: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if model.isLoading {
                        VStack(spacing: 12) {
                            ProgressView().tint(Theme.sky)
                            Text("Pim kijkt naar je reis en je lijst…")
                                .font(.frutiger(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xxl)
                    } else if let suggesties = model.suggesties {
                        Text(suggesties.toelichting)
                            .font(.frutiger(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(suggesties.items, id: \.self) { item in
                            suggestionRow(item)
                        }

                        Text("Voorgesteld op je toestel met Apple Intelligence, op basis van je bestemming, reisduur en wat er al op je lijst staat.")
                            .font(.frutiger(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, Theme.Spacing.xs)
                    } else if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.red)
                            .padding(.top, Theme.Spacing.xxl)
                    }
                }
                .padding(Theme.Spacing.base)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wat vergeet ik?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
            }
            .task { await model.generate(for: trip) }
        }
    }

    private func suggestionRow(_ item: String) -> some View {
        let isAdded = added.contains(item)
        return Button {
            guard !isAdded else { return }
            if store.addItem(tripId: trip.id, name: item, category: "Van Pim") {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            withAnimation(.spring(response: 0.3)) { _ = added.insert(item) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isAdded ? Theme.green : Theme.navy)
                Text(item)
                    .font(.frutiger(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isAdded {
                    Text("Toegevoegd")
                        .font(.frutiger(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }
            }
            .padding(Theme.Spacing.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }
}

// MARK: - Heldkaart voor de eerstvolgende reis

/// Grote fotokaart voor de reis die er nu toe doet. Toont niet alleen wat en
/// wanneer, maar vooral wat er nóg moet gebeuren — dat is de toegevoegde
/// waarde ten opzichte van een lijstrij die alleen een naam en een datum geeft.
private struct TripHeroCard: View {
    let trip: Trip
    let onOpen: () -> Void

    @EnvironmentObject private var session: UserSession

    private static let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM"
        return f
    }()

    private var dateRange: String {
        "\(Self.rangeFormatter.string(from: trip.startDate)) – \(Self.rangeFormatter.string(from: trip.endDate))"
    }

    /// De eerstvolgende concrete taak. Eén regel, geen lijstje: op deze kaart
    /// hoort te staan wat je nú kunt doen.
    private var nextAction: (icon: String, text: String, done: Bool) {
        let progress = trip.progress
        if progress.total > 0, progress.checked < progress.total {
            let remaining = progress.total - progress.checked
            return ("checklist",
                    remaining == 1 ? "Nog 1 item in te pakken" : "Nog \(remaining) items in te pakken",
                    false)
        }
        if session.isPassportValid(forTripStarting: trip.startDate) == false {
            return ("exclamationmark.triangle.fill", "Check je paspoort — mogelijk te kort geldig", false)
        }
        if trip.linkedFlightId == nil {
            return ("airplane", "Koppel je vlucht voor een aftelling", false)
        }
        return ("checkmark.seal.fill", "Je bent er klaar voor", true)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                photoHeader
                footer
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .cardElevation()
        }
        .buttonStyle(.pressableCard)
    }

    private var photoHeader: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Theme.inkGradient
                if let photoUrl = trip.photoUrl {
                    AuthorisedImage(urlString: photoUrl, fill: true)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 172)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.30), .black.opacity(0.78)],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.frutiger(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let destination = trip.destination, !destination.isEmpty {
                        Text(destination)
                            .lineLimit(1)
                        Text("·")
                    }
                    Text(dateRange)
                }
                .font(.frutiger(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(Theme.Spacing.base)

            // Aftelling rechtsboven, als bordje op de foto.
            Text(trip.countdownLabel.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .kerning(0.8)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.yellow, in: Capsule())
                .padding(Theme.Spacing.base)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(height: 172)
        .clipped()
    }

    private var footer: some View {
        let action = nextAction
        let progress = trip.progress
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(action.done ? Theme.green : Theme.ink)
                Text(action.text)
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            if progress.total > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: Double(progress.checked), total: Double(progress.total))
                        .tint(progress.checked == progress.total ? Theme.green : Theme.yellow)
                    HStack {
                        Text("Paklijst")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(progress.checked)/\(progress.total)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(Theme.Spacing.base)
    }
}

// MARK: - Herinnering (afgelopen reis)

/// Afgeronde reis als fotokaartje met jaartal — het tegenovergestelde van een
/// uitgegrijsde lijstrij.
private struct MemoryCard: View {
    let trip: Trip

    private var year: String {
        Calendar.current.component(.year, from: trip.startDate).description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Theme.skyLight
                    if let photoUrl = trip.photoUrl {
                        AuthorisedImage(urlString: photoUrl, fill: true)
                            .allowsHitTesting(false)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.navy.opacity(0.35))
                    }
                }
                .frame(width: 148, height: 104)
                .clipped()

                Text(year)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.yellow, in: Capsule())
                    .padding(Theme.Spacing.sm)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(trip.name)
                    .font(.frutiger(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(trip.destination ?? "\(trip.days) dagen")
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 148, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(width: 148)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .cardElevation()
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(trip.isPast ? Theme.textSecondary.opacity(0.10) : Theme.navy.opacity(0.10))
                if let photoUrl = trip.photoUrl {
                    AuthorisedImage(urlString: photoUrl, fill: true)
                } else {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(trip.isPast ? Theme.textSecondary : Theme.navy)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.frutiger(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                if trip.progress.total > 0 {
                    ProgressView(value: Double(trip.progress.checked), total: Double(trip.progress.total))
                        .tint(Theme.navy)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(trip.countdownLabel)
                    .font(.frutiger(size: 11, weight: .bold))
                    .foregroundStyle(trip.isPast ? Theme.textSecondary : Theme.navy)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(trip.isPast ? Theme.textSecondary.opacity(0.10) : Theme.yellow)
                    .clipShape(Capsule())
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color(.systemBackground))
        .opacity(trip.isPast ? 0.6 : 1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateStyle = .medium
        return f
    }()

    private var subtitle: String {
        var parts: [String] = []
        if let destination = trip.destination, !destination.isEmpty { parts.append(destination) }
        parts.append(Self.dateFormatter.string(from: trip.startDate))
        return parts.joined(separator: " · ")
    }
}

// MARK: - Home-carrousel

/// Compacte kaart voor HomeView's "Mijn reizen"-carrousel — zelfde 160pt-
/// breedte als ShopCarouselCard, zodat beide carrousels visueel matchen.
struct TripCarouselCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.navy.opacity(0.08))
                if let photoUrl = trip.photoUrl {
                    AuthorisedImage(urlString: photoUrl, fill: true)
                } else {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.navy)
                }
            }
            .frame(height: 70)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name)
                    .font(.frutiger(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(trip.countdownLabel)
                    .font(.frutiger(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.navy)
            }
            if trip.progress.total > 0 {
                ProgressView(value: Double(trip.progress.checked), total: Double(trip.progress.total))
                    .tint(Theme.navy)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 160)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .cardElevation()
    }
}

// MARK: - Detail: paklijst

/// Eén reis: countdown, voortgang en de categorieën-checklist. Exporteren
/// naar Herinneringen hergebruikt SaveToRemindersButton één-op-één.
struct TripDetailView: View {
    let tripId: UUID

    @ObservedObject private var store = TripsStore.shared
    @ObservedObject private var flightsStore = FlightsStore.shared
    @ObservedObject private var bagStore = BagCollectionStore.shared
    @EnvironmentObject private var airlineStore: AirlineStore
    @EnvironmentObject private var session: UserSession
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    @State private var newItemName = ""
    @State private var showPimSuggestions = false
    @FocusState private var newItemFocused: Bool

    private var trip: Trip? { store.trips.first { $0.id == tripId } }

    private var linkedFlight: SavedFlightRecord? {
        guard let id = trip?.linkedFlightId else { return nil }
        return flightsStore.flights.first { $0.id == id }
    }
    private var linkedBag: SavedBag? {
        guard let id = trip?.linkedBagId else { return nil }
        return bagStore.bags.first { $0.id == id }
    }
    private var resolvedAirline: Airline? {
        guard let slug = linkedFlight?.airlineSlug else { return nil }
        return airlineStore.airlines.first { $0.slug == slug }
    }
    private var bagFitOK: Bool? {
        guard let bag = linkedBag, let airline = resolvedAirline else { return nil }
        return BagAirlineFit.evaluate(bag: bag, airline: airline).allowedInCabin
    }

    /// Land dat uit de vrije-tekst bestemming valt te herleiden — gebruikt
    /// zowel voor het "zet op bezocht"-bannertje hieronder als (bij het
    /// aanmaken) om de bucket list automatisch bij te werken.
    private func matchedCountry(_ trip: Trip) -> Country? {
        matchCountry(in: trip.destination ?? "")
    }

    private func readiness(_ trip: Trip) -> TripReadiness {
        let progress = trip.progress
        let packingPercent = progress.total > 0 ? Double(progress.checked) / Double(progress.total) : 1
        return TripReadiness(
            packingPercent: packingPercent,
            bagFitOK: bagFitOK,
            passportOK: session.isPassportValid(forTripStarting: trip.startDate)
        )
    }

    /// Categorieën in vaste volgorde (packingCategoryOrder), met onbekende
    /// categorieën netjes achteraan.
    private func groupedItems(_ trip: Trip) -> [(category: String, items: [PackingItem])] {
        let grouped = Dictionary(grouping: trip.packingItems, by: \.category)
        let known = packingCategoryOrder.filter { grouped[$0] != nil }
        let unknown = grouped.keys.filter { !packingCategoryOrder.contains($0) }.sorted()
        return (known + unknown).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        Group {
            if let trip {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        photoHero(trip)
                        header(trip)

                        if trip.isPast {
                            // Na de reis is "ben ik er klaar voor" (readiness-
                            // ring, paklijst) niet meer relevant — alleen de
                            // terugblik telt nog.
                            if let country = matchedCountry(trip),
                               BucketListStore.shared.status(for: country) != .visited {
                                bucketListBanner(country: country)
                            }
                            journalCard(trip)
                        } else {
                            readinessCard(trip)
                            checklistCard(trip)

                            SaveToRemindersButton(
                                titles: trip.packingItems.filter { !$0.isChecked }
                                    .map { "\($0.name) (\($0.quantity)x)" },
                                notes: "Paklijst voor \(trip.name)"
                            )
                        }

                        if linkedFlight != nil || linkedBag != nil {
                            linkedInfoCard
                        }

                        Button {
                            showEdit = true
                        } label: {
                            Label("Reis aanpassen", systemImage: "pencil")
                                .font(.frutiger(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.navy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.navy.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Verwijder deze reis", systemImage: "trash")
                                .font(.frutiger(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Theme.Spacing.base)
                    .padding(.bottom, Theme.Spacing.xl)
                }
                .background(Color(.systemGroupedBackground))
                // Nodig voor het reisverslag: TextEditor heeft geen "klaar"-
                // toets zoals TextField, dus zonder dit blijft het
                // toetsenbord open tot je terugnavigeert.
                .scrollDismissesKeyboard(.interactively)
                .confirmationDialog(
                    "Reis verwijderen?",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Verwijder deze reis", role: .destructive) {
                        store.remove(trip)
                        dismiss()
                    }
                    Button("Annuleer", role: .cancel) {}
                }
                .sheet(isPresented: $showEdit) {
                    TripEditSheet(trip: trip)
                }
            } else {
                ContentUnavailableView("Reis niet meer beschikbaar", systemImage: "suitcase.rolling")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Foto van de bestemming (Unsplash), met verplichte fotograaf-credit
    /// eronder — vereist door Unsplash's API-richtlijnen bij elk gebruik.
    @ViewBuilder
    private func photoHero(_ trip: Trip) -> some View {
        if let photoUrl = trip.photoUrl {
            VStack(alignment: .trailing, spacing: 4) {
                AuthorisedImage(urlString: photoUrl, fill: true)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))

                if let authorName = trip.photoAuthorName,
                   let authorUrl = trip.photoAuthorUrl.flatMap({ URL(string: $0 + "?utm_source=vliegtuigtas&utm_medium=referral") }),
                   let unsplashUrl = URL(string: "https://unsplash.com/?utm_source=vliegtuigtas&utm_medium=referral") {
                    HStack(spacing: 3) {
                        Text("Foto:")
                        Link(authorName, destination: authorUrl)
                        Text("/")
                        Link("Unsplash", destination: unsplashUrl)
                    }
                    .font(.frutiger(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private static let tripRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM"
        return f
    }()

    /// Zelfde opbouw als de vluchtkaart: bestemming klein bovenaan, de
    /// aftelling als blikvanger, statuspil eronder en dan de feiten — met de
    /// resterende paklijst-items in het geel, want dat is hier het getal waar
    /// je iets mee moet.
    private func header(_ trip: Trip) -> some View {
        let progress = trip.progress
        let remaining = progress.total - progress.checked
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                BoardHeadline(
                    context: trip.destination.flatMap { $0.isEmpty ? nil : $0 } ?? trip.name,
                    value: trip.countdownLabel,
                    status: tripStatus(trip)
                )

                VStack(spacing: 4) {
                    FactLine(
                        label: "Reisdata",
                        value: "\(Self.tripRangeFormatter.string(from: trip.startDate)) – \(Self.tripRangeFormatter.string(from: trip.endDate))"
                    )
                    FactLine(label: "Duur", value: trip.days == 1 ? "1 dag" : "\(trip.days) dagen")
                    if let styleLabel = trip.styleLabel {
                        FactLine(label: "Soort", value: styleLabel)
                    }
                    if progress.total > 0 {
                        FactLine(
                            label: "Nog in te pakken",
                            value: "\(remaining)",
                            highlighted: remaining > 0
                        )
                    }
                }

                // Afgeronde reis krijgt een inreisstempel op naam — de beloning
                // voor een reis die erop zit, in dezelfde stijl als je paspoort.
                if trip.isPast {
                    PassportStamp(
                        place: trip.destination ?? trip.name,
                        date: trip.startDate,
                        angle: Double((abs(trip.id.hashValue) % 9) - 4)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xs)
                }
            }
            .padding(Theme.Spacing.base)

            if progress.total > 0 {
                InfoStrip(
                    icon: progress.checked == progress.total ? "checkmark.seal.fill" : "checklist",
                    text: progress.checked == progress.total
                        ? "Alles ingepakt"
                        : "\(progress.checked) van \(progress.total) ingepakt",
                    trailingLabel: "Klaar",
                    trailingValue: "\(Int(Double(progress.checked) / Double(progress.total) * 100))%"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .cardElevation()
    }

    private func tripStatus(_ trip: Trip) -> (text: String, tone: StatusPill.Tone) {
        if trip.isPast { return ("Geweest", .neutral) }
        if trip.isOngoing { return ("Onderweg", .positive) }
        return ("Gepland", .positive)
    }

    /// Eén percentage + concrete actiepunten: paklijst, tas-fit en paspoort
    /// samen, zodat je in één oogopslag weet of je écht klaar bent.
    private func readinessCard(_ trip: Trip) -> some View {
        let readiness = readiness(trip)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Theme.navy.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(readiness.overallPercent) / 100)
                        .stroke(Theme.navy, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(readiness.overallPercent)%")
                        .font(.frutiger(size: 13, weight: .black))
                        .foregroundStyle(Theme.navy)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reisklaar")
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(readiness.actionItems.isEmpty ? "Alles in orde, goede reis!" : "Nog iets te doen:")
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            ForEach(readiness.actionItems, id: \.self) { item in
                Label(item, systemImage: "exclamationmark.circle.fill")
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.orange)
            }
        }
        .padding(Theme.Spacing.base)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func bucketListBanner(country: Country) -> some View {
        Button {
            BucketListStore.shared.setStatus(.visited, for: country)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            HStack(spacing: 12) {
                Text(country.flagEmoji)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Was dit een reis naar \(country.name)?")
                        .font(.frutiger(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tik om op 'bezocht' te zetten in je bucket list")
                        .font(.frutiger(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Theme.green)
            }
            .padding(Theme.Spacing.base)
            .background(Theme.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    /// Vervangt de paklijst zodra een reis voorbij is: die is dan niet meer
    /// relevant, een cijfer en een verslagje wel. Beide worden meteen
    /// opgeslagen via TripsStore.upsert — hetzelfde lokaal+iCloud-pad als de
    /// rest van de reis, geen apart opslagmechanisme nodig.
    private func journalCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hoe was de reis?")
                .font(.frutiger(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var updated = trip
                        updated.rating = (trip.rating == star) ? nil : star
                        store.upsert(updated)
                    } label: {
                        Image(systemName: star <= (trip.rating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.yellow)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Reisverslag")
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                JournalTextEditor(trip: trip)
            }
        }
        .padding(Theme.Spacing.base)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func checklistCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedItems(trip), id: \.category) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.category)
                        .font(.frutiger(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(group.items) { item in
                        Button {
                            store.toggleItem(tripId: trip.id, itemId: item.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(item.isChecked ? Theme.green : Theme.textSecondary)
                                Text(item.name)
                                    .font(.frutiger(size: 14))
                                    .foregroundStyle(item.isChecked ? Theme.textSecondary : Theme.textPrimary)
                                    .strikethrough(item.isChecked)
                                Spacer()
                                if item.quantity > 1 {
                                    Text("×\(item.quantity)")
                                        .font(.frutiger(size: 12, weight: .bold))
                                        .foregroundStyle(Theme.textSecondary)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.xs)
                                        .background(Theme.textSecondary.opacity(0.10))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        // Eigen items moeten er ook weer af kunnen.
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.removeItem(tripId: trip.id, itemId: item.id)
                            } label: {
                                Label("Verwijder", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                store.removeItem(tripId: trip.id, itemId: item.id)
                            } label: {
                                Label("Verwijder van paklijst", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Divider()

            addItemRow(trip)
            pimSuggestionButton(trip)
        }
        .padding(Theme.Spacing.base)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    /// Zelf iets toevoegen: elke paklijst mist wel iets persoonlijks
    /// (medicijnen, laadkabel van een specifieke camera, cadeautjes).
    private func addItemRow(_ trip: Trip) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.navy)
            TextField("Zelf iets toevoegen…", text: $newItemName)
                .font(.frutiger(size: 14))
                .focused($newItemFocused)
                .submitLabel(.done)
                .onSubmit { addOwnItem(trip) }
            if !newItemName.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Voeg toe") { addOwnItem(trip) }
                    .font(.frutiger(size: 13, weight: .bold))
                    .foregroundStyle(Theme.navy)
            }
        }
    }

    private func addOwnItem(_ trip: Trip) {
        let added = store.addItem(tripId: trip.id, name: newItemName)
        UINotificationFeedbackGenerator().notificationOccurred(added ? .success : .warning)
        newItemName = ""
        newItemFocused = false
    }

    /// Pim kijkt naar bestemming, duur, soort reis én wat er al op de lijst
    /// staat, en noemt wat er nog ontbreekt.
    @ViewBuilder
    private func pimSuggestionButton(_ trip: Trip) -> some View {
        if #available(iOS 26.0, *), AIAvailability.isAvailable {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPimSuggestions = true
            } label: {
                HStack(spacing: 8) {
                    PurserPimCap(size: 20)
                    Text("Wat vergeet ik? Vraag het Pim")
                        .font(.frutiger(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.navy)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.base)
                .background(Theme.skyLight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPimSuggestions) {
                PimPaklijstSheet(trip: trip)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var linkedInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let flight = linkedFlight {
                HStack(spacing: 10) {
                    Image(systemName: "airplane.departure")
                        .foregroundStyle(Theme.sky)
                    Text("Vlucht \(flight.number)")
                        .font(.frutiger(size: 13, weight: .semibold))
                    Spacer()
                }
            }
            if let bag = linkedBag {
                HStack(spacing: 10) {
                    Image(systemName: "suitcase.rolling.fill")
                        .foregroundStyle(Theme.navy)
                    Text(bag.name)
                        .font(.frutiger(size: 13, weight: .semibold))
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.base)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

/// Los stukje state voor het reisverslag: bewaart pas bij het wegtikken
/// (focus verliezen) in plaats van bij elke toets — dat zou bij een lang
/// verslagje op elk lettertje een schrijfactie (+ iCloud-push) betekenen.
///
/// Focus verliezen is niet het enige moment dat hier telt: wie de app
/// wegveegt of naar een andere app schakelt terwijl het toetsenbord nog
/// openstaat, verliest anders alsnog het hele verslagje — vandaar ook een
/// vangnet op scenePhase en op het verdwijnen van de view zelf.
private struct JournalTextEditor: View {
    let trip: Trip
    @ObservedObject private var store = TripsStore.shared
    @State private var text: String
    @FocusState private var focused: Bool
    @Environment(\.scenePhase) private var scenePhase

    init(trip: Trip) {
        self.trip = trip
        _text = State(initialValue: trip.journalText ?? "")
    }

    var body: some View {
        TextEditor(text: $text)
            .font(.frutiger(size: 14))
            .foregroundStyle(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 110)
            .padding(Theme.Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .focused($focused)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Wat waren de hoogtepunten? Wat zou je anders doen?")
                        .font(.frutiger(size: 14))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                        .padding(.horizontal, Theme.Spacing.base)
                        .padding(.vertical, Theme.Spacing.base)
                        .allowsHitTesting(false)
                }
            }
            // TextEditor heeft, anders dan TextField, geen submit-toets — de
            // return-toets voegt gewoon een nieuwe regel toe. Zonder deze
            // knop is er geen voor de hand liggende manier om het toetsenbord
            // weg te tikken en zo de opslag te activeren.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Klaar") { focused = false }
                }
            }
            .onChange(of: focused) { _, isFocused in
                guard !isFocused else { return }
                commit()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                commit()
            }
            .onDisappear { commit() }
    }

    private func commit() {
        guard var updated = store.trips.first(where: { $0.id == trip.id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (updated.journalText ?? "") else { return }
        updated.journalText = trimmed.isEmpty ? nil : trimmed
        store.upsert(updated)
    }
}

// MARK: - Wizard: nieuwe reis


private enum TripWizardStep: Int, CaseIterable {
    case destination, dates, style, luggage, ready

    var title: String {
        switch self {
        case .destination: return "Waar gaat de reis heen?"
        case .dates:       return "Wanneer ga je?"
        case .style:       return "Wat voor reis wordt het?"
        case .luggage:     return "Wat neem je mee?"
        case .ready:       return "Klaar voor vertrek"
        }
    }

    var subtitle: String {
        switch self {
        case .destination: return "Geef je reis een naam en bestemming."
        case .dates:       return "Heen en terug — we tellen de dagen voor je."
        case .style:       return "Dit bepaalt wat er op je paklijst komt."
        case .luggage:     return "Handbagage, ruimbagage of allebei."
        case .ready:       return "Je paklijst staat klaar."
        }
    }
}

/// Reis-wizard in vijf stappen, met één vraag per scherm. Bovenaan loopt een
/// vliegtuigje over een gestippelde route van vertrek naar aankomst mee met je
/// voortgang — dezelfde beeldtaal als de terminal-route op Start.
///
/// De stap "wat voor reis" is niet decoratief: die bepaalt welke extra spullen
/// op de gegenereerde paklijst komen (zie TripStyle.extraItems).
struct TripWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var flightsStore = FlightsStore.shared

    @State private var step: TripWizardStep = .destination
    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 8, to: .now) ?? .now
    @State private var linkedFlightId: UUID?
    @State private var luggageType: LuggageType = .carryOnOnly
    @State private var style: TripStyle?
    @State private var showCustomStyle = false
    /// Eigen reistype van Pim. Precies één van `style` en dit type is
    /// gevuld — kiezen van het één wist het ander.
    @State private var customStyleNaam: String?
    @State private var customStyleTagline: String?
    @State private var customStyleItems: [String] = []
    @State private var createHidden = false
    @State private var createdItemCount = 0

    private var days: Int {
        let cal = Calendar.current
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: startDate),
                                   to: cal.startOfDay(for: endDate)).day ?? 0
        return max(1, d + 1)
    }

    private var canAdvance: Bool {
        switch step {
        case .destination: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .style:       return style != nil || customStyleNaam != nil
        default:           return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                flightPath

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        stepContent
                    }
                    .padding(Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
                }

                nextButton
                    .padding(Theme.Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .destination && step != .ready {
                        Button {
                            goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Vorige stap")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
        }
    }

    // MARK: - Vluchtpad als voortgang

    /// Gestippelde route met een vliegtuigje dat opschuift per stap. Vervangt
    /// de anonieme stippenrij: je ziet nu waar je bent én dat je onderweg bent.
    private var flightPath: some View {
        let total = max(TripWizardStep.allCases.count - 1, 1)
        let progress = CGFloat(step.rawValue) / CGFloat(total)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    DashedRule()
                        .frame(height: 2)
                        .frame(maxHeight: .infinity, alignment: .center)

                    Capsule()
                        .fill(Theme.yellow)
                        .frame(width: max(width * progress, 2), height: 3)
                        .frame(maxHeight: .infinity, alignment: .center)

                    Image(systemName: "airplane")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(Theme.Spacing.xs)
                        .background(Theme.yellow, in: Circle())
                        .offset(x: max(min(width * progress - 14, width - 28), 0))
                }
            }
            .frame(height: 32)

            HStack {
                Text("STAP \(step.rawValue + 1) VAN \(TripWizardStep.allCases.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .kerning(1)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: step)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step.title)
                .font(.frutiger(size: 27, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.subtitle)
                .font(.frutiger(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(step)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .destination: destinationStep
        case .dates:       datesStep
        case .style:       styleStep
        case .luggage:     luggageStep
        case .ready:       readyStep
        }
    }

    // MARK: - Stap 1: bestemming

    private var destinationStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            wizardField(label: "Naam van de reis", placeholder: "Bijv. Rome citytrip", text: $name)
            wizardField(label: "Bestemming (optioneel)", placeholder: "Bijv. Rome, Italië", text: $destination)
        }
    }

    private func wizardField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .kerning(0.8)
                .foregroundStyle(Theme.textSecondary)
            TextField(placeholder, text: text)
                .font(.frutiger(size: 17))
                .padding(Theme.Spacing.base)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(Theme.ink.opacity(0.08), lineWidth: 1)
                )
        }
    }

    // MARK: - Stap 2: data

    private var datesStep: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                DatePicker("Vertrek", selection: $startDate, displayedComponents: .date)
                Divider()
                DatePicker("Terug", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .font(.frutiger(size: 15, weight: .semibold))
            .tint(Theme.navy)
            .padding(Theme.Spacing.base)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

            // Directe terugkoppeling op je keuze — je ziet meteen hoe lang je weg bent.
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(days == 1 ? "1 dag weg" : "\(days) dagen weg")
                    .font(.frutiger(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.yellow, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .animation(.snappy, value: days)

            if !flightsStore.flights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("KOPPEL EEN VLUCHT (OPTIONEEL)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(Theme.textSecondary)
                    Picker("Vlucht", selection: $linkedFlightId) {
                        Text("Geen").tag(UUID?.none)
                        ForEach(flightsStore.sorted) { flight in
                            Text(flight.number).tag(Optional(flight.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.navy)
                    .padding(Theme.Spacing.md)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
            }
        }
    }

    // MARK: - Stap 3: soort reis

    private var styleStep: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(TripStyle.allCases) { option in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            style = option
                            customStyleNaam = nil
                            customStyleTagline = nil
                            customStyleItems = []
                        }
                    } label: {
                        styleTile(option)
                    }
                    .buttonStyle(.plain)
                }
            }

            customStyleTile
        }
    }

    /// Staat je reis er niet tussen, dan maakt Pim er zelf een type van uit je
    /// eigen omschrijving — inclusief de spullen die daarbij horen.
    @ViewBuilder
    private var customStyleTile: some View {
        if #available(iOS 26.0, *), AIAvailability.isAvailable {
            let selected = customStyleNaam != nil
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showCustomStyle = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(selected ? Theme.yellow : Theme.ink.opacity(0.06))
                        PurserPimCap(size: 22)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(customStyleNaam ?? "Eigen type met Pim")
                            .font(.frutiger(size: 15, weight: .bold))
                            .foregroundStyle(selected ? .white : Theme.textPrimary)
                        Text(customStyleTagline ?? "Staat jouw reis er niet bij? Omschrijf hem zelf.")
                            .font(.frutiger(size: 11))
                            .foregroundStyle(selected ? .white.opacity(0.75) : Theme.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: selected ? 17 : 12, weight: .semibold))
                        .foregroundStyle(selected ? Theme.yellow : Theme.textSecondary)
                }
                .padding(Theme.Spacing.base)
                .background(selected ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Color(.systemBackground)))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .strokeBorder(selected ? Theme.yellow : Theme.ink.opacity(0.07), lineWidth: selected ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showCustomStyle) {
                EigenReisstijlSheet { naam, tagline, items in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        customStyleNaam = naam
                        customStyleTagline = tagline
                        customStyleItems = items
                        style = nil
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func styleTile(_ option: TripStyle) -> some View {
        let selected = style == option
        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle().fill(selected ? Theme.yellow : Theme.ink.opacity(0.06))
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
            }
            .frame(width: 42, height: 42)

            Text(option.label)
                .font(.frutiger(size: 15, weight: .bold))
                .foregroundStyle(selected ? .white : Theme.textPrimary)
            Text(option.tagline)
                .font(.frutiger(size: 11))
                .foregroundStyle(selected ? .white.opacity(0.75) : Theme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(Theme.Spacing.base)
        .background(selected ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Color(.systemBackground)))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(selected ? Theme.yellow : Theme.ink.opacity(0.07), lineWidth: selected ? 2 : 1)
        )
        .scaleEffect(selected ? 1.02 : 1)
    }

    // MARK: - Stap 4: bagage

    private var luggageStep: some View {
        VStack(spacing: 10) {
            ForEach(LuggageType.allCases) { type in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.3)) { luggageType = type }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(luggageType == type ? Theme.yellow : Theme.ink.opacity(0.06))
                            Image(systemName: type.icon)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(luggageType == type ? Theme.ink : Theme.textSecondary)
                        }
                        .frame(width: 42, height: 42)

                        Text(type.label)
                            .font(.frutiger(size: 15, weight: .semibold))
                            .foregroundStyle(luggageType == type ? .white : Theme.textPrimary)
                        Spacer()
                        if luggageType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.yellow)
                        }
                    }
                    .padding(Theme.Spacing.base)
                    .background(luggageType == type ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Color(.systemBackground)))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .strokeBorder(luggageType == type ? Theme.yellow : Theme.ink.opacity(0.07), lineWidth: luggageType == type ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }

            hiddenToggle
        }
    }

    /// Meteen verbergen bij het aanmaken. Tot nu toe kon je een reis pas ná het
    /// aanmaken verbergen — en tot dat moment stond een verrassingsreis gewoon
    /// op Start, in je lijst en op je widget.
    private var hiddenToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $createHidden.animation(.snappy)) {
                HStack(spacing: 10) {
                    Image(systemName: createHidden ? "eye.slash.fill" : "eye")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(createHidden ? Theme.ink : Theme.textSecondary)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Verberg deze reis")
                            .font(.frutiger(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Voor een verrassing: nergens zichtbaar, alleen achter Face ID")
                            .font(.frutiger(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tint(Theme.navy)
            .padding(Theme.Spacing.base)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(createHidden ? Theme.yellow : Theme.ink.opacity(0.07),
                                  lineWidth: createHidden ? 2 : 1)
            )

            if createHidden && !HiddenTripsLock.isDeviceProtected {
                Text("Let op: je iPhone heeft geen toegangscode of Face ID. De reis wordt wel verborgen, maar is dan door iedereen te openen.")
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Stap 5: instapkaart

    /// Slotscherm als instapkaart: samenvatting van wat je hebt gekozen, plus
    /// hoeveel items er op je paklijst zijn gezet. Een afronding in plaats van
    /// een formulier dat zomaar dichtklapt.
    private var readyStep: some View {
        VStack(spacing: 16) {
            TagPaper {
                VStack(spacing: 14) {
                    HStack {
                        Text("BOARDING PASS")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Image(systemName: "airplane")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.navy)
                    }

                    Text(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Mijn reis" : name)
                        .font(.frutiger(size: 22, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)

                    TagPerforation()

                    HStack(spacing: 8) {
                        TagField(label: "BESTEMMING",
                                 value: destination.trimmingCharacters(in: .whitespaces).isEmpty ? "—" : destination)
                        TagField(label: "DAGEN", value: "\(days)", alignment: .center)
                        TagField(label: "SOORT", value: style?.label ?? customStyleNaam ?? "—", alignment: .trailing)
                    }

                    Barcode(seed: "\(name)-\(destination)-\(days)", height: 28)
                }
                .padding(Theme.Spacing.base)
            }

            if createdItemCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(createdItemCount) items op je paklijst gezet")
                        .font(.frutiger(size: 14, weight: .bold))
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.yellow, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }

    // MARK: - Navigatie

    private var nextButton: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: 8) {
                Text(primaryButtonTitle)
                    .font(.frutiger(size: 16, weight: .semibold))
                if step != .ready {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.base)
            .background(canAdvance ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Color(.systemGray4)))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(!canAdvance)
        .animation(.snappy, value: canAdvance)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .luggage: return "Maak mijn paklijst"
        case .ready:   return "Naar mijn reis"
        default:       return "Volgende"
        }
    }

    private func advance() {
        switch step {
        case .destination:
            move(to: .dates)
        case .dates:
            move(to: .style)
        case .style:
            move(to: .luggage)
        case .luggage:
            createTrip()
            move(to: .ready)
        case .ready:
            dismiss()
        }
    }

    private func goBack() {
        guard let previous = TripWizardStep(rawValue: step.rawValue - 1) else { return }
        move(to: previous)
    }

    private func move(to next: TripWizardStep) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = next }
    }
    private func createTrip() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespaces)
        var trip = Trip(
            name: trimmedName.isEmpty ? "Mijn reis" : trimmedName,
            destination: trimmedDestination.isEmpty ? nil : trimmedDestination,
            startDate: startDate,
            endDate: endDate,
            luggageType: luggageType,
            style: style,
            customStyleLabel: customStyleNaam,
            isHidden: createHidden,
            linkedFlightId: linkedFlightId
        )
        trip.packingItems = generatePackingList(
            days: trip.days,
            luggageType: luggageType,
            style: style,
            customItems: customStyleItems
        )
        // Voor het slotscherm: laat zien wat de wizard heeft opgeleverd.
        createdItemCount = trip.packingItems.count
        TripsStore.shared.upsert(trip)

        // Bucket list koppelen: een herkende bestemming staat er nog niet
        // op als "bezocht" al zet 'm automatisch op "wil ik heen".
        if let country = matchCountry(in: trip.destination ?? ""),
           BucketListStore.shared.status(for: country) == .none {
            BucketListStore.shared.setStatus(.wantToVisit, for: country)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Foto ophalen kost een netwerkroundtrip — de wizard hoeft daar niet
        // op te wachten. De trip in de store wordt bijgewerkt zodra de foto
        // binnen is, en elke view die 'm toont ververst vanzelf (@Published).
        let tripId = trip.id
        let searchTerm = trip.destination ?? trip.name
        Task { @MainActor in
            guard let photo = await UnsplashClient.searchPhoto(query: searchTerm) else { return }
            guard var updated = TripsStore.shared.trips.first(where: { $0.id == tripId }) else { return }
            updated.photoUrl = photo.regularUrl
            updated.photoAuthorName = photo.authorName
            updated.photoAuthorUrl = photo.authorProfileUrl
            TripsStore.shared.upsert(updated)
        }

        // Bewust géén dismiss() hier: na het aanmaken volgt de instapkaart als
        // slotstap, en die sluit de wizard zelf met "Naar mijn reis".
    }
}
