import SwiftUI

/// Bagage-info per maatschappij: persoonlijk item, per variant de kleine/grote
/// handbagagematen en gewicht, met pas-indicatie op basis van de eigen tas.
struct WatchAirlineDetailView: View {
    let airline: Airline
    @EnvironmentObject private var bag: WatchBagStore

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    WatchAirlineLogo(airline: airline, height: 22)
                    Text(airline.name)
                        .font(.frutiger(size: 17, weight: .semibold, relativeTo: .headline))
                }
            }

            if hasPersonalItem {
                Section("Persoonlijk item") {
                    DimRow(
                        title: "Onder de stoel",
                        dims: dimString(airline.personalItemLCm, airline.personalItemWCm, airline.personalItemDCm),
                        fits: bag.fits(l: airline.personalItemLCm, w: airline.personalItemWCm, d: airline.personalItemDCm)
                    )
                }
            }

            ForEach(airline.variants ?? []) { variant in
                Section(variant.variantName) {
                    if variant.smallLCm != nil {
                        DimRow(
                            title: "Klein (onder stoel)",
                            dims: variant.smallDimString,
                            fits: bag.fits(l: variant.smallLCm, w: variant.smallWCm, d: variant.smallDCm)
                        )
                    }
                    if variant.largeLCm != nil {
                        DimRow(
                            title: "Groot (bagagevak)",
                            dims: variant.largeDimString,
                            fits: variant.includesLargeBag == false
                                ? nil
                                : bag.fits(l: variant.largeLCm, w: variant.largeWCm, d: variant.largeDCm)
                        )
                    }
                    if let kg = variant.maxWeightKg {
                        DimRow(
                            title: "Max. gewicht",
                            dims: "\(kg.clean) kg",
                            fits: bag.fitsWeight(kg)
                        )
                    }
                    if variant.includesLargeBag == false {
                        Text("Grote handbagage niet inbegrepen bij dit ticket.")
                            .font(.frutiger(size: 13, relativeTo: .footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let notes = airline.extraNotes, !notes.isEmpty {
                Section("Let op") {
                    Text(notes)
                        .font(.frutiger(size: 13, relativeTo: .footnote))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Jouw tas: \(bag.dimsLabel)")
                    .font(.frutiger(size: 13, relativeTo: .footnote))
                    .foregroundStyle(.secondary)
                Text("Pasindicatie is een benadering; de app op je iPhone doet de officiële check.")
                    .font(.frutiger(size: 13, relativeTo: .footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(airline.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasPersonalItem: Bool {
        airline.personalItemLCm != nil
    }

    private func dimString(_ l: Double?, _ w: Double?, _ d: Double?) -> String {
        let parts = [l, w, d].compactMap { $0.map { "\(Int($0))" } }
        return parts.isEmpty ? "–" : parts.joined(separator: " × ") + " cm"
    }
}

private struct DimRow: View {
    let title: String
    let dims: String
    /// nil = geen indicatie tonen (maten onbekend of niet van toepassing)
    let fits: Bool?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.frutiger(size: 13, relativeTo: .footnote))
                    .foregroundStyle(.secondary)
                Text(dims)
                    .font(.body.weight(.semibold))
            }
            Spacer()
            if let fits {
                Image(systemName: fits ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(fits ? WatchTheme.green : WatchTheme.red)
            }
        }
    }
}
