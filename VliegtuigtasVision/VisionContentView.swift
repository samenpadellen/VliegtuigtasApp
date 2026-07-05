import SwiftUI

/// Hoofdvenster op Vision Pro: maatschappijen links, regels + check rechts.
/// Ruimtelijke troef: de koffer op ware grootte openen in je kamer.
struct VisionContentView: View {
    @EnvironmentObject private var airlineStore: AirlineStore
    @State private var selectedAirline: Airline?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            List(filteredAirlines, selection: $selectedAirline) { airline in
                HStack(spacing: 10) {
                    Text(airline.flagEmoji ?? "✈️")
                    Text(airline.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .tag(airline)
            }
            .navigationTitle("Vliegtuigtas")
            .searchable(text: $searchText, prompt: "Zoek maatschappij")
            .overlay {
                if airlineStore.isLoading && airlineStore.airlines.isEmpty {
                    ProgressView("Laden…")
                }
            }
        } detail: {
            if let airline = selectedAirline {
                VisionAirlineDetail(airline: airline)
                    .id(airline.id)
            } else {
                ContentUnavailableView(
                    "Kies een maatschappij",
                    systemImage: "airplane",
                    description: Text("Bekijk de bagageregels en check of jouw koffer past, op ware grootte in je kamer.")
                )
            }
        }
        .task { await airlineStore.load() }
    }

    private var filteredAirlines: [Airline] {
        let sorted = airlineStore.airlines.sorted {
            ($0.sortOrder ?? .max, $0.name) < ($1.sortOrder ?? .max, $1.name)
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Detail: regels + check + ware grootte

private struct VisionAirlineDetail: View {
    let airline: Airline

    @StateObject private var checkStore = CheckStore()
    @ObservedObject private var bagState = VisionBagState.shared
    @Environment(\.openWindow) private var openWindow

    @State private var length: Double = 55
    @State private var width: Double = 40
    @State private var depth: Double = 20
    @State private var weight: Double = 10

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                rulesGrid

                checkPanel
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(airline.name)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            if let result = checkStore.result {
                resultBanner(result)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Handbagageregels")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            if let date = airline.lastVerifiedDate {
                Label("Geverifieerd op \(date)", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Regels per tickettype, compacte kaartjes
    private var rulesGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(airline.variants ?? []) { variant in
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(variant.variantName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        if let kg = variant.maxWeightKg {
                            Text("max. \(Int(kg)) kg")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if variant.smallLCm != nil {
                            Text("Klein: \(variant.smallDimString)")
                        }
                        if variant.includesLargeBag == true, variant.largeLCm != nil {
                            Text("Groot: \(variant.largeDimString)")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // Check-paneel met sliders + ware-grootte-knop
    private var checkPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Check je koffer")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            dimSlider("Hoogte", value: $length, range: 20...90)
            dimSlider("Breedte", value: $width, range: 10...70)
            dimSlider("Diepte", value: $depth, range: 5...50)
            dimSlider("Gewicht", value: $weight, range: 1...40, unit: "kg", step: 0.5)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await checkStore.check(
                            airlineSlug: airline.slug,
                            length: length, width: width, depth: depth, weight: weight
                        )
                    }
                } label: {
                    Label(
                        checkStore.isChecking ? "Checken…" : "Controleer",
                        systemImage: "checkmark.shield.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(checkStore.isChecking)

                // De visionOS-troef: ware grootte in je kamer
                Button {
                    bagState.bagDims = (length, width, depth)
                    bagState.airlineName = airline.name
                    bagState.limitDims = largestAllowed
                    openWindow(id: "bag-volume")
                } label: {
                    Label("Toon op ware grootte", systemImage: "cube.transparent")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var largestAllowed: (h: Double, w: Double, d: Double)? {
        let variant = airline.variants?.first { $0.includesLargeBag == true }
            ?? airline.variants?.first
        if let l = variant?.largeLCm, let w = variant?.largeWCm, let d = variant?.largeDCm {
            return (l, w, d)
        }
        if let l = variant?.smallLCm, let w = variant?.smallWCm, let d = variant?.smallDCm {
            return (l, w, d)
        }
        return nil
    }

    private func dimSlider(
        _ label: String, value: Binding<Double>,
        range: ClosedRange<Double>, unit: String = "cm", step: Double = 1
    ) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(width: 80, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text("\(value.wrappedValue.formatted()) \(unit)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
        }
    }

    private func resultBanner(_ result: CheckResponse) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.verdict == .ok ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(result.verdict == .ok ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.verdictTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(result.verdictMessage)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassBackgroundEffect()
    }
}
