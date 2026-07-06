import SwiftUI
import StoreKit

/// Compacte, zelfstandige bagagecheck voor de App Clip. Bewust géén
/// afhankelijkheid van SharedViews of de tabnavigatie van de volledige app:
/// de clip moet klein blijven (limiet 10 MB) en in één flow tot resultaat komen.
struct ClipCheckView: View {
    @EnvironmentObject private var airlineStore: AirlineStore
    @StateObject private var checkStore = CheckStore()
    @Binding var invokedAirlineSlug: String?

    @State private var selectedAirline: Airline?
    @State private var length: Double = 55
    @State private var width:  Double = 40
    @State private var depth:  Double = 20
    @State private var weight: Double = 10
    @State private var showAppStoreOverlay = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    airlinePicker

                    dimensionsCard

                    checkButton

                    if let result = checkStore.result {
                        resultCard(result)
                    }
                    if let error = checkStore.error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.red)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Vliegtuigtas")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await airlineStore.load()
            applyInvokedAirline()
        }
        .onChange(of: invokedAirlineSlug) { _, _ in applyInvokedAirline() }
        // Na een resultaat: nodig uit om de volledige app te installeren.
        .appStoreOverlay(isPresented: $showAppStoreOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
    }

    private func applyInvokedAirline() {
        guard let slug = invokedAirlineSlug else { return }
        selectedAirline = airlineStore.airlines.first { $0.slug == slug }
    }

    // MARK: - Onderdelen

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "suitcase.rolling.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.yellow)
                Text("SNELLE BAGAGECHECK")
                    .font(.frutiger(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .kerning(1.6)
            }
            Text("Past jouw tas\nin het vliegtuig?")
                .font(.frutiger(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.navyGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    /// De populairste maatschappijen als direct tikbare chips, met daaronder
    /// de volledige lijst in een menu. Laadt de lijst niet? Dan staat er een
    /// duidelijke melding mét een knop om het opnieuw te proberen — voorheen
    /// bleef de picker dan stilletjes leeg en leek de clip kapot.
    @ViewBuilder
    private var airlinePicker: some View {
        if airlineStore.isLoading && airlineStore.airlines.isEmpty {
            HStack(spacing: 10) {
                ProgressView().tint(Theme.sky)
                Text("Maatschappijen laden…")
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else if airlineStore.airlines.isEmpty {
            VStack(spacing: 10) {
                Label("Maatschappijen konden niet laden. Check je verbinding.", systemImage: "wifi.exclamationmark")
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await airlineStore.load() }
                } label: {
                    Label("Opnieuw proberen", systemImage: "arrow.clockwise")
                        .font(.frutiger(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.navyGradient)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Met welke maatschappij vlieg je?")
                    .font(.frutiger(size: 14, weight: .semibold))

                // Snelle keuze: de bekendste maatschappijen als chips.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(popularAirlines) { airline in
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                selectedAirline = airline
                            } label: {
                                HStack(spacing: 5) {
                                    if let flag = airline.flagEmoji { Text(flag) }
                                    Text(airline.name)
                                        .font(.frutiger(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(selectedAirline?.id == airline.id ? .white : Theme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedAirline?.id == airline.id
                                    ? AnyShapeStyle(Theme.navyGradient)
                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                HStack {
                    Text("Alle maatschappijen")
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Picker("Maatschappij", selection: $selectedAirline) {
                        Text("Kies…").tag(Airline?.none)
                        ForEach(sortedAirlines) { airline in
                            Text(airline.name).tag(Optional(airline))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.navy)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var sortedAirlines: [Airline] {
        airlineStore.airlines.sorted {
            ($0.sortOrder ?? .max, $0.name) < ($1.sortOrder ?? .max, $1.name)
        }
    }

    private var popularAirlines: [Airline] { Array(sortedAirlines.prefix(8)) }

    private var dimensionsCard: some View {
        VStack(spacing: 12) {
            clipSlider("Hoogte", value: $length, range: 20...90)
            Divider()
            clipSlider("Breedte", value: $width, range: 10...60)
            Divider()
            clipSlider("Diepte", value: $depth, range: 5...50)
            Divider()
            clipSlider("Gewicht", value: $weight, range: 1...40, unit: "kg", step: 0.5)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func clipSlider(
        _ label: String, value: Binding<Double>,
        range: ClosedRange<Double>, unit: String = "cm", step: Double = 1
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.frutiger(size: 13, weight: .semibold))
                Spacer()
                Text("\(value.wrappedValue.formatted()) \(unit)")
                    .font(.frutiger(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.navy)
            }
            Slider(value: value, in: range, step: step)
                .tint(Theme.navy)
        }
    }

    private var checkButton: some View {
        Button {
            guard let airline = selectedAirline else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await checkStore.check(
                    airlineSlug: airline.slug,
                    length: length, width: width, depth: depth, weight: weight
                )
                if checkStore.result != nil {
                    showAppStoreOverlay = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                if checkStore.isChecking {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.shield.fill")
                }
                Text("Controleer mijn tas")
                    .font(.frutiger(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedAirline == nil ? AnyShapeStyle(Color(.systemGray3)) : AnyShapeStyle(Theme.navyGradient))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(selectedAirline == nil || checkStore.isChecking)
    }

    private func resultCard(_ result: CheckResponse) -> some View {
        VStack(spacing: 10) {
            Image(systemName: result.verdict == .ok ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.verdictColor(result.verdict))
            Text(result.verdictTitle)
                .font(.frutiger(size: 18, weight: .bold))
            Text(result.verdictMessage)
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Text("Meer regels, widgets en Purser Pim? Haal de volledige app.")
                .font(.frutiger(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
