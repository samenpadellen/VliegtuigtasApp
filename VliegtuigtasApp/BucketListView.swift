import SwiftUI
import PhotosUI

// MARK: - Bucket list

private enum BucketFilter: String, CaseIterable {
    case all, wantToVisit, visited

    var label: String {
        switch self {
        case .all:         return "Alles"
        case .wantToVisit: return "Wil ik heen"
        case .visited:     return "Bezocht"
        }
    }
}

/// Landen per continent, met "wil ik heen" / "bezocht" — puur lokale
/// gamification bovenop de statische wereldlijst uit BucketList.swift.
struct BucketListView: View {
    @ObservedObject private var store = BucketListStore.shared
    @ObservedObject private var photoCache = CountryPhotoCache.shared
    @State private var filter: BucketFilter = .all
    @State private var showPassport = false
    @State private var selectedCountryIso2: String?
    @Namespace private var zoomNamespace

    private var filteredByContinent: [(continent: Continent, countries: [Country])] {
        let filtered = allCountries.filter { country in
            switch filter {
            case .all:         return true
            case .wantToVisit: return store.status(for: country) == .wantToVisit
            case .visited:     return store.status(for: country) == .visited
            }
        }
        return Continent.allCases.compactMap { continent in
            let countries = filtered.filter { $0.continent == continent }
            return countries.isEmpty ? nil : (continent, countries)
        }
    }

    /// Bovenaan een snelle, visuele strook met de landen die op het
    /// verlanglijstje staan — de rest van het scherm is de volledige,
    /// doorzoekbare lijst per continent.
    private var wantToVisitCountries: [Country] {
        Array(allCountries.filter { store.status(for: $0) == .wantToVisit }.prefix(12))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if !wantToVisitCountries.isEmpty {
                    destinationStrip
                }

                filterChips

                ForEach(filteredByContinent, id: \.continent) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.continent.label)
                            .font(.frutiger(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            ForEach(group.countries) { country in
                                CountryRow(
                                    country: country, status: store.status(for: country),
                                    onSelect: { selectedCountryIso2 = country.iso2 },
                                    onChange: { status in store.setStatus(status, for: country) }
                                )
                                .zoomSource(id: country.iso2, in: zoomNamespace)
                                if country.id != group.countries.last?.id {
                                    Divider().padding(.leading, 54)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Bucket list")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPassport = true
                } label: {
                    Image(systemName: "airplane.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showPassport) {
            TravelPassportView()
        }
        .navigationDestination(item: $selectedCountryIso2) { iso2 in
            if let country = allCountries.first(where: { $0.iso2 == iso2 }) {
                CountryDetailView(country: country)
                    .zoomDestination(id: iso2, in: zoomNamespace)
            }
        }
    }

    private var destinationStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Wil je heen?")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(wantToVisitCountries) { country in
                        DestinationChip(
                            photoUrl: photoCache.photo(for: country)?.url,
                            flagEmoji: country.flagEmoji,
                            label: country.name
                        ) {
                            selectedCountryIso2 = country.iso2
                        }
                        .task(id: country.iso2) {
                            await photoCache.fetchIfNeeded(for: country)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(BucketFilter.allCases, id: \.self) { f in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.3)) { filter = f }
                } label: {
                    Text(f.label)
                        .font(.frutiger(size: 13, weight: .semibold))
                        .foregroundStyle(filter == f ? .white : Theme.textPrimary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(
                            filter == f
                                ? AnyShapeStyle(Theme.inkGradient)
                                : AnyShapeStyle(Color(.systemBackground))
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                filter == f ? Color.clear : Theme.textSecondary.opacity(0.25),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CountryRow: View {
    let country: Country
    let status: VisitStatus
    let onSelect: () -> Void
    let onChange: (VisitStatus) -> Void

    @ObservedObject private var photoCache = CountryPhotoCache.shared

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    // Foto voor sfeer + vlag als heldere, altijd-herkenbare
                    // badge eroverheen — de vlag verdween eerder achter de
                    // foto, wat de lijst onduidelijk maakte.
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.navy.opacity(0.08))
                            if let photoUrl = photoCache.photo(for: country)?.url {
                                AuthorisedImage(urlString: photoUrl, fill: true)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(country.flagEmoji)
                            .font(.system(size: 15))
                            .padding(1)
                            .background(.white, in: Circle())
                            .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 1.5))
                            .offset(x: 5, y: 5)
                    }

                    Text(country.name)
                        .font(.frutiger(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .task(id: country.iso2) {
                await photoCache.fetchIfNeeded(for: country)
            }

            Spacer()

            Button {
                onChange(status == .wantToVisit ? .none : .wantToVisit)
            } label: {
                Image(systemName: status == .wantToVisit ? "star.fill" : "star")
                    .font(.system(size: 15))
                    .foregroundStyle(status == .wantToVisit ? Theme.yellow : Theme.textSecondary.opacity(0.4))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Button {
                onChange(status == .visited ? .none : .visited)
            } label: {
                Image(systemName: status == .visited ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(status == .visited ? Theme.green : Theme.textSecondary.opacity(0.4))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Land-detail

/// Eén land: grote hero-foto, status-toggles en fotograaf-credit — zelfde
/// opzet als TripDetailView.photoHero, zodat Trips en BucketList dezelfde
/// premium interactie delen i.p.v. los van elkaar aan te voelen.
struct CountryDetailView: View {
    let country: Country

    @ObservedObject private var store = BucketListStore.shared
    @ObservedObject private var photoCache = CountryPhotoCache.shared

    private var status: VisitStatus { store.status(for: country) }

    private var countryStatus: (text: String, tone: StatusPill.Tone) {
        switch status {
        case .visited:     return ("Bezocht", .positive)
        case .wantToVisit: return ("Op je lijst", .warning)
        case .none:        return ("Nog niet", .neutral)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                photoHero
                statusCard
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: country.iso2) {
            await photoCache.fetchIfNeeded(for: country)
        }
    }

    @ViewBuilder
    private var photoHero: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.navy.opacity(0.08))
                if let photoUrl = photoCache.photo(for: country)?.url {
                    AuthorisedImage(urlString: photoUrl, fill: true)
                } else {
                    Text(country.flagEmoji)
                        .font(.system(size: 60))
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Pexels vraagt credit bij prominente weergave.
            if let photo = photoCache.photo(for: country),
               let authorUrl = URL(string: photo.authorProfileUrl),
               let pexelsUrl = URL(string: "https://www.pexels.com") {
                HStack(spacing: 3) {
                    Text("Foto:")
                    Link(photo.authorName, destination: authorUrl)
                    Text("/")
                    Link("Pexels", destination: pexelsUrl)
                }
                .font(.frutiger(size: 10))
                .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    /// Zelfde opbouw als de vlucht- en reiskaart: werelddeel klein bovenaan,
    /// het land groot, de status als pil, dan de feiten.
    private var statusCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(country.flagEmoji)
                    .font(.system(size: 34))
                BoardHeadline(
                    context: country.continent.label,
                    value: country.name,
                    status: countryStatus
                )
            }

            VStack(spacing: 4) {
                FactLine(label: "Landcode", value: country.iso2)
                FactLine(
                    label: "Op je lijst",
                    value: status == .none ? "Nog niet" : (status == .visited ? "Bezocht" : "Wil ik heen"),
                    highlighted: status == .visited
                )
            }

            HStack(spacing: 10) {
                statusButton(
                    title: "Wil ik heen", icon: "star.fill", color: Theme.yellow,
                    isActive: status == .wantToVisit
                ) {
                    store.setStatus(status == .wantToVisit ? .none : .wantToVisit, for: country)
                }
                statusButton(
                    title: "Bezocht", icon: "checkmark.circle.fill", color: Theme.green,
                    isActive: status == .visited
                ) {
                    store.setStatus(status == .visited ? .none : .visited, for: country)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusButton(
        title: String, icon: String, color: Color, isActive: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.frutiger(size: 13, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(isActive ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reispaspoort (deelbare kaart)

/// Stat-kaart met vlaggenmozaïek i.p.v. een echte wereldkaart: er is geen
/// kaart-topologiedata in de app, en die zelf opbouwen voor 195 landen is een
/// aparte, grote klus. De kaart blijft premium oogend door een full-bleed
/// bestemmingsfoto als hero (i.p.v. foto's te mengen in de kleine mozaïek,
/// wat onduidelijk oogde) — de mozaïek zelf blijft puur vlaggetjes, in één
/// oogopslag herkenbaar op 24pt, wat een willekeurig foto-snippertje niet is.
/// Kaart voor "Jouw reiswereld" in de Meer-hub: een miniatuur van de omslag
/// hieronder — zelfde bordeaux/goud, zelfde vliegtuig-embleem — in plaats
/// van een generiek icoontje. Zo herken je bij het scrollen al wat je
/// reispaspoort is, en trekt het door naar de echte omslag zodra je 'm opent.
struct PassportPreviewCard: View {
    @ObservedObject private var bucketList = BucketListStore.shared
    @ObservedObject private var trips = TripsStore.shared
    let action: () -> Void

    private var passportGold: Color { Color(red: 0.85, green: 0.72, blue: 0.44) }
    private var completedTripsCount: Int { trips.trips.filter(\.isPast).count }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.10, blue: 0.17),
                                    Color(red: 0.29, green: 0.06, blue: 0.11)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(passportGold.opacity(0.35), lineWidth: 1)
                        )
                    Image(systemName: "airplane")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(passportGold)
                        .rotationEffect(.degrees(-45))
                }
                .frame(width: 52, height: 68)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Jouw reispaspoort")
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(bucketList.visitedCount) stempels · \(completedTripsCount) reizen afgerond")
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
        .buttonStyle(.plain)
    }
}

struct TravelPassportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: UserSession
    @ObservedObject private var store = BucketListStore.shared
    @ObservedObject private var photoCache = CountryPhotoCache.shared
    @ObservedObject private var passportPhoto = TravelPassportPhotoStore.shared
    @State private var pickerItem: PhotosPickerItem?
    @State private var renderedImage: UIImage?

    /// Het meest tot de verbeelding sprekende bezochte land — wordt de
    /// full-page hero-foto van het paspoort.
    private var heroCountry: Country? { store.visitedCountries.first }
    private var heroPhoto: CountryPhoto? { heroCountry.flatMap { photoCache.photo(for: $0) } }

    @ObservedObject private var trips = TripsStore.shared

    private static let tripDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "MMM yyyy"
        return f
    }()

    /// Afgeronde reizen, nieuwste eerst — dit is wat je écht hebt gedaan.
    private var completedTrips: [Trip] {
        trips.trips.filter(\.isPast).sorted { $0.startDate > $1.startDate }
    }

    @State private var isOpen = false

    @MainActor
    private func resnapshot() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        renderedImage = passportCard.snapshotImage()
    }

    var body: some View {
        NavigationStack {
            Group {
                if isOpen {
                    pages
                } else {
                    cover
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isOpen ? "Reispaspoort" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
            .task {
                // Zorg dat de hero-foto er al is vóórdat we snapshotten,
                // anders deelt de eerste keer een leeg/half geladen plaatje.
                if let heroCountry {
                    await photoCache.fetchIfNeeded(for: heroCountry)
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                renderedImage = passportCard.snapshotImage()
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        passportPhoto.setPhoto(image)
                        await resnapshot()
                    }
                    pickerItem = nil
                }
            }
        }
    }

    // MARK: - Omslag

    /// De dichte omslag: bordeauxrood met goudopdruk, zoals een echt paspoort
    /// in je hand. Bewust met ónze eigen naam en embleem — het moet aanvoelen
    /// als een paspoort, maar nooit door kunnen gaan voor een echt document.
    private var cover: some View {
        VStack {
            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    isOpen = true
                }
            } label: {
                coverCard
            }
            .buttonStyle(.plain)

            Text("Tik om te openen")
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var coverCard: some View {
        VStack(spacing: 0) {
            Text("VLIEGTUIGTAS")
                .font(.system(size: 9, weight: .bold, design: .serif))
                .kerning(3.5)
                .foregroundStyle(passportGold)
                .padding(.top, 34)

            Text("REISPASPOORT")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .kerning(2.5)
                .foregroundStyle(passportGold)
                .padding(.top, 26)

            Spacer(minLength: 0)

            // Embleem: een gouden zegel met vliegtuig — ons eigen merkteken,
            // geen staatswapen.
            ZStack {
                Circle()
                    .strokeBorder(passportGold.opacity(0.85), lineWidth: 2)
                    .frame(width: 104, height: 104)
                Circle()
                    .strokeBorder(passportGold.opacity(0.45), lineWidth: 1)
                    .frame(width: 88, height: 88)
                Image(systemName: "airplane")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(passportGold)
                    .rotationEffect(.degrees(-45))
            }

            Spacer(minLength: 0)

            Text(session.firstName.isEmpty ? "REIZIGER" : session.firstName.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .kerning(2)
                .foregroundStyle(passportGold.opacity(0.9))

            // Chipsymbool onderaan, zoals op een biometrisch paspoort.
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(passportGold.opacity(0.8), lineWidth: 1.4)
                    .frame(width: 26, height: 19)
                Circle()
                    .strokeBorder(passportGold.opacity(0.8), lineWidth: 1.4)
                    .frame(width: 9, height: 9)
            }
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: 280)
        .frame(height: 400)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.10, blue: 0.17),
                    Color(red: 0.29, green: 0.06, blue: 0.11)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(passportGold.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reispaspoort, tik om te openen")
    }

    private var passportGold: Color {
        Color(red: 0.85, green: 0.72, blue: 0.44)
    }

    // MARK: - Binnenpagina's

    private var pages: some View {
        ScrollView {
                VStack(spacing: 24) {
                    passportCard
                        .padding(.top, 8)

                    if let renderedImage {
                        ShareLink(
                            item: Image(uiImage: renderedImage),
                            preview: SharePreview("Mijn reispaspoort", image: Image(uiImage: renderedImage))
                        ) {
                            Label("Deel je reispaspoort", systemImage: "square.and.arrow.up")
                                .font(.frutiger(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.inkGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        ProgressView().tint(Theme.navy)
                    }

                    stampsSection
                    continentSection
                    tripsSection
                }
                .padding(16)
                .padding(.bottom, 24)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Stempels

    /// Elk bezocht land als stempel, licht scheef zoals ze in een echt
    /// paspoort staan. Vervangt de kale vlaggenrij op het scherm zelf — die
    /// blijft alleen op de deelbare kaart, waar het compact moet.
    @ViewBuilder
    private var stampsSection: some View {
        if !store.visitedCountries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Jouw stempels")
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(store.visitedCountries) { country in
                        stamp(for: country)
                    }
                }
            }
        }
    }

    private func stamp(for country: Country) -> some View {
        // Vaste, kleine hoek per land: stabiel tussen herteken-beurten, maar
        // wel gevarieerd — willekeur bij elke render zou onrustig zijn.
        let angle = Double((abs(country.iso2.hashValue) % 9) - 4)
        return VStack(spacing: 3) {
            Text(country.flagEmoji)
                .font(.system(size: 22))
            Text(country.name.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .kerning(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("BEZOCHT")
                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                .kerning(0.8)
                .foregroundStyle(Theme.green)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.vertical, 9)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Theme.green.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        )
        .rotationEffect(.degrees(angle))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(country.name), bezocht")
    }

    // MARK: - Per continent

    /// Voortgang per werelddeel: dit maakt "een paar landen" ineens een
    /// verzameling waar je aan kunt werken.
    private var continentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Per continent")
            VStack(spacing: 10) {
                ForEach(Continent.allCases, id: \.self) { continent in
                    continentRow(continent)
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func continentRow(_ continent: Continent) -> some View {
        let total = allCountries.filter { $0.continent == continent }.count
        let visited = store.visitedCountries.filter { $0.continent == continent }.count
        let fraction = total > 0 ? Double(visited) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(continent.label)
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(visited)/\(total)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(visited > 0 ? Theme.textPrimary : Theme.textSecondary)
            }
            ProgressView(value: fraction)
                .tint(visited > 0 ? Theme.yellow : Theme.textSecondary.opacity(0.3))
        }
    }

    // MARK: - Reizen

    /// Je afgeronde reizen horen in je paspoort — tot nu toe stonden ze er
    /// helemaal niet in, terwijl het paspoort juist dáárover gaat.
    @ViewBuilder
    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Jouw reizen")

            if completedTrips.isEmpty {
                Text("Nog geen afgeronde reizen. Zodra een reis voorbij is, komt hij hier in je paspoort te staan.")
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(completedTrips) { trip in
                        tripRow(trip)
                        if trip.id != completedTrips.last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.skyLight)
                if let photoUrl = trip.photoUrl {
                    AuthorisedImage(urlString: photoUrl, fill: true)
                } else {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.navy)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name)
                    .font(.frutiger(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(tripSubtitle(trip))
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.green)
        }
        .padding(12)
    }

    private func tripSubtitle(_ trip: Trip) -> String {
        let period = Self.tripDateFormatter.string(from: trip.startDate)
        if let destination = trip.destination, !destination.isEmpty {
            return "\(destination) · \(period)"
        }
        return period
    }

    private var passportCard: some View {
        VStack(spacing: 0) {
            heroHeader
            if !store.visitedCountries.isEmpty {
                flagMosaic
                    .padding(20)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.skyGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    /// Full-page bestemmingsfoto als achtergrond, met de kernstats erop —
    /// een echte cover in plaats van een vlakke kleurverloop-kaart.
    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            if let customImage = passportPhoto.customImage {
                Image(uiImage: customImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .clipped()
                    .allowsHitTesting(false)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.35), .black.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 280)
            } else if let photoUrl = heroPhoto?.url {
                AuthorisedImage(urlString: photoUrl, fill: true)
                    .frame(height: 280)
                    .clipped()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.35), .black.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 280)
            } else {
                Theme.skyGradient.frame(height: 240)
            }

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(session.firstName.isEmpty ? "Reispaspoort" : session.firstName)
                        .font(.frutiger(size: 22, weight: .bold))
                    Text("Vliegtuigtas Reispaspoort")
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)

                Text("\(Int(store.percentWorld.rounded()))%")
                    .font(.frutiger(size: 52, weight: .black))
                    .foregroundStyle(.white)
                Text("van de wereld gezien")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 22) {
                    statColumn(value: "\(store.visitedCount)", label: "Landen")
                    statColumn(value: "\(store.visitedContinents.count)/\(Continent.allCases.count)", label: "Continenten")
                    statColumn(value: "\(store.wantToVisitCount)", label: "Op de lijst")
                }
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 16)

            if passportPhoto.customImage == nil,
               let photo = heroPhoto,
               let authorUrl = URL(string: photo.authorProfileUrl),
               let pexelsUrl = URL(string: "https://www.pexels.com") {
                HStack(spacing: 3) {
                    Text("Foto:")
                    Link(photo.authorName, destination: authorUrl)
                    Text("/")
                    Link("Pexels", destination: pexelsUrl)
                }
                .font(.frutiger(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            photoEditControls
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// Eigen achtergrondfoto kiezen — of, als er al een is, weer terugzetten
    /// naar de automatisch gekozen bestemmingsfoto. Bewust een klein, stil
    /// knopje linksboven: dit is een verrijking, geen hoofdactie.
    private var photoEditControls: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Eigen achtergrondfoto kiezen")

            if passportPhoto.customImage != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    passportPhoto.reset()
                    Task { await resnapshot() }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .accessibilityLabel("Terug naar automatische foto")
            }
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.frutiger(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.frutiger(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    /// Puur vlaggetjes — in één oogopslag herkenbaar op klein formaat, in
    /// tegenstelling tot een niet-gelabeld foto-snippertje van 24×24pt. De
    /// bestemmingsfoto's krijgen hun eigen grote plek in `heroHeader`.
    private var flagMosaic: some View {
        let countries = Array(store.visitedCountries.prefix(30))
        let overflow = store.visitedCountries.count - countries.count
        return VStack(spacing: 6) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 6) {
                ForEach(countries) { country in
                    Text(country.flagEmoji)
                        .font(.system(size: 18))
                        .frame(width: 24, height: 24)
                }
            }
            if overflow > 0 {
                Text("+\(overflow) meer")
                    .font(.frutiger(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(12)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Eigen achtergrondfoto voor het reispaspoort

/// Bewaart een zelfgekozen foto als achtergrond van de paspoortkaart, in
/// plaats van de automatisch gekozen bestemmingsfoto — zodat het kaartje
/// persoonlijk genoeg aanvoelt om ook echt op social media te posten.
/// Bewust op schijf (niet UserDefaults): een volle-resolutie foto is te
/// groot voor UserDefaults' praktische grens.
@MainActor
final class TravelPassportPhotoStore: ObservableObject {
    static let shared = TravelPassportPhotoStore()

    @Published private(set) var customImage: UIImage?

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vt_passport_photo.jpg")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL) {
            customImage = UIImage(data: data)
        }
    }

    func setPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
        try? data.write(to: fileURL, options: .atomic)
        customImage = image
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
        customImage = nil
    }
}

// MARK: - Snapshot-helper

extension View {
    /// Rendert deze view naar een UIImage — nieuwe, zelfstandige helper; er
    /// bestond nog geen beeld-exportmechanisme in de app (ShareLink werd
    /// alleen gebruikt om een URL te delen, niet een gerenderd beeld).
    @MainActor
    func snapshotImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
