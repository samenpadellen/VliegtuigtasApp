import SwiftUI

/// De volledige feature past in één scherm: kies een maatschappij, tik 'm
/// aan, en de handbagage-regel gaat als kaart het gesprek in. Geen opgeslagen
/// reisdata nodig — puur de checker-functie, rechtstreeks vanuit Messages.
struct QuickBaggageCheckView: View {
    @StateObject private var store = AirlineStore()
    @State private var searchText = ""

    let onSend: (Airline, AirlineVariant) -> Void

    private var filtered: [Airline] {
        let withVariant = store.airlines.filter { $0.variants?.first != nil }
        guard !searchText.isEmpty else { return withVariant }
        return withVariant.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if store.isLoading && store.airlines.isEmpty {
                ProgressView()
                    .tint(Theme.yellow)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                emptyState
            } else {
                List(filtered) { airline in
                    Button {
                        guard let variant = airline.variants?.first else { return }
                        onSend(airline, variant)
                    } label: {
                        row(for: airline)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .background(Theme.surface)
        .searchable(text: $searchText, prompt: "Zoek maatschappij")
        .task { await store.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
            Text(store.airlines.isEmpty ? "Kan maatschappijen niet laden" : "Geen resultaten")
                .font(.frutiger(size: 14, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func row(for airline: Airline) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: airline.bestLogoUrl ?? "")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "airplane.circle.fill")
                    .resizable()
                    .foregroundStyle(Theme.textSecondary.opacity(0.25))
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(airline.name)
                    .font(.frutiger(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if let variant = airline.variants?.first {
                    Text(variant.smallDimString)
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "paperplane.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.yellow)
        }
        .padding(.vertical, 4)
    }
}

/// De kaart die als afbeelding in het gesprek verschijnt — dezelfde
/// ink/geel-huisstijl als de rest van de app, zodat 'm meteen herkenbaar is.
struct BaggageRuleCard: View {
    let airline: Airline
    let variant: AirlineVariant

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(airline.flagEmoji ?? "✈️")
                    .font(.system(size: 30))
                VStack(alignment: .leading, spacing: 1) {
                    Text(airline.name)
                        .font(.frutiger(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("HANDBAGAGE")
                        .font(.frutiger(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.yellow)
                }
                Spacer()
                Image(systemName: "suitcase.rolling.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Afmetingen")
                        .font(.frutiger(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(variant.smallDimString)
                        .font(.frutiger(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                if let weight = variant.maxWeightKg {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max gewicht")
                            .font(.frutiger(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(Int(weight)) kg")
                            .font(.frutiger(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
            }
        }
        .padding(18)
        .frame(width: 320, height: 150, alignment: .topLeading)
        .background(Theme.inkGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
