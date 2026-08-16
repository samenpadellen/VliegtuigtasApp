import SwiftUI

private var airlineListStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct AirlineListView: View {
    @EnvironmentObject private var store: AirlineStore
    @State private var search = ""
    @Namespace private var zoomNamespace

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
                            .font(.frutiger(size: 15))
                        if !search.isEmpty {
                            Button { search = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .cardElevation()

                    // Grid — adaptief: 2 kolommen op iPhone, meer op brede schermen
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(filtered) { airline in
                            NavigationLink(destination: AirlineDetailView(airline: airline)
                                .zoomDestination(id: airline.id, in: zoomNamespace)) {
                                AirlineListCard(airline: airline)
                            }
                            .buttonStyle(.pressableCard)
                            .zoomSource(id: airline.id, in: zoomNamespace)
                        }
                    }
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
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
                // .clipped() knipt alleen het tekenen, niet de hit-test:
                // zonder dit vangt de foto op iPad tikken in het grid af.
                .allowsHitTesting(false)

            // Donker verloop van onderaf + links voor leesbaarheid tekst
            LinearGradient(
                colors: [Theme.navy.opacity(0.88), Theme.navy.opacity(0.30)],
                startPoint: .bottom, endPoint: .topTrailing
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.80))
                    Text("MAATSCHAPPIJEN")
                        .font(.frutiger(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .kerning(1.2)
                }
                Text("Vlieg met\nelk merk")
                    .font(.frutiger(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(1)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
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
                .font(.frutiger(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                Image(systemName: "bag")
                    .font(.system(size: 11, weight: .medium))
                Text("Bekijk regels")
                    .font(.frutiger(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.navy)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.base)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .cardElevation()
    }
}
