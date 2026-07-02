import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case `default`   = "Aanbevolen"
    case priceLow    = "Prijs: laag → hoog"
    case priceHigh   = "Prijs: hoog → laag"
    case sizeSmall   = "Formaat: klein → groot"
    case sizeLarge   = "Formaat: groot → klein"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .default:   return "star"
        case .priceLow:  return "arrow.up"
        case .priceHigh: return "arrow.down"
        case .sizeSmall: return "arrow.up.right"
        case .sizeLarge: return "arrow.down.right"
        }
    }
}

private var shopStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct BagsShopView: View {
    // Gedeelde catalogus (zie AppNavigator/ContentView): zonder maatschappij-filter
    // hergebruiken we gewoon wat Home al heeft ingeladen, in plaats van dezelfde
    // data nog een keer op te vragen bij elke tabwissel.
    @EnvironmentObject private var airlineStore: AirlineStore
    @EnvironmentObject private var bagStore: BagStore

    @State private var filteredBags: [Bag] = []
    @State private var isLoadingFiltered = false

    @State private var searchText = ""
    @State private var selectedFitType: BagFitType? = nil
    @State private var selectedAirlineSlug: String? = nil
    @State private var selectedBrand: String? = nil
    @State private var sortOption: SortOption = .default
    @State private var showFilters = false
    @Namespace private var zoomNamespace

    /// Zonder maatschappij-filter tonen we de gedeelde catalogus; met filter
    /// gebruiken we de eigen server-gefilterde resultaten (de API filtert op
    /// maatschappij zelf, dat kan de gedeelde store niet generiek cachen).
    private var allBags: [Bag] {
        selectedAirlineSlug == nil ? bagStore.bags : filteredBags
    }

    private var isLoading: Bool {
        selectedAirlineSlug == nil
            ? (bagStore.isLoading && bagStore.bags.isEmpty)
            : isLoadingFiltered
    }

    private var availableFitTypes: [BagFitType] {
        BagFitType.allCases.filter { type in allBags.contains { $0.fitType == type } }
    }

    /// Meest voorkomende merken in de catalogus, voor de merken-chips (net als Apple's productgrid).
    private var topBrands: [String] {
        var counts: [String: Int] = [:]
        for bag in allBags { if let brand = bag.brand { counts[brand, default: 0] += 1 } }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(8).map(\.key)
    }

    private var distinctBrandCount: Int {
        Set(allBags.compactMap(\.brand)).count
    }

    /// Uitgelichte tassen voor de swipeable carousel bovenaan.
    private var featuredBags: [Bag] {
        let featured = allBags.filter { $0.featured == true }
            .sorted { ($0.editorRank ?? .max) < ($1.editorRank ?? .max) }
        if !featured.isEmpty { return Array(featured.prefix(5)) }
        return Array(allBags.sorted { ($0.editorRank ?? .max) < ($1.editorRank ?? .max) }.prefix(3))
    }

    private var activeFilterCount: Int {
        [selectedFitType != nil, selectedAirlineSlug != nil, selectedBrand != nil, sortOption != .default]
            .filter { $0 }.count
    }

    private var filtered: [Bag] {
        var result = allBags
        if let fit = selectedFitType  { result = result.filter { $0.fitType == fit } }
        if let brand = selectedBrand  { result = result.filter { $0.brand == brand } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.brand ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOption {
        case .default:   break
        case .priceLow:  result.sort { ($0.priceEur ?? 0) < ($1.priceEur ?? 0) }
        case .priceHigh: result.sort { ($0.priceEur ?? 0) > ($1.priceEur ?? 0) }
        case .sizeSmall: result.sort { volume($0) < volume($1) }
        case .sizeLarge: result.sort { volume($0) > volume($1) }
        }
        return result
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                shopHeader

                VStack(alignment: .leading, spacing: 0) {
                    searchAndFilter
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 20)

                    featuredCarousel
                        .padding(.bottom, 24)

                    if !topBrands.isEmpty {
                        brandRow.padding(.bottom, 16)
                    }

                    if !availableFitTypes.isEmpty {
                        fitTypeRow.padding(.bottom, 16)
                    }

                    activeFiltersBar

                    productGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 48)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .refreshable { await refreshAll() }
        .sheet(isPresented: $showFilters) {
            FilterSheet(
                airlines: airlineStore.airlines,
                fitTypes: availableFitTypes,
                selectedFitType: $selectedFitType,
                selectedAirlineSlug: $selectedAirlineSlug,
                sortOption: $sortOption
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await loadAll() }
        .onChange(of: selectedAirlineSlug) { Task { await loadBags() } }
    }

    // MARK: - Shop header (navy hero style)

    private var shopHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Image("PhotoTraveler")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 160 + shopStatusBarHeight)
                .clipped()

            // Donker onderin + links zodat tekst leesbaar blijft, foto rechts uitkomt
            LinearGradient(
                colors: [Theme.navy.opacity(0.80), Theme.navy.opacity(0.10)],
                startPoint: .bottom, endPoint: .topTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.80))
                    Text("HANDBAGAGE SHOP")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .kerning(1.2)
                }
                Text("Tassen die altijd\npassen")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(1)

                if !allBags.isEmpty {
                    Text("\(allBags.count) tassen · \(distinctBrandCount) merken")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .clipped()
    }

    // MARK: - Search + filter row

    private var searchAndFilter: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.system(size: 15))
                TextField("Zoek op naam of merk…", text: $searchText)
                    .font(.system(size: 15, design: .rounded))
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

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
    }

    // MARK: - Fit type chips (onder de stoel / bagagevak)

    private var fitTypeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "Alles", selected: selectedFitType == nil) {
                    withAnimation(.spring(response: 0.3)) { selectedFitType = nil }
                }
                ForEach(availableFitTypes) { fit in
                    CategoryChip(label: fit.label, selected: selectedFitType == fit) {
                        withAnimation(.spring(response: 0.3)) { selectedFitType = fit }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Active filters bar

    @ViewBuilder
    private var activeFiltersBar: some View {
        if activeFilterCount > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if sortOption != .default {
                        ActiveFilterChip(label: sortOption.rawValue) { sortOption = .default }
                    }
                    if let slug = selectedAirlineSlug,
                       let airline = airlineStore.airlines.first(where: { $0.slug == slug }) {
                        ActiveFilterChip(label: airline.name) { selectedAirlineSlug = nil }
                    }
                    if let brand = selectedBrand {
                        ActiveFilterChip(label: brand) { selectedBrand = nil }
                    }
                    Button {
                        sortOption = .default; selectedAirlineSlug = nil
                        selectedFitType = nil; selectedBrand = nil
                    } label: {
                        Text("Wis alles")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.red)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 14)
        }
    }

    // MARK: - Featured carousel ("Uitgelicht", swipeable als in de App Store shop)

    @ViewBuilder
    private var featuredCarousel: some View {
        if isLoading {
            SkeletonCard()
                .frame(height: 220)
                .padding(.horizontal, 16)
        } else if featuredBags.isEmpty {
            FeaturedBagCard(bag: nil)
                .padding(.horizontal, 16)
        } else {
            FeaturedCarousel(bags: featuredBags)
        }
    }

    // MARK: - Brand row ("Merken", vergelijkbaar met Apple's productcategorieën)

    private var brandRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Merken")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topBrands, id: \.self) { brand in
                        CategoryChip(label: brand, selected: selectedBrand == brand) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedBrand = (selectedBrand == brand) ? nil : brand
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Product grid

    @ViewBuilder
    private var productGrid: some View {
        if isLoading {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in SkeletonCard() }
            }
        } else if filtered.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(filtered.count) tassen")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText(value: Double(filtered.count)))
                        .animation(.snappy(duration: 0.25), value: filtered.count)
                    Spacer()
                    if sortOption != .default {
                        HStack(spacing: 4) {
                            Image(systemName: sortOption.icon).font(.system(size: 11))
                            Text(sortOption.rawValue)
                                .font(.system(size: 12, design: .rounded))
                        }
                        .foregroundStyle(Theme.navy)
                    }
                }
                .padding(.bottom, 14)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(filtered) { bag in
                        NavigationLink(destination: BagDetailView(bagId: bag.id)
                            .zoomDestination(id: bag.id, in: zoomNamespace)) {
                            BagCard(bag: bag)
                        }
                        .buttonStyle(.pressableCard)
                        .zoomSource(id: bag.id, in: zoomNamespace)
                    }
                }
                // Laat kaarten vloeiend herschikken/verschijnen bij filteren,
                // zoeken en sorteren in plaats van hard te verspringen.
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: filtered.map(\.id))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.navy.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "bag")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Theme.navy.opacity(0.4))
            }
            VStack(spacing: 6) {
                Text("Geen tassen gevonden")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Pas je filters aan of zoek op een ander merk.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if activeFilterCount > 0 {
                Button {
                    sortOption = .default; selectedAirlineSlug = nil
                    selectedFitType = nil; selectedBrand = nil; searchText = ""
                } label: {
                    Text("Wis alle filters")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Theme.navyGradient)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func volume(_ bag: Bag) -> Double {
        (bag.length ?? 0) * (bag.width ?? 0) * (bag.depth ?? 0)
    }

    private func loadAll() async {
        async let bagsTask: () = loadBags()
        async let airlinesTask: () = airlineStore.load()
        await bagsTask
        await airlinesTask
    }

    /// Voor pull-to-refresh: in tegenstelling tot `loadAll()` haalt dit altijd
    /// verse data op, ook als de gedeelde catalogus al gevuld was.
    private func refreshAll() async {
        async let airlinesTask: () = airlineStore.load()
        if selectedAirlineSlug == nil {
            async let bagsTask: () = bagStore.reload()
            await bagsTask
        } else {
            async let bagsTask: () = loadBags()
            await bagsTask
        }
        await airlinesTask
    }

    private func loadBags() async {
        guard let slug = selectedAirlineSlug else {
            // Geen filter: gebruik/laad de gedeelde catalogus, geen dubbele fetch.
            await bagStore.loadIfNeeded()
            return
        }
        isLoadingFiltered = true
        filteredBags = (try? await APIClient.shared.bags(
            airline: slug,
            type: nil,
            maxPrice: nil
        )) ?? []
        isLoadingFiltered = false
    }
}

// MARK: - Featured carousel (swipeable, net als Apple's "Shop iPhone")

private struct FeaturedCarousel: View {
    let bags: [Bag]
    @State private var page = 0

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $page) {
                ForEach(Array(bags.enumerated()), id: \.element.id) { index, bag in
                    FeaturedBagCard(bag: bag, badgeLabel: index == 0 ? "ONZE KEUS" : "AANBEVOLEN")
                        .padding(.horizontal, 16)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 232)

            if bags.count > 1 {
                HStack(spacing: 6) {
                    ForEach(bags.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Theme.navy : Theme.navy.opacity(0.18))
                            .frame(width: index == page ? 16 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
            }
        }
    }
}

// MARK: - Featured bag card ("Onze keus")

private struct FeaturedBagCard: View {
    let bag: Bag?
    var badgeLabel: String = "ONZE KEUS"
    @State private var isPressed = false

    var body: some View {
        cardContent
            // Press-animatie via simultaneousGesture zodat de Link tap gewoon werkt
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }

    private var cardContent: some View {
        Group {
            if let url = bag?.affiliateUrl.flatMap(URL.init) {
                Link(destination: url) { featured }
            } else {
                featured
            }
        }
        .buttonStyle(.plain)
    }

    private var featured: some View {
        HStack(spacing: 0) {

            // — Links: navy gradient met tekst —
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Theme.navy, Color(red: 0.04, green: 0.16, blue: 0.36)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                // subtiele decoratieve cirkel
                Circle().fill(.white.opacity(0.06)).frame(width: 120).offset(x: -30, y: 80)

                VStack(alignment: .leading, spacing: 14) {
                    // Badge
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.yellow)
                        Text(badgeLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.yellow)
                            .kerning(1.2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.yellow.opacity(0.18))
                    .clipShape(Capsule())

                    // Naam & merk
                    VStack(alignment: .leading, spacing: 3) {
                        if let brand = bag?.brand {
                            Text(brand.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.50))
                                .kerning(0.7)
                        }
                        Text(bag?.name ?? "Aanbevolen tas")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .lineSpacing(1)
                    }

                    Spacer()

                    // Prijs + shop domain
                    VStack(alignment: .leading, spacing: 4) {
                        if let label = bag?.displayPrice {
                            Text(label)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.yellow)
                        }
                        if let domain = bag?.shopDomain {
                            Text(domain)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                    }

                    // CTA knop
                    HStack(spacing: 5) {
                        Text("Bekijk aanbieding")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)

            // — Rechts: productfoto vult het volledige paneel —
            ZStack {
                Color.white

                if bag?.imageUrl != nil {
                    AuthorisedImage(urlString: bag?.imageUrl, fill: true)
                } else {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Theme.navy.opacity(0.12))
                }
            }
            .frame(width: 140)
            .clipped()
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .shadow(color: Theme.navy.opacity(0.25), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Bag card (grid tile)

private struct BagCard: View {
    let bag: Bag

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // — Productfoto —
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Color.white
                    if bag.imageUrl != nil {
                        AuthorisedImage(urlString: bag.imageUrl, fill: true)
                    } else {
                        Image(systemName: "bag")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Theme.navy.opacity(0.12))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 148)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 18, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 18))

                // Afmetingen badge rechtsboven
                if let dims = dimensionsBadge {
                    Text(dims)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .glassChrome(in: Capsule(), tint: Theme.navy, legacyFill: AnyShapeStyle(Theme.navy.opacity(0.80)))
                        .padding(8)
                }

                // Topkeuze badge linksboven (compact zodat het niet botst met de afmetingen-badge)
                if bag.featured == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 22, height: 22)
                        .background(Theme.yellow)
                        .clipShape(Circle())
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // — Info —
            VStack(alignment: .leading, spacing: 4) {
                if let brand = bag.brand {
                    Text(brand.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy.opacity(0.55))
                        .kerning(0.7)
                }
                Text(bag.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let colors = bag.colors, !colors.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(colors.prefix(5), id: \.self) { name in
                            Circle()
                                .fill(BagColorMap.color(for: name))
                                .frame(width: 10, height: 10)
                                .overlay(Circle().strokeBorder(Color(.systemGray4), lineWidth: 0.6))
                        }
                        if colors.count > 5 {
                            Text("+\(colors.count - 5)")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.top, 2)
                }

                if let label = bag.displayPrice {
                    Text(label)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.navy)
                        .padding(.top, 4)
                }
                if let domain = bag.shopDomain {
                    Text(domain)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    private var dimensionsBadge: String? {
        if let label = bag.dimensionsLabel { return label }
        let parts = [bag.length, bag.width, bag.depth].compactMap { $0.map { "\(Int($0))" } }
        guard parts.count == 3 else { return nil }
        return parts.joined(separator: "×") + " cm"
    }
}

// MARK: - Filter sheet

private struct FilterSheet: View {
    let airlines: [Airline]
    let fitTypes: [BagFitType]
    @Binding var selectedFitType: BagFitType?
    @Binding var selectedAirlineSlug: String?
    @Binding var sortOption: SortOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .frame(width: 20)
                                    .foregroundStyle(Theme.navy)
                                Text(option.rawValue)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.navy)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Sorteer op").font(.system(size: 12, weight: .semibold, design: .rounded))
                }

                if !airlines.isEmpty {
                    Section {
                        Button {
                            selectedAirlineSlug = nil
                        } label: {
                            HStack {
                                Text("Alle maatschappijen")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if selectedAirlineSlug == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.navy).fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(airlines) { airline in
                            Button {
                                selectedAirlineSlug = airline.slug
                            } label: {
                                HStack(spacing: 12) {
                                    AirlineLogo(airline: airline, size: 36)
                                    Text(airline.name)
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    if selectedAirlineSlug == airline.slug {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.navy).fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Maatschappij").font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }

                if !fitTypes.isEmpty {
                    Section {
                        Button {
                            selectedFitType = nil
                        } label: {
                            HStack {
                                Text("Alle types")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if selectedFitType == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.navy).fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(fitTypes) { fit in
                            Button {
                                selectedFitType = fit
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: fit.icon)
                                        .frame(width: 20)
                                        .foregroundStyle(Theme.navy)
                                    Text(fit.label)
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    if selectedFitType == fit {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.navy).fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Waar past de tas?").font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }
            }
            .navigationTitle("Filteren & sorteren")
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
}

// MARK: - Active filter chip

struct ActiveFilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(Theme.navy)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.navy.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Category chip

private struct CategoryChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 18).padding(.vertical, 9)
                .background(selected ? AnyShapeStyle(Theme.navyGradient) : AnyShapeStyle(Color(.systemBackground)))
                .foregroundStyle(selected ? .white : Theme.textPrimary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(selected ? 0.15 : 0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skeleton card

private struct SkeletonCard: View {
    @State private var opacity: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.systemFill))
                .frame(height: 150)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 0,
                                                  bottomTrailingRadius: 0, topTrailingRadius: 18))
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 8).frame(maxWidth: 50)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 8).frame(maxWidth: 80)
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 20).frame(maxWidth: 60)
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { opacity = 0.45 }
        }
    }
}
