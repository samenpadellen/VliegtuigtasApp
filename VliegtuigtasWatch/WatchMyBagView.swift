import SwiftUI

/// Bewerk de eigen tasafmetingen met steppers (crown-vriendelijk).
struct WatchMyBagView: View {
    @EnvironmentObject private var bag: WatchBagStore

    var body: some View {
        List {
            Section("Afmetingen") {
                DimensionStepper(label: "Lengte", value: $bag.length, range: 20...90, step: 1, unit: "cm")
                DimensionStepper(label: "Breedte", value: $bag.width, range: 15...70, step: 1, unit: "cm")
                DimensionStepper(label: "Diepte", value: $bag.depth, range: 5...50, step: 1, unit: "cm")
            }
            Section("Gewicht") {
                DimensionStepper(label: "Gewicht", value: $bag.weight, range: 1...32, step: 0.5, unit: "kg")
            }
            Section {
                Label {
                    Text("Maten worden gebruikt voor de pasindicatie per maatschappij.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(WatchTheme.sky)
                }
            }
        }
        .navigationTitle("Mijn tas")
    }
}

private struct DimensionStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(label)
                    .font(.footnote)
                Spacer()
                Text("\(value.clean) \(unit)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WatchTheme.yellow)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchMyBagView()
            .environmentObject(WatchBagStore.shared)
    }
}
