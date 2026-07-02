import SwiftUI

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
    @StateObject private var checkStore = CheckStore()

    @State private var step: CheckStep = .airline
    @State private var selectedAirline: Airline?
    @State private var length: Double = 55
    @State private var width:  Double = 40
    @State private var depth:  Double = 20
    @State private var weight: Double = 10

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
                        onDismiss: { dismiss() }
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
                        case .airline:    dismiss()
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
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
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
        Task {
            await checkStore.check(
                airlineSlug: airline.slug,
                length: length, width: width, depth: depth, weight: weight
            )
        }
    }
}

extension CheckStep: Hashable {}

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
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
                    .background(activeFilterCount > 0 ? AnyShapeStyle(Theme.navyGradient) : AnyShapeStyle(Color(.systemBackground)))
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
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.red)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Hero banner

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            Image("PhotoWindowWing")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: checkerStatusBarHeight + 230)
                .clipped()

            LinearGradient(
                colors: [
                    Theme.navy.opacity(0.88),
                    Theme.navy.opacity(0.55),
                    Theme.navy.opacity(0.08)
                ],
                startPoint: .bottom,
                endPoint: .topTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("STAP 1 VAN 3 · HANDBAGAGE CHECKER")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .kerning(1.2)

                Text("Met welke\nmaatschappij\nvlieg je?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
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
                .font(.system(size: 15, design: .rounded))
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
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
                .font(.system(size: 12, weight: .bold, design: .rounded))
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
                .font(.system(size: 12, weight: .bold, design: .rounded))
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
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .glassChrome(in: Circle(), interactive: true, legacyFill: AnyShapeStyle(.white.opacity(0.18)))
                }
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
                        .font(.system(size: 15, design: .rounded))
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
                            .font(.system(size: 15, design: .rounded))
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
            Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("STAP 2 VAN 3")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.sky)
                        .kerning(1.5)
                    if let name = airline?.name {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("Hoe groot is\njouw handbagage?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .padding(.top, 2)
                    Text("Meet jouw tas op en vul de maten in.")
                        .font(.body1).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Visual bag diagram
                BagDiagram(length: length, width: width, depth: depth)
                    .padding(.horizontal, 20)

                // Dimension inputs
                Card {
                    VStack(spacing: 14) {
                        DimSlider(label: "Hoogte", value: $length, range: 20...90, color: Theme.navy)
                        Divider()
                        DimSlider(label: "Breedte", value: $width,  range: 10...60, color: Theme.navy)
                        Divider()
                        DimSlider(label: "Diepte",  value: $depth,  range: 5...50,  color: Theme.navy)
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Weight
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "scalemass.fill").foregroundStyle(Theme.navy)
                            Text("Gewicht").font(.headline2)
                        }
                        HStack(spacing: 0) {
                            Button {
                                if weight > 1 { weight = max(1, weight - 0.5) }
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28)).foregroundStyle(Theme.navy)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", weight))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    // Cijfers rollen vloeiend om bij +/- in plaats
                                    // van hard te verspringen (native numericText).
                                    .contentTransition(.numericText(value: weight))
                                    .animation(.snappy(duration: 0.25), value: weight)
                                Text("kilogram").font(.caption1).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Button {
                                if weight < 40 { weight += 0.5 }
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28)).foregroundStyle(Theme.navy)
                            }
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
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(isChecking
                            ? AnyShapeStyle(Theme.navy.opacity(0.5))
                            : AnyShapeStyle(Theme.navyGradient))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Theme.navy.opacity(0.30), radius: 10, x: 0, y: 4)
                    }
                    .disabled(isChecking)

                    if let err = error {
                        Label(err, systemImage: "exclamationmark.circle")
                            .font(.caption1).foregroundStyle(Theme.red)
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

private struct BagDiagram: View {
    let length: Double   // hoogte (cm)
    let width:  Double   // breedte (cm)
    let depth:  Double   // diepte (cm)

    // Schaling van cm naar tekenpunten, binnen het paneel.
    private var w: CGFloat { 28 + CGFloat((width  - 10) / 50) * 62 }  // 10–60 cm → 28–90 pt
    private var h: CGFloat { 34 + CGFloat((length - 20) / 70) * 62 }  // 20–90 cm → 34–96 pt
    private var d: CGFloat { 6  + CGFloat((depth  -  5) / 45) * 20 }  //  5–50 cm →  6–26 pt

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.skyLight)
                .frame(height: 200)

            suitcase
                // Elke maatverandering veert vloeiend mee — de custom Shapes
                // interpoleren de schuinte via animatableData.
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: length)
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: width)
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: depth)

            overlayLabels
        }
    }

    private var suitcase: some View {
        VStack(spacing: 0) {
            // Telescopische trolleygreep
            ZStack(alignment: .top) {
                HStack(spacing: max(w * 0.36, 12)) {
                    Capsule().fill(Theme.yellow.opacity(0.75)).frame(width: 4, height: 16)
                    Capsule().fill(Theme.yellow.opacity(0.75)).frame(width: 4, height: 16)
                }
                Capsule().fill(Theme.yellow).frame(width: max(w * 0.36, 12) + 18, height: 6)
            }
            .offset(x: d / 2)
            .zIndex(1)

            // Koffer met dieptevlakken (isometrische extrusie naar rechtsboven)
            ZStack(alignment: .topLeading) {
                // Bovenvlak
                BagTopFace(skew: d)
                    .fill(Theme.yellowSoft)
                    .frame(width: w + d, height: d)

                // Zijvlak
                BagSideFace(skew: d)
                    .fill(Theme.yellow)
                    .overlay(BagSideFace(skew: d).fill(.black.opacity(0.18)))
                    .frame(width: d, height: h + d)
                    .offset(x: w)

                // Voorvlak
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Theme.yellow, Theme.yellow.opacity(0.82)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))

                    VStack(spacing: h / 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: w * 0.7, height: 3)
                        }
                    }
                }
                .frame(width: w, height: h)
                .offset(y: d)
            }
            .frame(width: w + d, height: h + d)
            .shadow(color: Theme.navy.opacity(0.16), radius: 10, x: 0, y: 7)

            // Wielen
            HStack(spacing: max(w * 0.4, 14)) {
                Circle().fill(Color(.systemGray)).frame(width: 7, height: 7)
                Circle().fill(Color(.systemGray)).frame(width: 7, height: 7)
            }
            .offset(x: -d / 2, y: -2)
        }
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
                .font(.system(size: 11, weight: .semibold, design: .rounded))
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

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body1).fontWeight(.medium)
                .frame(width: 60, alignment: .leading)

            Slider(value: $value, in: range, step: 1) { editing in
                if editing {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .tint(color)

            Text("\(Int(value))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            Text("cm").font(.caption1).foregroundStyle(Theme.textSecondary)
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

    @State private var bags: [Bag] = []
    @State private var loadingBags = false
    @State private var firstName = ""
    @State private var email = ""
    @State private var leadSent = false

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

                // Tas-aanbevelingen
                if !isFit {
                    bagRecommendations
                }

                // Opnieuw + disclaimer
                VStack(spacing: 16) {
                    Button(action: onReset) {
                        Label("Opnieuw controleren", systemImage: "arrow.clockwise")
                            .font(.body1).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.navy.opacity(0.07))
                            .foregroundStyle(Theme.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Text("Indicatie — controleer altijd de officiële regels.")
                        .font(.caption1).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 36)
            }
            .padding(.top, topInset + 16)
        }
        .task { await loadBags() }
    }

    // MARK: Verdict hero

    private var verdictHero: some View {
        VStack(spacing: 20) {
            Text("STAP 3 VAN 3 · RESULTAAT")
                .font(.system(size: 11, weight: .black, design: .rounded))
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
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    AirlineLogo(airline: airline, size: 20)
                    Text(airline.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
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
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Bag recommendations

    private var bagRecommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tassen die wél passen")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Geselecteerd voor \(airline.name).")
                    .font(.caption1).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)

            if loadingBags {
                ProgressView().tint(Theme.sky).frame(maxWidth: .infinity).padding()
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
            }
        }
    }

    // MARK: Lead card

    private var leadCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Theme.sky)
                    Text("Ontvang de beste tas-tips")
                        .font(.headline2)
                }

                Text("We sturen je een overzicht van tassen die altijd passen bij \(airline.name).")
                    .font(.caption1).foregroundStyle(Theme.textSecondary)

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
                        .font(.body1).fontWeight(.semibold)
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
        bags = (try? await APIClient.shared.bags(airline: airline.slug)) ?? []
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
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                if let brand = bag.brand {
                    Text(brand).font(.caption1).foregroundStyle(Theme.textSecondary)
                }
                if let price = bag.priceEur {
                    Text("€\(String(format: "%.0f", price))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.sky)
                }
            }

            if let url = bag.affiliateUrl.flatMap(URL.init) {
                Link(destination: url) {
                    Text("Bekijk tas")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.card)
            .clipShape(Capsule())
            .foregroundStyle(Theme.textSecondary)
    }
}
