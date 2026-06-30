import SwiftUI

struct AirlineDetailView: View {
    let airline: Airline
    @State private var detail: Airline?
    @State private var isLoading = false
    @State private var navigateToCheck = false

    var display: Airline { detail ?? airline }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeader
                content
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .task { await loadDetail() }
        .overlay { if isLoading && detail == nil { LoadingOverlay() } }
        .navigationDestination(isPresented: $navigateToCheck) {
            BaggageCheckView(preselected: display)
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [Theme.sky.opacity(0.15), Color(.systemGroupedBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 200)

            VStack(spacing: 12) {
                // Logo
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                    AirlineLogo(airline: display, size: 64)
                }

                VStack(spacing: 4) {
                    Text(display.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    if let date = display.lastVerifiedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.green)
                            Text("Geverifieerd op \(formattedDate(date))")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 16) {
            // CTA
            Button {
                navigateToCheck = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill").font(.system(size: 16))
                    Text("Controleer mijn tas")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.navyGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Theme.navy.opacity(0.30), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            if let variants = display.variants, !variants.isEmpty {
                sectionHeader("Bagageregels")
                ForEach(variants) { variant in
                    VariantCard(variant: variant)
                }
            }

            if let notes = display.extraNotes {
                sectionHeader("Extra informatie")
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Theme.sky)
                        .font(.system(size: 18))
                    Text(notes)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }

            if let sourceUrl = display.sourceUrl, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Bekijk officiële bagagepagina")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Theme.sky)
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func formattedDate(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: raw) else { return raw }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "nl_NL")
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    private func loadDetail() async {
        isLoading = true
        detail = try? await APIClient.shared.airline(slug: airline.slug)
        isLoading = false
    }
}

// MARK: - Variant card

private struct VariantCard: View {
    let variant: AirlineVariant
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button { withAnimation(.spring(response: 0.35)) { expanded.toggle() } } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(variant.variantName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        if let large = variant.includesLargeBag {
                            Text(large ? "Incl. grote handbagage" : "Klein persoonlijk item")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    if let large = variant.includesLargeBag {
                        Image(systemName: large ? "bag.fill" : "bag")
                            .font(.system(size: 14))
                            .foregroundStyle(large ? Theme.green : Theme.orange)
                            .padding(8)
                            .background((large ? Theme.green : Theme.orange).opacity(0.1))
                            .clipShape(Circle())
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 16)

                VStack(spacing: 10) {
                    DimBlock(
                        icon: "person.fill",
                        color: Theme.sky,
                        title: "Klein persoonlijk item",
                        subtitle: "Onder de stoel voor u",
                        dims: variant.smallDimString
                    )

                    if variant.includesLargeBag == true {
                        DimBlock(
                            icon: "bag.fill",
                            color: Theme.green,
                            title: "Grote handbagage",
                            subtitle: "In het bagagevak boven u",
                            dims: variant.largeDimString,
                            weight: variant.maxWeightKg
                        )
                    } else if let w = variant.maxWeightKg {
                        HStack(spacing: 10) {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(Theme.sky)
                                .frame(width: 20)
                            Text("Max. gewicht: \(String(format: "%.0f", w)) kg")
                                .font(.system(size: 14, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                    }

                    if let notes = variant.notes {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Theme.yellow)
                                .font(.system(size: 14))
                            Text(notes)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 14)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Dimension block

private struct DimBlock: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let dims: String
    var weight: Double? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(dims)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                if let w = weight {
                    Text("max. \(String(format: "%.0f", w)) kg")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
