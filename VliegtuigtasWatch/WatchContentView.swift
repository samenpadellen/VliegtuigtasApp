import SwiftUI

/// Root van de watch-app: twee verticale pagina's, het watchOS-idioom van
/// de Weer-app. Omhoog vegen wisselt tussen "Mijn tas" en de
/// maatschappijenlijst — overzichtelijker dan één lange gemengde lijst.
struct WatchContentView: View {
    var body: some View {
        TabView {
            NavigationStack { WatchMyBagPage() }
            NavigationStack { WatchAirlinesPage() }
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Pagina 1: Mijn tas

private struct WatchMyBagPage: View {
    @EnvironmentObject private var bag: WatchBagStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "suitcase.rolling.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(WatchTheme.yellow)

                Text("\(Int(bag.length)) × \(Int(bag.width)) × \(Int(bag.depth))")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("cm · \(bag.weight.clean) kg")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    WatchMyBagView()
                } label: {
                    Label("Maten wijzigen", systemImage: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                }

                Label("Veeg omhoog voor maatschappijen", systemImage: "chevron.up")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Mijn tas")
    }
}

// MARK: - Pagina 2: Maatschappijen

private struct WatchAirlinesPage: View {
    @EnvironmentObject private var store: AirlineStore
    @State private var searchText = ""

    var body: some View {
        List {
            if store.isLoading && store.airlines.isEmpty {
                HStack {
                    ProgressView()
                    Text("Laden…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let error = store.error, store.airlines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Laden mislukt")
                        .font(.footnote.weight(.semibold))
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Opnieuw") {
                        Task { await store.load() }
                    }
                }
            } else if searchText.isEmpty {
                Section("Populair") {
                    ForEach(popular) { AirlineRow(airline: $0) }
                }
                Section("Alle maatschappijen") {
                    ForEach(allAlphabetical) { AirlineRow(airline: $0) }
                }
            } else {
                // Zoeken: één platte, gefilterde lijst.
                ForEach(filtered) { AirlineRow(airline: $0) }
            }
        }
        .navigationTitle("Maatschappijen")
        .searchable(text: $searchText, prompt: "Zoek maatschappij")
        .task { await store.load() }
    }

    private var popular: [Airline] {
        store.airlines
            .sorted { ($0.sortOrder ?? .max, $0.name) < ($1.sortOrder ?? .max, $1.name) }
            .prefix(5)
            .map { $0 }
    }

    private var allAlphabetical: [Airline] {
        store.airlines.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filtered: [Airline] {
        allAlphabetical.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct AirlineRow: View {
    let airline: Airline

    var body: some View {
        NavigationLink {
            WatchAirlineDetailView(airline: airline)
        } label: {
            HStack(spacing: 8) {
                WatchAirlineLogo(airline: airline, height: 18)
                Text(airline.name)
                    .font(.body)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Logo's op de watch

/// Compacte logoweergave met eigen mini-cache: de watch deelt de zware
/// beeldlader van de iPhone-app niet, en heeft aan dit lichtgewicht laadpad
/// (geheugencache + URLSession) ruim genoeg.
struct WatchAirlineLogo: View {
    let airline: Airline
    var height: CGFloat = 18

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // Nette fallback zolang het logo laadt (of ontbreekt).
                Text(airline.name.prefix(2).uppercased())
                    .font(.system(size: height * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.sky)
            }
        }
        .frame(width: height * 1.5, height: height)
        .task(id: airline.bestLogoUrl) {
            image = await WatchLogoLoader.load(airline.bestLogoUrl)
        }
    }
}

enum WatchLogoLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func load(_ urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        if let cached = cache.object(forKey: urlString as NSString) {
            return cached
        }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: urlString as NSString)
        return image
    }
}

#Preview {
    WatchContentView()
        .environmentObject(AirlineStore())
        .environmentObject(WatchBagStore.shared)
}
