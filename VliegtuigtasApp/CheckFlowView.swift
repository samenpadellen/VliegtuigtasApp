import SwiftUI
import StoreKit
// `@Environment(\.requestReview)` leeft in dit private submodule; op Mac
// Catalyst wordt het niet altijd automatisch meegeëxporteerd door
// `import StoreKit`, wat een build error geeft zonder deze expliciete import.
#if canImport(_StoreKit_SwiftUI)
import _StoreKit_SwiftUI
#endif

// MARK: - Flow state

enum CheckStep { case airline, dimensions, result }

private var checkerStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct CheckFlowView: View {
    var request: CheckerRequest?

    @EnvironmentObject private var airlineStore: AirlineStore
    @EnvironmentObject private var nav: AppNavigator
    @StateObject private var checkStore = CheckStore()

    @State private var step: CheckStep = .airline
    @State private var showGuide = false
    @State private var selectedAirline: Airline?
    @State private var length: Double = 55
    @State private var width:  Double = 40
    @State private var depth:  Double = 20
    @State private var weight: Double = 5.0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Step content – volledig scherm voor stap 2 & 3
            ZStack {
                if step == .airline {
                    AirlineStepView(
                        airlines: airlineStore.airlines,
                        isLoading: airlineStore.isLoading,
                        selected: selectedAirline,
                        // De checker is een tab-root: dismiss() deed hier
                        // niets. "Terug" betekent: naar de Home-tab.
                        onDismiss: { nav.selectedTab = .home },
                        onShowAllAirlines: { nav.openAirlines() },
                        onShowGuide: { showGuide = true }
                    ) { airline in
                        let g = UIImpactFeedbackGenerator(style: .rigid)
                        g.impactOccurred(intensity: 0.85)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                            g.impactOccurred(intensity: 0.5)
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedAirline = airline
                            step = .dimensions
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }

                if step == .dimensions {
                    DimensionsStepView(
                        airline: selectedAirline,
                        length: $length, width: $width,
                        depth: $depth, weight: $weight,
                        isChecking: checkStore.isChecking,
                        error: checkStore.error,
                        topInset: compactNavHeight
                    ) {
                        runCheck()
                    }
                    .ignoresSafeArea(edges: .top)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }

                if step == .result, let result = checkStore.result, let airline = selectedAirline {
                    ResultStepView(
                        result: result,
                        airline: airline,
                        dimensions: (length, width, depth, weight),
                        topInset: compactNavHeight
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            checkStore.result = nil
                            step = .airline
                            selectedAirline = nil
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)

            // Zwevende compacte nav bovenop content (alleen stap 2 & 3)
            if step != .airline {
                compactNav
                    .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showGuide) {
            BaggageGuideView()
        }
        // De checker schaalt volledig mee met Dynamic Type, met een bovengrens
        // zodat de compactere rijen (sliders, pillen) ook bij grote letters
        // leesbaar en heel blijven.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .task { await airlineStore.load() }
        .onChange(of: checkStore.result) { _, new in
            if let result = new {
                // Haptic gebaseerd op uitkomst
                if result.verdict == .ok {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else if result.verdict == .fail {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    step = .result
                }
            }
        }
        .onAppear {
            applyRequest(request)
            // Laatst gebruikte tasmaten terugzetten — via iCloud ook de maten
            // die je op een ander apparaat invoerde.
            if let saved = CloudSync.shared.savedBagDims() {
                length = min(max(saved.length, 20), 90)
                width  = min(max(saved.width, 10), 60)
                depth  = min(max(saved.depth, 5), 50)
                weight = min(max(saved.weight, 1), 40)
            }
        }
        .onChange(of: request) { _, new in
            // Reageert op élk nieuw verzoek vanuit Home — ook een herhaalde tik
            // op dezelfde maatschappij — zonder de hele tab opnieuw op te bouwen.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                applyRequest(new)
            }
        }
    }

    private func applyRequest(_ request: CheckerRequest?) {
        checkStore.result = nil
        if let airline = request?.airline {
            selectedAirline = airline
            step = .dimensions
        } else {
            selectedAirline = nil
            step = .airline
        }
    }

    // MARK: - Compact nav hoogte (voor scroll-inset van stap 2 & 3)

    private var compactNavHeight: CGFloat { checkerStatusBarHeight + 128 }

    // MARK: - Compact nav (zwevend, stap 2 & 3) — toont de 3-staps flow expliciet

    private var compactNav: some View {
        VStack(spacing: 14) {
            Color.clear.frame(height: checkerStatusBarHeight)

            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        switch step {
                        case .airline:    nav.selectedTab = .home
                        case .dimensions: step = .airline; selectedAirline = nil
                        case .result:
                            checkStore.result = nil
                            step = .dimensions
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Terug")
                            .font(.frutiger(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.navy)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            FlowStepper(step: step)
                .padding(.horizontal, 28)

            Divider().opacity(0.4)
        }
        .glassChrome(in: Rectangle())
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Actions

    private func runCheck() {
        guard let airline = selectedAirline else { return }
        // Maten bewaren (lokaal + iCloud) zodra ze echt gebruikt worden.
        CloudSync.shared.pushBagDims(length: length, width: width, depth: depth, weight: weight)
        Task {
            await checkStore.check(
                airlineSlug: airline.slug,
                length: length, width: width, depth: depth, weight: weight
            )
        }
    }
}

extension CheckStep: Hashable {}

// MARK: - Vlucht in de widget (mini-sheet vanaf het checkresultaat)

/// Slaat de vlucht direct op vanaf het resultaatscherm — de maatschappij is
/// al bekend, dus alleen vluchtnummer (optioneel) en vertrekmoment.
private struct FlightWidgetSheet: View {
    let airline: Airline

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = UserSession.shared
    @State private var flightNumber = ""
    @State private var departure = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var saved = false

    var body: some View {
        NavigationStack {
            if session.hasAccount {
                content
            } else {
                ScrollView {
                    AccountRequiredView(
                        icon: "airplane.departure",
                        title: "Vlucht opslaan werkt met een profiel",
                        reason: "Je vlucht hoort bij je profiel: zo telt dezelfde vlucht af op je widget, je Apple Watch en al je andere apparaten."
                    )
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Vlucht opslaan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sluit") { dismiss() }
                    }
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                AirlineLogo(airline: airline, size: 34)
                Text("Vlucht met \(airline.name)")
                    .font(.frutiger(size: 15, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Vluchtnummer (optioneel)")
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                TextField("bijv. KL1234", text: $flightNumber)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .font(.frutiger(size: 15))
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Vertrek")
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                DatePicker("", selection: $departure, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }

            Spacer()

            Button {
                let number = flightNumber.trimmingCharacters(in: .whitespaces).uppercased()
                FlightsStore.shared.upsert(SavedFlightRecord(
                    number: number.isEmpty ? "Mijn vlucht" : number,
                    airlineName: airline.name,
                    airlineSlug: airline.slug,
                    airlineLogoUrl: airline.bestLogoUrl,
                    departure: departure
                ))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.3)) { saved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: saved ? "checkmark" : "plus.square.on.square")
                    Text(saved ? "Vlucht opgeslagen" : "Vlucht opslaan")
                        .font(.frutiger(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(saved ? AnyShapeStyle(Theme.green) : AnyShapeStyle(Theme.inkGradient))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(saved)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vlucht opslaan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sluit") { dismiss() }
            }
        }
    }
}

// MARK: - Flow stepper (maakt de 3-staps checker-flow expliciet zichtbaar,
// in plaats van kleine losse puntjes die op elke pagina anders leken)

private struct FlowStepper: View {
    let step: CheckStep
    var onDark: Bool = false

    private let labels = ["Maatschappij", "Afmetingen", "Resultaat"]

    var body: some View {
        let current = stepIndex(step)
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    circle(i, current: current)
                    if i < 2 {
                        Rectangle()
                            .fill(i < current ? activeColor : mutedColor)
                            .frame(height: 2)
                            .animation(.spring(response: 0.35), value: step)
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    Text(labels[i])
                        // Vast: de stap-indicator staat in drie smalle kolommen
                        // die niet mee mogen groeien met Dynamic Type.
                        .font(.frutiger(size: 10, weight: .semibold))
                        .foregroundStyle(i <= current ? activeColor : mutedText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func circle(_ i: Int, current: Int) -> some View {
        ZStack {
            Circle()
                .fill(i <= current ? activeColor : mutedColor)
                .frame(width: 24, height: 24)
            if i < current {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(onDark ? Theme.navy : .white)
            } else {
                Text("\(i + 1)")
                    // Vast: het cijfer zit in een 24pt-cirkel.
                    .font(.frutiger(size: 12, weight: .bold))
                    .foregroundStyle(i == current ? (onDark ? Theme.navy : .white) : mutedText)
            }
        }
        .frame(width: 24)
        .animation(.spring(response: 0.35), value: current)
    }

    private var activeColor: Color { onDark ? .white : Theme.navy }
    private var mutedColor: Color { onDark ? .white.opacity(0.30) : Theme.navy.opacity(0.14) }
    private var mutedText: Color { onDark ? .white.opacity(0.55) : Theme.textSecondary.opacity(0.65) }

    private func stepIndex(_ s: CheckStep) -> Int {
        switch s { case .airline: return 0; case .dimensions: return 1; case .result: return 2 }
    }
}

// MARK: - Step 1: Airline

private struct AirlineStepView: View {
    let airlines: [Airline]
    let isLoading: Bool
    let selected: Airline?
    let onDismiss: () -> Void
    /// Alleen regels opzoeken, zonder een check te doen.
    let onShowAllAirlines: () -> Void
    let onShowGuide: () -> Void
    let onSelect: (Airline) -> Void

    @State private var search = ""
    @State private var selectedContinent: String?
    @State private var selectedAlliance: String?
    @State private var selectedAirlineType: String?
    @State private var showFilters = false

    private var continents: [String] { Array(Set(airlines.compactMap(\.continent))).sorted() }
    private var alliances: [String] { Array(Set(airlines.compactMap(\.alliance))).sorted() }
    private var airlineTypes: [String] { Array(Set(airlines.compactMap(\.airlineType))).sorted() }

    private var activeFilterCount: Int {
        [selectedContinent, selectedAlliance, selectedAirlineType].compactMap { $0 }.count
    }

    private var filtered: [Airline] {
        var result = airlines
        if !search.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        if let c = selectedContinent    { result = result.filter { $0.continent == c } }
        if let a = selectedAlliance     { result = result.filter { $0.alliance == a } }
        if let t = selectedAirlineType  { result = result.filter { $0.airlineType == t } }
        return result
    }

    private var popular: [Airline] { Array(airlines.prefix(8)) }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroBanner

                    // Stap-indicator staat hier in de gewone document-flow, direct
                    // onder de foto — niet als zwevende overlay, zodat hij nooit
                    // met de koptekst kan overlappen.
                    FlowStepper(step: .airline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3)

                    HStack(spacing: 10) {
                        searchBar
                        filterButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, activeFilterCount > 0 ? 10 : 0)

                    if activeFilterCount > 0 {
                        activeFiltersBar
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                    }

                    if isLoading {
                        ProgressView()
                            .tint(Theme.sky)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if !search.isEmpty || activeFilterCount > 0 {
                        searchResults
                    } else {
                        popularSection
                        allAirlinesSection
                        quickLinksFooter
                    }
                }
            }

            headerOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFilters) {
            AirlineFilterSheet(
                continents: continents,
                alliances: alliances,
                airlineTypes: airlineTypes,
                selectedContinent: $selectedContinent,
                selectedAlliance: $selectedAlliance,
                selectedAirlineType: $selectedAirlineType
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Filter button + active filters

    private var filterButton: some View {
        Button { showFilters = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(activeFilterCount > 0 ? .white : Theme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(activeFilterCount > 0 ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Color(.systemBackground)))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)

                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Theme.yellow)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filteren")
        .accessibilityValue(activeFilterCount > 0 ? "\(activeFilterCount) filters actief" : "Geen filters")
    }

    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let c = selectedContinent {
                    ActiveFilterChip(label: c.capitalized) { selectedContinent = nil }
                }
                if let a = selectedAlliance {
                    ActiveFilterChip(label: a) { selectedAlliance = nil }
                }
                if let t = selectedAirlineType {
                    ActiveFilterChip(label: t.capitalized) { selectedAirlineType = nil }
                }
                Button {
                    selectedContinent = nil; selectedAlliance = nil; selectedAirlineType = nil
                } label: {
                    Text("Wis alles")
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.red)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Hero banner

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            SeasonalHeroImage()
                .frame(maxWidth: .infinity)
                .frame(height: checkerStatusBarHeight + 230)
                .clipped()
                // .clipped() knipt alleen het tekenen, niet de hit-test:
                // zonder dit vangt de foto op iPad tikken in het grid af.
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Theme.navy.opacity(0.88),
                    Theme.navy.opacity(0.55),
                    Theme.navy.opacity(0.08)
                ],
                startPoint: .bottom,
                endPoint: .topTrailing
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                Text("STAP 1 VAN 3 · HANDBAGAGE CHECKER")
                    .font(.frutiger(size: 10, weight: .black, relativeTo: .caption2))
                    .foregroundStyle(.white.opacity(0.70))
                    .kerning(1.2)

                Text("Met welke\nmaatschappij\nvlieg je?")
                    .font(.frutiger(size: 32, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(height: checkerStatusBarHeight + 230)
        .clipped()
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
                .font(.system(size: 15))
            TextField("Zoek maatschappij…", text: $search)
                .autocorrectionDisabled()
                .font(.frutiger(size: 15))
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Zoekopdracht wissen")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }

    // MARK: - Popular horizontal section

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Populaire maatschappijen")
                .font(.frutiger(size: 12, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .kerning(0.4)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(popular) { airline in
                        PopularAirlinePill(airline: airline, isSelected: selected?.id == airline.id) {
                            onSelect(airline)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 24)
    }

    // MARK: - All airlines grid

    private var allAirlinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alle maatschappijen")
                .font(.frutiger(size: 12, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .kerning(0.4)
                .padding(.horizontal, 20)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 12
            ) {
                ForEach(airlines) { airline in
                    AirlineTile(airline: airline, isSelected: selected?.id == airline.id) {
                        onSelect(airline)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Vaste ingangen onderaan stap 1

    /// Twee zichtbare uitwegen voor wie niet komt om te checken maar om op te
    /// zoeken: de volledige maatschappijenlijst en de bagagegids. Die hingen
    /// eerder als kaartjes in de Home-feed en waren daar niet te vinden.
    private var quickLinksFooter: some View {
        VStack(spacing: 10) {
            quickLink(
                icon: "list.bullet.rectangle.portrait.fill",
                title: "Alle maatschappijen & regels",
                subtitle: "Bekijk de regels zonder te checken",
                action: onShowAllAirlines
            )
            quickLink(
                icon: "bag.badge.questionmark",
                title: "Wat mag mee?",
                subtitle: "De complete bagagegids",
                action: onShowGuide
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func quickLink(
        icon: String, title: String, subtitle: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.yellow)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.pressableCard)
    }

    // MARK: - Search results

    private var searchResults: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
            spacing: 12
        ) {
            ForEach(filtered) { airline in
                AirlineTile(airline: airline, isSelected: selected?.id == airline.id) {
                    onSelect(airline)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 40)
    }

    // MARK: - Floating header overlay (alleen de terugknop, zwevend op de foto)

    private var headerOverlay: some View {
        VStack {
            HStack {
                FloatingBackButton(action: onDismiss)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, checkerStatusBarHeight + 14)

            Spacer()
        }
    }
}

// MARK: - Airline filter sheet

private struct AirlineFilterSheet: View {
    let continents: [String]
    let alliances: [String]
    let airlineTypes: [String]
    @Binding var selectedContinent: String?
    @Binding var selectedAlliance: String?
    @Binding var selectedAirlineType: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !continents.isEmpty {
                    filterSection(
                        title: "Continent",
                        options: continents,
                        selected: $selectedContinent,
                        allLabel: "Alle continenten",
                        display: { $0.capitalized }
                    )
                }
                if !airlineTypes.isEmpty {
                    filterSection(
                        title: "Type maatschappij",
                        options: airlineTypes,
                        selected: $selectedAirlineType,
                        allLabel: "Alle types",
                        display: { $0.capitalized }
                    )
                }
                if !alliances.isEmpty {
                    filterSection(
                        title: "Alliantie",
                        options: alliances,
                        selected: $selectedAlliance,
                        allLabel: "Alle allianties",
                        display: { $0 }
                    )
                }
            }
            .navigationTitle("Filteren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.navy)
                }
            }
        }
    }

    @ViewBuilder
    private func filterSection(
        title: String,
        options: [String],
        selected: Binding<String?>,
        allLabel: String,
        display: @escaping (String) -> String
    ) -> some View {
        Section {
            Button { selected.wrappedValue = nil } label: {
                HStack {
                    Text(allLabel)
                        .font(.frutiger(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if selected.wrappedValue == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.navy).fontWeight(.semibold)
                    }
                }
            }
            .buttonStyle(.plain)

            ForEach(options, id: \.self) { option in
                Button { selected.wrappedValue = option } label: {
                    HStack {
                        Text(display(option))
                            .font(.frutiger(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if selected.wrappedValue == option {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.navy).fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(title).font(.frutiger(size: 12, weight: .semibold))
        }
    }
}

// MARK: - Airline tiles

private struct PopularAirlinePill: View {
    let airline: Airline
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AirlineLogo(airline: airline, size: 30)
                Text(airline.name)
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.navy : Theme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.skyLight : Color(.systemBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Theme.sky : Color(.systemGray5), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(.spring(response: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct AirlineTile: View {
    let airline: Airline
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                AirlineLogo(airline: airline, size: 72)
                Text(airline.name)
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.navy : Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
            .background(isSelected ? Theme.skyLight : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Theme.sky : Color(.systemGray6), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.10 : 0.04), radius: 8, x: 0, y: 3)
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(.spring(response: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Dimensions

private struct DimensionsStepView: View {
    let airline: Airline?
    @Binding var length: Double
    @Binding var width:  Double
    @Binding var depth:  Double
    @Binding var weight: Double
    let isChecking: Bool
    let error: String?
    var topInset: CGFloat = 0
    let onCheck: () -> Void

    @State private var showScanner = false
    @State private var isDragging = false

    /// Grootste toegestane handbagagemaat van de gekozen maatschappij,
    /// als AR-limietkooi in de scanner.
    private var scannerLimits: (h: Double, w: Double, d: Double)? {
        let variant = airline?.variants?.first { $0.includesLargeBag == true }
            ?? airline?.variants?.first
        if let l = variant?.largeLCm, let w = variant?.largeWCm, let d = variant?.largeDCm {
            return (l, w, d)
        }
        if let l = variant?.smallLCm, let w = variant?.smallWCm, let d = variant?.smallDCm {
            return (l, w, d)
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("STAP 2 VAN 3")
                        .font(.frutiger(size: 11, weight: .black))
                        .foregroundStyle(Theme.sky)
                        .kerning(1.5)
                    if let name = airline?.name {
                        Text(name)
                            .font(.frutiger(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("Hoe groot is\njouw handbagage?")
                        .font(.frutiger(size: 26, weight: .bold))
                        .padding(.top, 2)
                    Text("Meet jouw tas op en vul de maten in.")
                        .font(.frutiger(size: 16)).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Visual bag diagram
                BagDiagram(length: length, width: width, depth: depth, isDragging: isDragging)
                    .padding(.horizontal, 20)

                #if !targetEnvironment(macCatalyst)
                // AR-meting: alleen op toestellen met LiDAR — zonder die
                // sensor is de meting niet betrouwbaar genoeg.
                if LiDARSupport.isAvailable {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showScanner = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Scan je tas met de camera")
                            .font(.frutiger(size: 15, weight: .semibold))
                        Spacer()
                        Text("LiDAR")
                            .font(.frutiger(size: 10, weight: .black))
                            .foregroundStyle(Theme.navy)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.yellow)
                            .clipShape(Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.skyGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .fullScreenCover(isPresented: $showScanner) {
                    BagScannerView(
                        airlineName: airline?.name,
                        limitsCm: scannerLimits
                    ) { h, b, d in
                        // Clamp binnen de sliderbereiken van de checker.
                        length = min(max(h, 20), 90)
                        width  = min(max(b, 10), 60)
                        depth  = min(max(d, 5), 50)
                    }
                }
                }
                #endif

                // Dimension inputs
                Card {
                    VStack(spacing: 14) {
                        DimSlider(label: "Hoogte", value: $length, range: 20...90, color: Theme.navy, isDragging: $isDragging)
                        Divider()
                        DimSlider(label: "Breedte", value: $width,  range: 10...60, color: Theme.navy, isDragging: $isDragging)
                        Divider()
                        DimSlider(label: "Diepte",  value: $depth,  range: 5...50,  color: Theme.navy, isDragging: $isDragging)
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Weight
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "scalemass.fill").foregroundStyle(Theme.navy)
                            Text("Gewicht").font(.frutiger(size: 20, weight: .semibold))
                        }
                        HStack(spacing: 0) {
                            Button {
                                if weight > 1 { weight = max(1, weight - 0.5) }
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28)).foregroundStyle(Theme.navy)
                            }
                            .accessibilityLabel("Gewicht verlagen")
                            Spacer()
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", weight))
                                    .font(.frutiger(size: 36, weight: .bold))
                                    .monospacedDigit()
                                    // Cijfers rollen vloeiend om bij +/- in plaats
                                    // van hard te verspringen (native numericText).
                                    .contentTransition(.numericText(value: weight))
                                    .animation(.snappy(duration: 0.25), value: weight)
                                Text("kilogram").font(.frutiger(size: 13)).foregroundStyle(Theme.textSecondary)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Gewicht")
                            .accessibilityValue(String(format: "%.1f kilogram", weight))
                            Spacer()
                            Button {
                                if weight < 40 { weight += 0.5 }
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28)).foregroundStyle(Theme.navy)
                            }
                            .accessibilityLabel("Gewicht verhogen")
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Check button
                VStack(spacing: 8) {
                    Button {
                        // Krachtige tik bij "Controleer" — voelt als een bevestiging
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
                        onCheck()
                    } label: {
                        HStack(spacing: 8) {
                            if isChecking {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(isChecking ? "Controleren…" : "Controleer nu")
                                .font(.frutiger(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(isChecking
                            ? AnyShapeStyle(Theme.navy.opacity(0.5))
                            : AnyShapeStyle(Theme.inkGradient))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Theme.navy.opacity(0.30), radius: 10, x: 0, y: 4)
                    }
                    .disabled(isChecking)

                    if let err = error {
                        Label(err, systemImage: "exclamationmark.circle")
                            .font(.frutiger(size: 13)).foregroundStyle(Theme.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .padding(.top, topInset + 8)
        }
    }
}

// MARK: - Bag diagram (pseudo-3D, volledig animatable)

/// Bovenvlak van de koffer: parallellogram waarvan de schuinte (diepte)
/// animatable is, zodat óók diepteveranderingen vloeiend meebewegen.
private struct BagTopFace: Shape {
    var skew: CGFloat
    var animatableData: CGFloat {
        get { skew }
        set { skew = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + skew, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - skew, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Zijvlak van de koffer (rechterkant), eveneens met animatable schuinte.
private struct BagSideFace: Shape {
    var skew: CGFloat
    var animatableData: CGFloat {
        get { skew }
        set { skew = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + skew))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - skew))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Het volledige silhouet van de koffer (voorvlak + extrusie) als één vorm
/// met afgeronde hoeken. De facetten worden hierbinnen geclipt, zodat boven-,
/// zij- en voorvlak altijd naadloos op elkaar aansluiten — ook tijdens animatie.
private struct BagSilhouette: Shape {
    var skew: CGFloat
    var radius: CGFloat = 8
    var animatableData: CGFloat {
        get { skew }
        set { skew = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let frontW = rect.width - skew
        let frontB = rect.height          // onderkant voorvlak
        let sideB  = rect.height - skew   // onderkant zijvlak (rechts)

        // Zeshoek, met de klok mee vanaf de linkerbovenhoek van het voorvlak.
        let corners = [
            CGPoint(x: rect.minX,         y: rect.minY + skew), // voor · linksboven
            CGPoint(x: rect.minX + skew,  y: rect.minY),        // boven · linksachter
            CGPoint(x: rect.maxX,         y: rect.minY),        // boven · rechtsachter
            CGPoint(x: rect.maxX,         y: sideB),            // zij · rechtsonder
            CGPoint(x: frontW,            y: frontB),           // voor · rechtsonder
            CGPoint(x: rect.minX,         y: frontB)            // voor · linksonder
        ]

        var p = Path()
        let r = min(radius, skew / 2 + 2)
        // Start midden op de onderrand (veilig recht stuk) en rond elke hoek
        // af met een tangent-boog, met de klok mee.
        p.move(to: CGPoint(x: (corners[4].x + corners[5].x) / 2, y: frontB))
        for i in corners.indices {
            let corner = corners[(i + 5) % corners.count]
            let next   = corners[(i + 6) % corners.count]
            p.addArc(tangent1End: corner, tangent2End: next, radius: r)
        }
        p.closeSubpath()
        return p
    }
}

private struct BagDiagram: View {
    let length: Double   // hoogte (cm)
    let width:  Double   // breedte (cm)
    let depth:  Double   // diepte (cm)
    var isDragging: Bool = false

    // Schaling van cm naar tekenpunten, binnen het paneel.
    private var w: CGFloat { 28 + CGFloat((width  - 10) / 50) * 62 }  // 10–60 cm → 28–90 pt
    private var h: CGFloat { 34 + CGFloat((length - 20) / 70) * 62 }  // 20–90 cm → 34–96 pt
    private var d: CGFloat { 6  + CGFloat((depth  -  5) / 45) * 20 }  //  5–50 cm →  6–26 pt

    // Hoeveel de greepbuizen in het bovenvlak "verzinken" — verbergt de naad
    // tussen greep en koffer, zodat de greep er echt uit lijkt te komen in
    // plaats van los erboven te zweven.
    private var handleOverlap: CGFloat { d * 0.45 }
    // Hoeveel de wielophanging in de onderrand verzinkt, om dezelfde reden.
    private let wheelOverlap: CGFloat = 6

    // Extra "swoosh"-pop bovenop de maatverandering zelf: een korte
    // overshoot in schaal bij elke stap, zodat het schuiven energieker
    // aanvoelt dan een kalme maatovergang alleen.
    @State private var pop: CGFloat = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.skyLight)
                .frame(height: 200)

            if isDragging {
                speedLines
            }

            suitcase
                // Elke maatverandering veert vloeiend mee — de custom Shapes
                // interpoleren de schuinte via animatableData. Een lagere
                // dampingfraction dan voorheen laat 'm net iets doorschieten
                // vóór hij settelt — dat overshoot is wat "swoosh" leest in
                // plaats van een kalme, vlakke overgang.
                .animation(.spring(response: 0.38, dampingFraction: 0.58), value: length)
                .animation(.spring(response: 0.38, dampingFraction: 0.58), value: width)
                .animation(.spring(response: 0.38, dampingFraction: 0.58), value: depth)
                .scaleEffect(pop)
                .onChange(of: length) { _, _ in bounce() }
                .onChange(of: width)  { _, _ in bounce() }
                .onChange(of: depth)  { _, _ in bounce() }

            overlayLabels
        }
    }

    private func bounce() {
        withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) { pop = 1.035 }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.55).delay(0.08)) { pop = 1.0 }
    }

    /// Korte, diagonale "vaart"-strepen die alleen oplichten terwijl je
    /// écht aan een slider trekt — het letterlijke swoosh-effect, geen
    /// permanent decoratie-element.
    private var speedLines: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Theme.sky.opacity(0.35 - Double(index) * 0.09))
                    .frame(width: 3, height: 26 - CGFloat(index) * 5)
            }
        }
        .rotationEffect(.degrees(-18))
        .offset(x: -(w + d) / 2 - 26, y: -8)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(x: 10)),
            removal: .opacity
        ))
        .animation(.easeOut(duration: 0.18), value: isDragging)
    }

    private var suitcase: some View {
        VStack(spacing: 0) {
            trolleyHandle
                .offset(x: d / 2)
                // Buizen zakken een stukje weg áchter het bovenvlak (dat
                // hierna getekend wordt) i.p.v. er los bovenop te eindigen.
                .padding(.bottom, -handleOverlap)

            // Koffer met dieptevlakken (isometrische extrusie naar rechtsboven).
            // Alle vlakken worden binnen één afgerond silhouet geclipt, zodat
            // ze bij elke maat en tijdens animaties naadloos aansluiten.
            bagBody

            wheels
                // Wielophanging zakt weg ín de onderrand i.p.v. eronder te bungelen.
                .padding(.top, -wheelOverlap)
        }
        .background(alignment: .bottom) {
            // Contactschaduw op de "vloer" — zet de koffer neer i.p.v. zweven.
            Ellipse()
                .fill(Theme.navy.opacity(0.14))
                .frame(width: w + d * 0.6, height: 12)
                .blur(radius: 5)
                .offset(x: -d / 4, y: 8)
        }
    }

    // Tweetraps telescoopgreep met handvat-grip. Het bagagelabel hangt er
    // letterlijk aan (i.p.v. los op een hoek van de koffer te zweven).
    private var trolleyHandle: some View {
        ZStack(alignment: .top) {
            // Buizen: buitenbuis donkerder, binnenbuis lichter (uitgeschoven)
            HStack(spacing: max(w * 0.36, 12)) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(spacing: 0) {
                        Capsule().fill(Theme.yellow).frame(width: 3, height: 9)
                        Capsule().fill(Theme.yellow.opacity(0.65)).frame(width: 4.5, height: 9)
                    }
                }
            }
            // Handvat met donkere grip
            Capsule()
                .fill(Theme.yellow)
                .frame(width: max(w * 0.36, 12) + 20, height: 7)
                .overlay(
                    Capsule()
                        .fill(Theme.navyDark.opacity(0.35))
                        .frame(width: max(w * 0.36, 12) + 4, height: 3)
                )
        }
        .overlay(alignment: .top) {
            // Vlak náást de rechterbuis, niet aan de volle breedte van het
            // handvat — anders drijft het label bij een brede koffer los
            // de kaart uit.
            luggageTag
                .offset(x: max(w * 0.36, 12) / 2 + 8, y: 6)
        }
    }

    private var bagBody: some View {
        ZStack(alignment: .topLeading) {
            // Basis: hele silhouet in het voorvlak-geel
            BagSilhouette(skew: d)
                .fill(LinearGradient(
                    colors: [Theme.yellow, Theme.yellow.opacity(0.82)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            // Bovenvlak (lichter) + montageplaatjes van de greep
            BagTopFace(skew: d)
                .fill(Theme.yellowSoft)
                .frame(width: w + d, height: d)
            HStack(spacing: max(w * 0.36, 12)) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.navyDark.opacity(0.30))
                        .frame(width: 7, height: 3.5)
                }
            }
            .frame(width: w + d)
            .offset(x: d / 2, y: d * 0.35)

            // Lichtrand op de achterste bovenrand: vangt het licht en bindt
            // boven- en zijvlak visueel samen tot één gevouwen vorm i.p.v.
            // los aanééngeplakte facetten.
            Rectangle()
                .fill(Color.white.opacity(0.40))
                .frame(width: w, height: 1)
                .offset(x: d, y: 0)

            // Zijvlak (donkerder). Een recessed draaggreep tekenen we alleen bij
            // een diepe koffer, als een smalle verticale gleuf midden op het
            // zijvlak — daar is het parallellogram op zijn breedst, zodat de
            // gleuf nooit over de voor/zij-rand heen valt.
            BagSideFace(skew: d)
                .fill(.black.opacity(0.16))
                .frame(width: d, height: h + d)
                .offset(x: w)
            if d > 15 {
                Capsule()
                    .fill(Theme.navyDark.opacity(0.28))
                    .frame(width: max(d * 0.20, 3.5), height: h * 0.22)
                    .offset(x: w + d * 0.5 - max(d * 0.20, 3.5) / 2,
                            y: (h + d) / 2 - h * 0.11)
            }

            frontFaceDetails
                .frame(width: w, height: h)
                .offset(y: d)
        }
        .frame(width: w + d, height: h + d)
        .clipShape(BagSilhouette(skew: d))
        .overlay(
            // Dunne contourlijn om het hele silhouet: bindt de vlakken samen
            // tot één ogende vorm, ook precies tijdens het schuiven.
            BagSilhouette(skew: d)
                .stroke(Theme.navyDark.opacity(0.18), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            // Achterwiel: piept net onder de zijkant uit. Zonder dit leek de
            // koffer maar op twee wielen te staan in plaats van de
            // gebruikelijke vier.
            ZStack {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.navyDark.opacity(0.5))
                    .frame(width: 5, height: 4)
                    .offset(y: -3)
                Circle()
                    .fill(Color(red: 0.22, green: 0.24, blue: 0.29))
                    .frame(width: 7, height: 7)
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 3, height: 3)
            }
            .offset(x: w + d * 0.5 - 3.5, y: h - 5)
        }
        .shadow(color: Theme.navy.opacity(0.16), radius: 10, x: 0, y: 7)
    }

    /// Voorvlak: hardshell-ribbels, rits met trekker, merkplaatje en een
    /// diagonale glans — vast aantal elementen zodat alles vloeiend meeschaalt.
    private var frontFaceDetails: some View {
        ZStack {
            // Verticale hardshell-ribbels (vast aantal, flexibele breedte)
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [.white.opacity(0.14), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.07)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
                }
            }
            .padding(.vertical, h * 0.06)

            // Rits rondom het voorvlak, met trekker rechtsboven
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [2.5, 2.5]))
                .foregroundStyle(Theme.navyDark.opacity(0.30))
                .padding(6)
            Circle()
                .strokeBorder(Theme.navyDark.opacity(0.45), lineWidth: 1.6)
                .frame(width: 6, height: 6)
                .offset(x: w / 2 - 9, y: -h / 2 + 12)

            // Merkplaatje
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Theme.navyDark.opacity(0.85))
                .frame(width: min(w * 0.3, 26), height: 8)
                .overlay(
                    Text("VT")
                        // Vast: onderdeel van de getekende koffer, geen leestekst.
                        .font(.frutiger(size: 5.5, weight: .black))
                        .foregroundStyle(Theme.yellow)
                )
                .offset(y: -h * 0.30)

            // Diagonale glans linksboven
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.28), location: 0),
                    .init(color: .clear, location: 0.45)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
    }

    // Spinnerwielen met naaf en een steviger ophanging die echt in de
    // onderrand van de koffer verzinkt, i.p.v. er los onder te bungelen.
    private var wheels: some View {
        HStack(spacing: max(w * 0.4, 14)) {
            ForEach(0..<2, id: \.self) { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.navyDark.opacity(0.55))
                        .frame(width: 8, height: 7)
                        .offset(y: -5)
                    Circle()
                        .fill(Color(red: 0.22, green: 0.24, blue: 0.29))
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .offset(x: -d / 2)
    }

    /// Bagagelabel aan de greep — knipoog naar het merk. Compact en dicht
    /// tegen de buis aan, zodat het duidelijk ergens aan hangt i.p.v. los
    /// te zweven.
    private var luggageTag: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.navyDark.opacity(0.4))
                .frame(width: 1.5, height: 6)
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.white)
                .frame(width: 13, height: 18)
                .overlay(
                    VStack(spacing: 1.5) {
                        Circle()
                            .strokeBorder(Theme.navyDark.opacity(0.4), lineWidth: 1)
                            .frame(width: 3, height: 3)
                        Image(systemName: "airplane")
                            .font(.system(size: 5, weight: .bold))
                            .foregroundStyle(Theme.navy)
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Theme.navyDark.opacity(0.25))
                            .frame(width: 7, height: 1.5)
                    }
                )
                .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
        }
        .rotationEffect(.degrees(8), anchor: .top)
    }

    private var overlayLabels: some View {
        VStack {
            HStack {
                Spacer()
                dimLabel(icon: "arrow.up.right", value: depth)
            }
            Spacer()
            HStack {
                dimLabel(icon: "arrow.up.and.down", value: length)
                Spacer()
                dimLabel(icon: "arrow.left.and.right", value: width)
            }
        }
        .padding(10)
        .frame(height: 200)
    }

    /// Maatlabel waarvan de cijfers per digit omrollen (numericText) bij
    /// het schuiven, in plaats van hard te verspringen.
    private func dimLabel(icon: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text("\(Int(value)) cm")
                // Vast: maatlabel dat op de getekende koffer zweeft.
                .font(.frutiger(size: 11, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
        }
        .foregroundStyle(Theme.sky)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground).opacity(0.72))
        .clipShape(Capsule())
        .animation(.snappy(duration: 0.25), value: value)
    }
}

// MARK: - Dim slider

private struct DimSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    /// Gedeeld met `BagDiagram` zodat de koffer alleen tijdens het schuiven
    /// zijn "swoosh"-lijnen laat zien — niet erna, als bevestiging dat er
    /// écht iets in beweging is en niet een permanent decoratie-element.
    @Binding var isDragging: Bool

    private let impact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.frutiger(size: 16)).fontWeight(.medium)
                .frame(width: 60, alignment: .leading)

            Slider(value: $value, in: range, step: 1) { editing in
                isDragging = editing
                if editing {
                    impact.prepare()
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .tint(color)
            // Elke hele cm een tikje, niet alleen bij het beetpakken —
            // dat maakt het schuiven zelf voelbaar in plaats van alleen
            // de start ervan.
            .onChange(of: value) { _, _ in
                guard isDragging else { return }
                impact.impactOccurred(intensity: 0.55)
            }

            Text("\(Int(value))")
                .font(.frutiger(size: 16, weight: .bold))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            Text("cm").font(.frutiger(size: 13)).foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Step 3: Result

struct ResultStepView: View {
    let result: CheckResponse
    let airline: Airline
    let dimensions: (Double, Double, Double, Double)
    var topInset: CGFloat = 0
    let onReset: () -> Void

    @EnvironmentObject private var nav: AppNavigator
    @ObservedObject private var session = UserSession.shared
    @ObservedObject private var journey = JourneyManager.shared
    // Sluit de resultaat-sheet (BaggageCheckView-variant) vóór het wisselen
    // van tab; in de tab-checker is dit een onschuldige no-op.
    @Environment(\.dismiss) private var dismissContainer
    @Environment(\.requestReview) private var requestReview
    @State private var bags: [Bag] = []
    @State private var loadingBags = false
    @State private var bagsFailed = false
    @State private var firstName = ""
    @State private var email = ""
    @State private var leadSent = false
    @State private var showFlightSheet = false

    private var isFit: Bool { result.status == "fit" }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Verdict hero
                verdictHero

                // Variant details (compact)
                if let variant = result.variant {
                    variantRow(variant)
                }

                // Tas-aanbevelingen + route naar de shop: het moment van
                // "past niet" is precies het moment van koopintentie.
                if !isFit {
                    bagRecommendations
                    shopCTA
                } else {
                    fitNextSteps
                }

                // Lead: alleen voor gebruikers zonder profiel — de al
                // gebouwde leadCard stond hier voorheen ongebruikt in de file.
                if !session.hasAccount {
                    if leadSent {
                        leadThanks
                    } else {
                        leadCard
                    }
                }

                // Opnieuw + disclaimer
                VStack(spacing: 16) {
                    Button(action: onReset) {
                        Label("Opnieuw controleren", systemImage: "arrow.clockwise")
                            .font(.frutiger(size: 16)).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.navy.opacity(0.07))
                            .foregroundStyle(Theme.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Text("Indicatie: controleer altijd de officiële regels.")
                        .font(.frutiger(size: 13)).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 36)
            }
            .padding(.top, topInset + 16)
        }
        .task { await loadBags() }
        .onAppear(perform: maybeAskForReview)
        .sheet(isPresented: $showFlightSheet) {
            FlightWidgetSheet(airline: airline)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $journey.showFirstCheckCelebration) {
            FirstCheckCelebrationView(onPlanTrip: { nav.selectedTab = .trips })
        }
    }

    /// Verwerkt een geslaagde check: telt 'm mee voor de journey, viert de
    /// állereerste keer (aha-moment) en vraagt anders — op een natuurlijk
    /// moment, hoogstens 1×/3 maanden — om een beoordeling.
    private func maybeAskForReview() {
        guard isFit else { return }
        ReviewPrompter.recordSuccess()
        JourneyManager.shared.registerSuccessfulCheck()
        // Bij de eerste geslaagde check alleen vieren; de review-vraag bewaren
        // we voor een latere keer zodat de twee elkaar niet overlappen.
        if journey.showFirstCheckCelebration { return }
        guard ReviewPrompter.shouldPrompt() else { return }
        Task {
            // Even wachten zodat het "je tas past!"-moment eerst rustig landt.
            try? await Task.sleep(for: .seconds(1.5))
            requestReview()
        }
    }

    // MARK: Verdict hero

    private var verdictHero: some View {
        VStack(spacing: 20) {
            Text("STAP 3 VAN 3 · RESULTAAT")
                .font(.frutiger(size: 11, weight: .black))
                .foregroundStyle(Theme.verdictColor(result.verdict))
                .kerning(1.5)

            ZStack {
                Circle()
                    .fill(Theme.verdictColor(result.verdict).opacity(0.10))
                    .frame(width: 110, height: 110)
                Image(systemName: verdictIcon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Theme.verdictColor(result.verdict))
            }

            VStack(spacing: 8) {
                Text(result.verdictTitle)
                    .font(.frutiger(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    AirlineLogo(airline: airline, size: 20)
                    Text(airline.name)
                        .font(.frutiger(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 8) {
                    DimPill(value: "\(Int(dimensions.0))×\(Int(dimensions.1))×\(Int(dimensions.2)) cm", icon: "ruler")
                    DimPill(value: String(format: "%.1f kg", dimensions.3), icon: "scalemass")
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        // VoiceOver leest de hele uitkomst als één duidelijke zin voor, in
        // plaats van losse fragmenten (icoon, titel, logo, pillen).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(verdictAccessibilityLabel)
    }

    /// Eén voorgelezen samenvatting van de uitkomst voor VoiceOver.
    private var verdictAccessibilityLabel: String {
        let dims = "\(Int(dimensions.0)) bij \(Int(dimensions.1)) bij \(Int(dimensions.2)) centimeter"
        let weight = String(format: "%.1f", dimensions.3).replacingOccurrences(of: ".", with: ",")
        return "\(result.verdictTitle). \(result.verdictMessage) Maatschappij \(airline.name). "
            + "Ingevoerde maten: \(dims), \(weight) kilogram."
    }

    private var verdictIcon: String {
        switch result.verdict {
        case .ok:      return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail:    return "xmark.circle.fill"
        }
    }

    // MARK: Variant rij (compact)

    private func variantRow(_ variant: AirlineVariant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let w = variant.maxWeightKg {
                resultRow(icon: "scalemass", label: "Max gewicht", value: "\(Int(w)) kg")
            }
            if let large = variant.includesLargeBag {
                resultRow(
                    icon: large ? "bag.fill" : "bag",
                    label: "Tickettype",
                    value: large ? "Grote handbagage inbegrepen" : "Alleen klein persoonlijk item",
                    color: large ? Theme.green : Theme.orange
                )
            }
            if let reasons = result.reasons, !reasons.isEmpty {
                ForEach(reasons, id: \.self) { r in
                    resultRow(icon: "exclamationmark.circle", label: r, value: "", color: Theme.red)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func resultRow(icon: String, label: String, value: String, color: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.frutiger(size: 14))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Bag recommendations

    private var bagRecommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tassen & koffers die wél passen")
                    .font(.frutiger(size: 16, weight: .bold))
                Text("Geselecteerd voor \(airline.name).")
                    .font(.frutiger(size: 13)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)

            if loadingBags {
                ProgressView().tint(Theme.sky).frame(maxWidth: .infinity).padding()
                    .accessibilityLabel("Passende tassen laden")
            } else if !bags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(bags.prefix(6)) { bag in
                            BagRecommendationCard(bag: bag)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            } else if bagsFailed {
                InlineRetryState(
                    message: "We konden de tas-suggesties niet laden. Controleer je verbinding.",
                    onRetry: { Task { await loadBags() } }
                )
                .padding(.horizontal, 20)
            } else {
                // Geen fout, maar (nog) geen match — eerlijk en zonder lege ruimte.
                Text("Nog geen passende tassen gevonden voor \(airline.name). Bekijk de hele shop hieronder.")
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: Vervolgacties

    /// Fail: één duidelijke route naar de volledige, voorgefilterde shop.
    private var shopCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            APIClient.shared.sendEvent("shop_cta_result_fail", path: "/check/result")
            dismissContainer()
            nav.openShop(airlineSlug: airline.slug)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                Text("Bekijk alles wat past bij \(airline.name)")
                    .font(.frutiger(size: 15, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.inkGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    /// Fit: houd het momentum vast met logische volgende stappen.
    private var fitNextSteps: some View {
        VStack(spacing: 10) {
            nextStepRow(
                icon: "airplane.departure", color: Theme.sky,
                title: "Zet je vlucht in de aftelwidget",
                subtitle: "Aftelling + tasreminder op je beginscherm"
            ) {
                // Geen tabwissel (die was onzichtbaar als je al via Home
                // binnenkwam): sla de vlucht hier direct op via een mini-sheet.
                APIClient.shared.sendEvent("widget_cta_result_fit", path: "/check/result")
                showFlightSheet = true
            }
            nextStepRow(
                icon: "bag.fill", color: Theme.green,
                title: "Toch een nieuwe tas of koffer?",
                subtitle: "Alles cabin-proof voor \(airline.name)"
            ) {
                APIClient.shared.sendEvent("shop_cta_result_fit", path: "/check/result")
                dismissContainer()
                nav.openShop(airlineSlug: airline.slug)
            }
        }
        .padding(.horizontal, 20)
    }

    private func nextStepRow(
        icon: String, color: Color, title: String, subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.frutiger(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var leadThanks: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.green)
            Text("Gelukt! We houden je op de hoogte.")
                .font(.frutiger(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.green.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    // MARK: Lead card

    private var leadCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Theme.sky)
                    Text("Ontvang de beste tas-tips")
                        .font(.frutiger(size: 20, weight: .semibold))
                }

                Text("We sturen je een overzicht van tassen en koffers die altijd passen bij \(airline.name).")
                    .font(.frutiger(size: 13)).foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    TextField("Voornaam", text: $firstName)
                        .textContentType(.givenName)
                        .padding(11)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("E-mail", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(11)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    APIClient.shared.saveLead(firstName: firstName, email: email, airlineSlug: airline.slug)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation { leadSent = true }
                } label: {
                    Text("Stuur mij tips")
                        .font(.frutiger(size: 16)).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canSendLead ? Theme.sky : Theme.sky.opacity(0.35))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSendLead)
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    private var canSendLead: Bool { !firstName.isEmpty && email.contains("@") }

    // MARK: - Data

    private func loadBags() async {
        guard !isFit else { return }
        loadingBags = true
        bagsFailed = false
        do {
            bags = try await APIClient.shared.bags(airline: airline.slug)
        } catch {
            // Onderscheid tussen "niets gevonden" en "kon niet laden": alleen
            // bij een écht mislukte call tonen we de opnieuw-proberen-knop.
            bagsFailed = true
            bags = []
        }
        loadingBags = false
    }
}

// MARK: - Bag card (horizontal scroll)

private struct BagRecommendationCard: View {
    let bag: Bag

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AuthorisedImage(urlString: bag.imageUrl, fill: true)
            .frame(width: 160, height: 130)
            .background(Theme.skyLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(bag.name)
                    .font(.frutiger(size: 13, weight: .semibold))
                    .lineLimit(2)
                if let brand = bag.brand {
                    Text(brand).font(.frutiger(size: 13)).foregroundStyle(Theme.textSecondary)
                }
                if let price = bag.priceEur {
                    Text("€\(String(format: "%.0f", price))")
                        .font(.frutiger(size: 15, weight: .bold))
                        .foregroundStyle(Theme.sky)
                }
            }

            if let url = bag.affiliateUrl.flatMap(URL.init) {
                Link(destination: url) {
                    Text("Bekijk tas")
                        .font(.frutiger(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.sky)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(width: 160)
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Dim pill

private struct DimPill: View {
    let value: String
    let icon: String

    var body: some View {
        Label(value, systemImage: icon)
            .font(.frutiger(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.card)
            .clipShape(Capsule())
            .foregroundStyle(Theme.textSecondary)
    }
}
