import SwiftUI

struct AirlineListView: View {
    @StateObject private var store = AirlineStore()
    @State private var search = ""
    @State private var selected: Airline?

    private var filtered: [Airline] {
        guard !search.isEmpty else { return store.airlines }
        return store.airlines.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(filtered) { airline in
                    NavigationLink(destination: AirlineDetailView(airline: airline)) {
                        AirlineListCard(airline: airline)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Maatschappijen")
        .searchable(text: $search, prompt: "Zoek maatschappij")
        .task { await store.load() }
        .overlay {
            if store.isLoading { LoadingOverlay() }
        }
    }
}

private struct AirlineListCard: View {
    let airline: Airline

    var body: some View {
        VStack(spacing: 10) {
            AirlineLogo(airline: airline, size: 80)
            Text(airline.name)
                .font(.body1).fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                Image(systemName: "bag")
                    .font(.caption1)
                Text("Bekijk regels")
                    .font(.caption1)
            }
            .foregroundStyle(Theme.sky)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }
}
