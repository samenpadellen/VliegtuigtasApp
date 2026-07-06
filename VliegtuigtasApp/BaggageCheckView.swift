import SwiftUI

struct BaggageCheckView: View {
    var preselected: Airline?

    @EnvironmentObject private var airlineStore: AirlineStore
    @StateObject private var checkStore = CheckStore()

    @State private var selectedAirline: Airline?
    @State private var selectedVariant: AirlineVariant?
    @State private var length: Double = 55
    @State private var width:  Double = 40
    @State private var depth:  Double = 20
    @State private var weight: Double = 10
    @State private var showAirlinePicker = false
    @State private var showResult = false

    private var canCheck: Bool { selectedAirline != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                airlineSelector
                variantSelector
                Divider().padding(.horizontal, 16)
                dimensionsSection
                weightSection
                checkButton
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Handbagage checker")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await airlineStore.load()
            if let pre = preselected {
                selectedAirline = pre
            }
        }
        .sheet(isPresented: $showAirlinePicker) {
            AirlinePickerSheet(airlines: airlineStore.airlines, selected: $selectedAirline)
                .onDisappear { selectedVariant = nil }
        }
        .sheet(isPresented: $showResult) {
            if let result = checkStore.result, let airline = selectedAirline {
                // Zelfde resultaatscherm als de grote checker: verdict,
                // passende tassen, shoproute en vervolgstappen.
                NavigationStack {
                    ResultStepView(
                        result: result,
                        airline: airline,
                        dimensions: (length, width, depth, weight),
                        onReset: { showResult = false }
                    )
                    .background(Color(.systemGroupedBackground))
                    .navigationTitle("Resultaat")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Klaar") { showResult = false }
                        }
                    }
                }
            }
        }
        .onChange(of: checkStore.result) { _, new in
            if new != nil { showResult = true }
        }
    }

    // MARK: - Sections

    private var airlineSelector: some View {
        Card {
            Button {
                showAirlinePicker = true
            } label: {
                HStack(spacing: 12) {
                    if let airline = selectedAirline {
                        AirlineLogo(airline: airline, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(airline.name).font(.body1).fontWeight(.semibold)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Tik om te wijzigen").font(.caption1).foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 36)).foregroundStyle(Theme.sky)
                        Text("Kies maatschappij")
                            .font(.body1).fontWeight(.semibold)
                            .foregroundStyle(Theme.sky)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var variantSelector: some View {
        if let variants = selectedAirline?.variants, variants.count > 1 {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ticket type").font(.caption1).foregroundStyle(Theme.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(variants) { v in
                                VariantChip(variant: v, selected: selectedVariant?.id == v.id) {
                                    selectedVariant = (selectedVariant?.id == v.id) ? nil : v
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 16)
        }
    }

    private var dimensionsSection: some View {
        Card {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "ruler").foregroundStyle(Theme.sky)
                    Text("Afmetingen").font(.headline2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MeasurementField(label: "Lengte",  unit: "cm", value: $length, range: 1...100, step: 1)
                MeasurementField(label: "Breedte", unit: "cm", value: $width,  range: 1...80,  step: 1)
                MeasurementField(label: "Diepte",  unit: "cm", value: $depth,  range: 1...60,  step: 1)
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    private var weightSection: some View {
        Card {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass").foregroundStyle(Theme.sky)
                    Text("Gewicht").font(.headline2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MeasurementField(label: "Gewicht", unit: "kg", value: $weight, range: 1...40, step: 0.5)
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    private var checkButton: some View {
        VStack(spacing: 8) {
            PrimaryButton(checkStore.isChecking ? "Bezig met controleren…" : "Controleer nu",
                          icon: checkStore.isChecking ? nil : "checkmark.shield") {
                runCheck()
            }
            .disabled(!canCheck || checkStore.isChecking)
            .opacity(canCheck ? 1 : 0.5)

            if let err = checkStore.error {
                Label(err, systemImage: "exclamationmark.circle")
                    .font(.caption1).foregroundStyle(Theme.red)
            }

            if !canCheck {
                Text("Selecteer eerst een maatschappij")
                    .font(.caption1).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func runCheck() {
        guard let airline = selectedAirline else { return }
        Task {
            await checkStore.check(
                airlineSlug: airline.slug,
                length: length, width: width, depth: depth, weight: weight
            )
        }
    }
}

// MARK: - Variant chip

private struct VariantChip: View {
    let variant: AirlineVariant
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(variant.variantName)
                .font(.frutiger(size: 13, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Theme.navy : Theme.card)
                .foregroundStyle(selected ? .white : Theme.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Airline picker sheet

struct AirlinePickerSheet: View {
    let airlines: [Airline]
    @Binding var selected: Airline?
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [Airline] {
        search.isEmpty ? airlines : airlines.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { airline in
                Button {
                    selected = airline
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        AirlineLogo(airline: airline, size: 40)
                        Text(airline.name).font(.body1)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if selected?.id == airline.id {
                            Image(systemName: "checkmark").foregroundStyle(Theme.sky)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Zoek maatschappij")
            .navigationTitle("Kies maatschappij")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
            }
        }
    }
}
