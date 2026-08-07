import SwiftUI

// MARK: - Model

/// Een benoemde tas of koffer van de gebruiker ("Rode trolley", "Werkrugzak").
struct SavedBag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var length: Double   // hoogte (cm)
    var width: Double    // breedte (cm)
    var depth: Double    // diepte (cm)
    var weight: Double   // kg

    var dimsLabel: String { "\(Int(length)) × \(Int(width)) × \(Int(depth)) cm" }
}

// MARK: - Opslag (lokaal + iCloud)

/// Beheert de tassenverzameling: UserDefaults als bron, iCloud als sync.
@MainActor
final class BagCollectionStore: ObservableObject {
    static let shared = BagCollectionStore()
    static let storageKey = "vt_saved_bags"

    @Published private(set) var bags: [SavedBag] = []

    private let defaults = UserDefaults.standard

    private init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([SavedBag].self, from: data) {
            bags = decoded
        } else if let dims = CloudSync.shared.savedBagDims() {
            // Migratie: de eerder onthouden checker-maten worden je eerste tas.
            bags = [SavedBag(name: "Mijn tas", length: dims.length, width: dims.width,
                             depth: dims.depth, weight: dims.weight)]
            persist()
        }
    }

    func upsert(_ bag: SavedBag) {
        if let index = bags.firstIndex(where: { $0.id == bag.id }) {
            bags[index] = bag
        } else {
            bags.append(bag)
        }
        persist()
    }

    func remove(_ bag: SavedBag) {
        bags.removeAll { $0.id == bag.id }
        persist()
    }

    func removeAll() {
        bags = []
        persist()
    }

    /// Vanuit iCloud overgenomen — alleen lokaal schrijven, niet terugpushen.
    func adopt(data: Data) {
        guard let decoded = try? JSONDecoder().decode([SavedBag].self, from: data) else { return }
        bags = decoded
        defaults.set(data, forKey: Self.storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bags) else { return }
        defaults.set(data, forKey: Self.storageKey)
        CloudSync.shared.pushBagList(data)
    }
}

// MARK: - Pas-logica (lokaal, oriëntatie-onafhankelijk)

/// Oordeel van één tas bij één maatschappij, op basis van het ruimste tarief.
struct BagAirlineFit {
    let underSeat: Bool?        // nil = maten onbekend
    let cabinBag: Bool?         // nil = geen grote handbagage in het tarief
    let withinWeight: Bool?     // nil = geen gewichtslimiet bekend
    let smallDims: String?
    let largeDims: String?
    let maxWeightKg: Double?

    /// Mag hij überhaupt de cabine in?
    var allowedInCabin: Bool {
        let weightOK = withinWeight ?? true
        return weightOK && ((underSeat ?? false) || (cabinBag ?? false))
    }

    static func evaluate(bag: SavedBag, airline: Airline) -> BagAirlineFit {
        let variant = airline.variants?.first { $0.includesLargeBag == true }
            ?? airline.variants?.first

        func fits(_ l: Double?, _ w: Double?, _ d: Double?) -> Bool? {
            guard let l, let w, let d else { return nil }
            let b = [bag.length, bag.width, bag.depth].sorted(by: >)
            let limit = [l, w, d].sorted(by: >)
            return b[0] <= limit[0] && b[1] <= limit[1] && b[2] <= limit[2]
        }
        func label(_ l: Double?, _ w: Double?, _ d: Double?) -> String? {
            guard let l, let w, let d else { return nil }
            return "\(Int(l))×\(Int(w))×\(Int(d))"
        }

        let smallL = variant?.smallLCm ?? airline.personalItemLCm
        let smallW = variant?.smallWCm ?? airline.personalItemWCm
        let smallD = variant?.smallDCm ?? airline.personalItemDCm

        let hasLarge = variant?.includesLargeBag == true && variant?.largeLCm != nil

        return BagAirlineFit(
            underSeat: fits(smallL, smallW, smallD),
            cabinBag: hasLarge ? fits(variant?.largeLCm, variant?.largeWCm, variant?.largeDCm) : nil,
            withinWeight: variant?.maxWeightKg.map { bag.weight <= $0 },
            smallDims: label(smallL, smallW, smallD),
            largeDims: hasLarge ? label(variant?.largeLCm, variant?.largeWCm, variant?.largeDCm) : nil,
            maxWeightKg: variant?.maxWeightKg
        )
    }
}

// MARK: - Overzicht: passen mijn tassen?

/// Eén overzicht van ál je tassen en koffers bij een gekozen maatschappij:
/// onder de stoel ja/nee, bagagevak ja/nee, en het eindoordeel
/// (mee in de cabine of alleen als ruimbagage).
struct MyBagsOverviewView: View {
    @EnvironmentObject private var airlineStore: AirlineStore
    @ObservedObject private var collection = BagCollectionStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAirline: Airline?
    @State private var editingBag: SavedBag?
    @State private var showNewBag = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    airlinePicker

                    if collection.bags.isEmpty {
                        emptyState
                    } else if let airline = selectedAirline {
                        ForEach(collection.bags) { bag in
                            BagFitCard(bag: bag, airline: airline) {
                                editingBag = bag
                            }
                        }
                    }

                    Button {
                        showNewBag = true
                    } label: {
                        Label("Tas of koffer toevoegen", systemImage: "plus")
                            .font(.frutiger(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Theme.navy.opacity(0.07))
                            .foregroundStyle(Theme.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Passen mijn tassen?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
            }
            .task {
                await airlineStore.load()
                if selectedAirline == nil {
                    selectedAirline = airlineStore.airlines
                        .sorted { ($0.sortOrder ?? .max, $0.name) < ($1.sortOrder ?? .max, $1.name) }
                        .first
                }
            }
            .sheet(item: $editingBag) { bag in
                BagEditorSheet(bag: bag)
            }
            .sheet(isPresented: $showNewBag) {
                BagEditorSheet(bag: nil)
            }
        }
    }

    private var airlinePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(airlineStore.airlines.prefix(12)) { airline in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.3)) { selectedAirline = airline }
                    } label: {
                        Text(airline.name)
                            .font(.frutiger(size: 13, weight: .semibold))
                            .foregroundStyle(selectedAirline?.id == airline.id ? .white : Theme.textPrimary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                selectedAirline?.id == airline.id
                                    ? AnyShapeStyle(Theme.inkGradient)
                                    : AnyShapeStyle(Color(.systemBackground))
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "suitcase.rolling")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.textSecondary)
            Text("Nog geen tassen of koffers")
                .font(.frutiger(size: 15, weight: .bold))
            Text("Voeg je tassen toe met naam en maten. Daarna zie je hier per maatschappij direct wat mee mag.")
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Pas-kaart per tas

private struct BagFitCard: View {
    let bag: SavedBag
    let airline: Airline
    let onEdit: () -> Void

    private var fit: BagAirlineFit { .evaluate(bag: bag, airline: airline) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "suitcase.rolling.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.yellow)
                    .frame(width: 38, height: 38)
                    .background(Theme.yellow.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(bag.name)
                        .font(.frutiger(size: 15, weight: .bold))
                    Text("\(bag.dimsLabel) · \(bag.weight.formatted()) kg")
                        .font(.frutiger(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 32, height: 32)
                        .background(Theme.navy.opacity(0.07))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bewerk \(bag.name)")
            }

            // Eindoordeel
            verdictChip

            Divider()

            fitRow(
                title: "Onder de stoel",
                detail: fit.smallDims.map { "max \($0) cm" },
                status: fit.underSeat
            )
            fitRow(
                title: "Bagagevak (grote handbagage)",
                detail: fit.largeDims.map { dims in
                    "max \(dims) cm" + (fit.maxWeightKg.map { " · \(Int($0)) kg" } ?? "")
                },
                status: fit.cabinBag
            )
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private var verdictChip: some View {
        let tooHeavy = fit.withinWeight == false
        if fit.allowedInCabin {
            chip(
                text: fit.underSeat == true && fit.cabinBag != true
                    ? "Mag mee, onder de stoel"
                    : "Mag mee in de cabine",
                icon: "checkmark.seal.fill", color: Theme.green
            )
        } else if tooHeavy {
            chip(
                text: "Te zwaar voor de cabine (max \(Int(fit.maxWeightKg ?? 0)) kg), inchecken als ruimbagage",
                icon: "scalemass.fill", color: Theme.orange
            )
        } else {
            chip(
                text: "Past niet in de cabine, inchecken als ruimbagage",
                icon: "xmark.seal.fill", color: Theme.red
            )
        }
    }

    private func chip(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.frutiger(size: 12, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func fitRow(title: String, detail: String?, status: Bool?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: status == true ? "checkmark.circle.fill"
                    : (status == false ? "xmark.circle.fill" : "minus.circle"))
                .font(.system(size: 15))
                .foregroundStyle(status == true ? Theme.green
                    : (status == false ? Theme.red : Theme.textSecondary))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.frutiger(size: 13, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.frutiger(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            Text(status == true ? "Ja" : (status == false ? "Nee" : "Onbekend"))
                .font(.frutiger(size: 12, weight: .bold))
                .foregroundStyle(status == true ? Theme.green
                    : (status == false ? Theme.red : Theme.textSecondary))
        }
    }
}

// MARK: - Tas toevoegen / bewerken

struct BagEditorSheet: View {
    let bag: SavedBag?

    @ObservedObject private var collection = BagCollectionStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var length: Double
    @State private var width: Double
    @State private var depth: Double
    @State private var weight: Double

    init(bag: SavedBag?) {
        self.bag = bag
        _name = State(initialValue: bag?.name ?? "")
        _length = State(initialValue: bag?.length ?? 55)
        _width = State(initialValue: bag?.width ?? 40)
        _depth = State(initialValue: bag?.depth ?? 20)
        _weight = State(initialValue: bag?.weight ?? 8)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Naam")
                            .font(.frutiger(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        TextField("Bijv. Rode trolley of Werkrugzak", text: $name)
                            .font(.frutiger(size: 15))
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(spacing: 12) {
                        editorSlider("Hoogte", value: $length, range: 20...90)
                        Divider()
                        editorSlider("Breedte", value: $width, range: 10...70)
                        Divider()
                        editorSlider("Diepte", value: $depth, range: 5...50)
                        Divider()
                        editorSlider("Gewicht", value: $weight, range: 1...40, unit: "kg", step: 0.5)
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        var saved = bag ?? SavedBag(name: "", length: 0, width: 0, depth: 0, weight: 0)
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        saved.name = trimmed.isEmpty ? "Mijn tas" : trimmed
                        saved.length = length
                        saved.width = width
                        saved.depth = depth
                        saved.weight = weight
                        collection.upsert(saved)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        Text(bag == nil ? "Tas toevoegen" : "Opslaan")
                            .font(.frutiger(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.inkGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    if let bag {
                        Button(role: .destructive) {
                            collection.remove(bag)
                            dismiss()
                        } label: {
                            Label("Verwijder deze tas", systemImage: "trash")
                                .font(.frutiger(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(bag == nil ? "Nieuwe tas of koffer" : "Tas bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
        }
    }

    private func editorSlider(
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
}
