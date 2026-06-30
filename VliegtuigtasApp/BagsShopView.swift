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
    @State private var allBags: [Bag] = []
    @State private var airlines: [Airline] = []
    @State private var isLoading = false

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedAirlineSlug: String? = nil
    @State private var sortOption: SortOption = .default
    @State private var showFilters = false

    private var categories: [String] {
        Array(Set(allBags.compactMap(\.category))).sorted()
    }

    private var activeFilterCount: Int {
        [selectedCategory != nil, selectedAirlineSlug != nil, sortOption != .default]
            .filter { $0 }.count
    }

    private var filtered: [Bag] {
        var result = allBags
        if let cat = selectedCategory  { result = result.filter { $0.category == cat } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.brand ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOption {
        case .default:   break
        case .priceLow:  result.sort { ($0.price ?? 0) < ($1.price ?? 0) }
        case .priceHigh: result.sort { ($0.price ?? 0) > ($1.price ?? 0) }
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
                        .padding(.bottom, 16)

                    promoBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    if !categories.isEmpty {
                        categoryRow.padding(.bottom, 16)
                    }

                    activeFiltersBar
                        .padding(.horizontal, 16)

                    productGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 48)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .sheet(isPresented: $showFilters) {
            FilterSheet(
                airlines: airlines,
                categories: categories,
                selectedCategory: $selectedCategory,
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

    // MARK: - Category chips

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "Alles", selected: selectedCategory == nil) {
                    withAnimation(.spring(response: 0.3)) { selectedCategory = nil }
                }
                ForEach(categories, id: \.self) { cat in
                    CategoryChip(label: cat.capitalized, selected: selectedCategory == cat) {
                        withAnimation(.spring(response: 0.3)) { selectedCategory = cat }
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
                       let airline = airlines.first(where: { $0.slug == slug }) {
                        ActiveFilterChip(label: airline.name) { selectedAirlineSlug = nil }
                    }
                    Button {
                        sortOption = .default; selectedAirlineSlug = nil; selectedCategory = nil
                    } label: {
                        Text("Wis alles")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.red)
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    // MARK: - Promo banner

    private var promoBanner: some View {
        ZStack(alignment: .leading) {
            Theme.navyGradient
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // Decorative circles
            Circle().fill(.white.opacity(0.06)).frame(width: 120).offset(x: 190, y: -30)
            Circle().fill(.white.opacity(0.04)).frame(width: 80).offset(x: 240, y: 50)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ZOMERDEAL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.sky)
                            .kerning(1.5)
                        Text("Altijd past\njouw tas!")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineSpacing(2)
                        Text("Gecontroleerd op maat")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    HStack(spacing: 6) {
                        Text("Shop nu")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .padding(22)

                Spacer()

                Text("🧳")
                    .font(.system(size: 72))
                    .rotationEffect(.degrees(10))
                    .padding(.trailing, 22)
                    .offset(y: 8)
            }
        }
        .frame(height: 165)
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
                    ForEach(filtered) { bag in BagCard(bag: bag) }
                }
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
                    selectedCategory = nil; searchText = ""
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
        async let airlinesTask = APIClient.shared.airlines()
        await bagsTask
        airlines = (try? await airlinesTask) ?? []
    }

    private func loadBags() async {
        isLoading = true
        allBags = (try? await APIClient.shared.bags(
            airline: selectedAirlineSlug,
            type: nil,
            maxPrice: nil
        )) ?? []
        isLoading = false
    }
}

// MARK: - Bag card (grid tile)

private struct BagCard: View {
    let bag: Bag

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product image — witte achtergrond zodat foto's er professioneel uitzien
            ZStack {
                Color.white
                if bag.imageUrl != nil {
                    AuthorisedImage(urlString: bag.imageUrl)
                        .padding(8)
                } else {
                    Image(systemName: "bag")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Theme.navy.opacity(0.18))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 0,
                                              bottomTrailingRadius: 0, topTrailingRadius: 18))

            // Info block
            VStack(alignment: .leading, spacing: 6) {
                if let brand = bag.brand {
                    Text(brand.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy)
                        .kerning(0.8)
                }
                Text(bag.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let dims = dimensionsText {
                    Text(dims)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 6)

                HStack(alignment: .center) {
                    if let price = bag.price {
                        Text("€\(Int(price))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    if let url = bag.affiliateUrl.flatMap(URL.init) {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Theme.navyGradient)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    private var dimensionsText: String? {
        let parts = [bag.length, bag.width, bag.depth].compactMap { $0.map { "\(Int($0))" } }
        guard !parts.isEmpty else { return nil }
        var s = parts.joined(separator: "×") + " cm"
        if let w = bag.weight { s += " · \(Int(w))kg" }
        return s
    }
}

// MARK: - Filter sheet

private struct FilterSheet: View {
    let airlines: [Airline]
    let categories: [String]
    @Binding var selectedCategory: String?
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

                if !categories.isEmpty {
                    Section {
                        Button {
                            selectedCategory = nil
                        } label: {
                            HStack {
                                Text("Alle categorieën")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if selectedCategory == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.navy).fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                HStack {
                                    Text(cat.capitalized)
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    if selectedCategory == cat {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.navy).fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Categorie").font(.system(size: 12, weight: .semibold, design: .rounded))
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

private struct ActiveFilterChip: View {
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
