import SwiftUI

private var airlineListStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct AirlineListView: View {
    @StateObject private var store = AirlineStore()
    @State private var search = ""

    private var filtered: [Airline] {
        search.isEmpty
            ? store.airlines
            : store.airlines.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                airlineHeader

                VStack(spacing: 16) {
                    // Zoekbalk
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)

                    // Grid
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                        spacing: 12
                    ) {
                        ForEach(filtered) { airline in
                            NavigationLink(destination: AirlineDetailView(airline: airline)) {
                                AirlineListCard(airline: airline)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .task { await store.load() }
        .overlay {
            if store.isLoading { LoadingOverlay() }
        }
    }

    // MARK: - Navy header

    private var airlineHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Image("PhotoBaggageTag")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 140 + airlineListStatusBarHeight)
                .clipped()

            // Donker verloop van onderaf + links voor leesbaarheid tekst
            LinearGradient(
                colors: [Theme.navy.opacity(0.88), Theme.navy.opacity(0.30)],
                startPoint: .bottom, endPoint: .topTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.80))
                    Text("MAATSCHAPPIJEN")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .kerning(1.2)
                }
                Text("Vlieg met\nelk merk")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .clipped()
    }
}

// MARK: - Airline list card

private struct AirlineListCard: View {
    let airline: Airline

    var body: some View {
        VStack(spacing: 10) {
            AirlineLogo(airline: airline, size: 80)
            Text(airline.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                Image(systemName: "bag")
                    .font(.system(size: 11, weight: .medium))
                Text("Bekijk regels")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Theme.navy)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}
