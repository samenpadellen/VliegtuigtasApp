import SwiftUI

// MARK: - Airport Information View

struct AirportSelectionView: View {
    @StateObject private var airportsStore = AirportsStore.shared
    let onSelect: (Airport) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nederlandse Luchthavens")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Selecteer een luchthaven voor specifieke informatie")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    VStack(spacing: 10) {
                        ForEach(airportsStore.airports) { airport in
                            NavigationLink(destination: AirportDetailView(airport: airport)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        AirportLogo(airport: airport, size: 44)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(airport.name)
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Theme.textPrimary)
                                                .multilineTextAlignment(.leading)
                                            HStack(spacing: 8) {
                                                Text(airport.iata)
                                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Theme.navy)
                                                    .clipShape(Capsule())
                                                Text(airport.type)
                                                    .font(.system(size: 11, design: .rounded))
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(Theme.textSecondary)
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                                .padding(14)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Airport Detail View

struct AirportDetailView: View {
    let airport: Airport

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            AirportLogo(airport: airport, size: 56)
                            Text(airport.name)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 12) {
                            Badge(text: airport.iata, color: Theme.navy)
                            Badge(text: airport.type, color: Theme.sky)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Divider().padding(.horizontal, 20)

                    // Security features
                    if hasSecurityInfo(airport) {
                        securitySection
                    }

                    // Recommendations
                    if let minutes = airport.recommendedArrivalMinutes {
                        recommendationsSection
                    }

                    // Tips
                    if let tips = airport.tips, !tips.isEmpty {
                        tipsSection
                    }

                    // Warnings
                    if let warnings = airport.warningMessages, !warnings.isEmpty {
                        warningsSection
                    }

                    // Special notes
                    if let notes = airport.specialNotes {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(Theme.yellow)
                                    Text("Bijzonderheden")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                Text(notes)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 32)
                }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(airport.iata)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var securitySection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Theme.sky)
                    Text("Security-informatie")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }

                if let has3D = airport.has3DCtScan {
                    securityRow(
                        icon: "camera.fill",
                        label: "3D CT-scanners",
                        value: has3D ? "Ja - vloeistoffen hoeven niet uit tas" : "Nee",
                        color: has3D ? Theme.green : Theme.orange
                    )
                }

                if let fluidsRemoved = airport.fluidsMustBeRemoved {
                    securityRow(
                        icon: "drop.fill",
                        label: "Vloeistoffen uit tas",
                        value: fluidsRemoved ? "Ja" : "Nee",
                        color: fluidsRemoved ? Theme.orange : Theme.green
                    )
                }

                if let electronicsOut = airport.electronicsOutOfBag {
                    securityRow(
                        icon: "laptopcomputer",
                        label: "Elektronica uit tas",
                        value: electronicsOut ? "Ja" : "Nee",
                        color: electronicsOut ? Theme.orange : Theme.green
                    )
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Theme.sky)
                    Text("Aankomst aanbevelingen")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }

                if let minutes = airport.recommendedArrivalMinutes {
                    recommendationRow(icon: "calendar", label: "Normaal seizoen", value: "\(minutes) minuten voor vertrek")
                }

                if let minutesHigh = airport.recommendedArrivalMinutesHighSeason {
                    recommendationRow(icon: "calendar", label: "Piekseizoen", value: "\(minutesHigh) minuten voor vertrek")
                }

                if let fastTrack = airport.fastTrackPrice {
                    recommendationRow(icon: "bolt.fill", label: "Fast-track", value: "€\(String(format: "%.2f", fastTrack))")
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Theme.yellow)
                Text("Handige tips")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(airport.tips ?? [], id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Theme.sky)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(tip)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.red)
                Text("Let op!")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(airport.warningMessages ?? [], id: \.self) { warning in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.red)
                            .font(.system(size: 14))
                        Text(warning)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.red)
                    }
                }
            }
            .padding(16)
            .background(Theme.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
    }

    private func hasSecurityInfo(_ airport: Airport) -> Bool {
        airport.has3DCtScan != nil || airport.fluidsMustBeRemoved != nil ||
        airport.electronicsOutOfBag != nil || airport.jewelryMustBeRemoved != nil
    }

    private func securityRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }

    private func recommendationRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Theme.sky)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.sky)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - EU Rules View

struct EURulesView: View {
    @StateObject private var airportsStore = AirportsStore.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EU Handbagage Regels")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Deze regels gelden op alle Nederlandse luchthavens")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if let rules = airportsStore.euRules {
                        // Fluids
                        rulesCard(
                            title: "💧 \(rules.fluidRule.title)",
                            description: rules.fluidRule.description,
                            details: [
                                "Max. \(rules.fluidRule.maxMlPerBottle) ml per verpakking",
                                "Max. \(rules.fluidRule.maxTotalLiters) liter totaal",
                                "In één doorzichtige hersluitbare zak (ca. 20×20 cm)"
                            ]
                        )

                        // Power banks
                        rulesCard(
                            title: "🔋 \(rules.powerBankRule.title)",
                            description: rules.powerBankRule.details
                        )

                        // E-cigarettes
                        rulesCard(
                            title: "💨 E-sigaretten/Vapes",
                            description: rules.ecigaretteRule
                        )

                        // Sharp objects
                        rulesCard(
                            title: "✂️ Scherpe voorwerpen",
                            description: rules.sharpObjectsRule
                        )

                        // Prohibited items
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.red)
                                    Text("Volledig verboden")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                VStack(spacing: 8) {
                                    ForEach(rules.prohibitedItems, id: \.name) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "xmark.circle")
                                                .foregroundStyle(Theme.red)
                                                .font(.system(size: 12))
                                            Text(item.name)
                                                .font(.system(size: 13, design: .rounded))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Terug")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.navy)
                    }
                }
            }
        }
    }

    private func rulesCard(title: String, description: String, details: [String] = []) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                if !details.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(details, id: \.self) { detail in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.sky)
                                    .frame(width: 4, height: 4)
                                Text(detail)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Customs Info View

struct CustomsInfoView: View {
    @StateObject private var airportsStore = AirportsStore.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Douane & Belastingvrij Importeren")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Informatie voor vluchten van buiten de EU")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if let customs = airportsStore.customsInfo {
                        // Limits
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "eurosign.circle.fill")
                                        .foregroundStyle(Theme.sky)
                                    Text("Belastingvrije invoerlimieten")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                customsRow(icon: "airplane", label: "Per vliegtuig", value: "€\(String(format: "%.0f", customs.dutyfreeImportLimit))")
                                customsRow(icon: "figure.walk", label: "Over land", value: "€\(String(format: "%.0f", customs.landImportLimit))")
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        // Tobacco
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "nosign")
                                        .foregroundStyle(Theme.orange)
                                    Text("Tabak (kies één optie)")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                VStack(spacing: 8) {
                                    customsRow(icon: "circle", label: "Sigaretten", value: "\(customs.tobacco.cigarettes) stuks")
                                    customsRow(icon: "circle", label: "Shag/pijptabak", value: "\(customs.tobacco.shaggingTobacco) gram")
                                    customsRow(icon: "circle", label: "Cigarillo's", value: "\(customs.tobacco.cigarillos) stuks")
                                    customsRow(icon: "circle", label: "Sigaren", value: "\(customs.tobacco.cigars) stuks")
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        // Alcohol
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "wineglass")
                                        .foregroundStyle(Theme.red)
                                    Text("Alcohol")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                VStack(spacing: 8) {
                                    customsRow(icon: "circle", label: "Sterke drank (>22%)", value: customs.alcohol.strongSpirits)
                                    customsRow(icon: "circle", label: "Mousserende wijn", value: customs.alcohol.sparklingWine)
                                }

                                if let notes = customs.alcohol.notes {
                                    Divider().padding(.vertical, 4)
                                    Text(notes)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        // Cash
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "banknote.fill")
                                        .foregroundStyle(Theme.green)
                                    Text("Geldmiddelen")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                customsRow(icon: "circle", label: "Aangifte verplicht bij", value: "€\(String(format: "%.0f", customs.cashDeclarationThreshold))+")
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        // Restricted items
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.red)
                                    Text("Nooit toegestaan")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                VStack(spacing: 8) {
                                    ForEach(customs.restrictedItems, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "xmark.circle")
                                                .foregroundStyle(Theme.red)
                                                .font(.system(size: 12))
                                            Text(item)
                                                .font(.system(size: 13, design: .rounded))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Terug")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.navy)
                    }
                }
            }
        }
    }

    private func customsRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Theme.sky)
                .frame(width: 12)
                .font(.system(size: 8, weight: .semibold))
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.sky)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Baggage Issues View

struct BaggageIssuesView: View {
    @StateObject private var airportsStore = AirportsStore.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bagage Kwijt of Beschadigd?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Procedure en je rechten")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if let issues = airportsStore.baggageIssueInfo {
                        // Immediate steps
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(Theme.red)
                                    Text("Direct na aankomst")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                Text(issues.immediateReporting)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)

                                Divider().padding(.vertical, 4)

                                Text(issues.pirForm)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        // Claims
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(Theme.sky)
                                Text("Claim-mogelijkheden")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 12) {
                                ForEach(issues.claims, id: \.condition) { claim in
                                    claimCard(claim)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Redelivery
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "truck.box.fill")
                                        .foregroundStyle(Theme.green)
                                    Text("Thuisbezorging")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                Text(issues.baggageRedelivery)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        // Tips
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(Theme.yellow)
                                    Text("Handige tips")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }

                                VStack(spacing: 8) {
                                    ForEach(issues.tips, id: \.self) { tip in
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(Theme.sky)
                                                .frame(width: 4, height: 4)
                                                .padding(.top, 7)
                                            Text(tip)
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Terug")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.navy)
                    }
                }
            }
        }
    }

    private func claimCard(_ claim: BaggageIssueInfo.Claim) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.sky)
                    Text(claim.condition)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }

                Text(claim.description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                VStack(spacing: 6) {
                    HStack {
                        Text("Termijn melden:")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("Binnen \(claim.daysToReport) dagen")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.sky)
                    }

                    HStack {
                        Text("Max. vergoeding:")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("€\(String(format: "%.0f", claim.maxCompensationEur))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.green)
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Badge Component

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Airport Logo

/// Logo van de luchthaven via logo.dev (op basis van het domein). Valt terug
/// op een vliegtuig-icoon als er geen domein/logo beschikbaar is.
///
/// Bewust `AsyncImage` i.p.v. de gedeelde `AuthorisedImage`: die stuurt onze
/// eigen API-bearer-token mee op élke request, en dat token hoort niet naar
/// een externe host als logo.dev te lekken. logo.dev authenticeert via de
/// `?token=`-querystring (publishable key), niet via een Authorization-header.
struct AirportLogo: View {
    let airport: Airport
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(Theme.skyLight)

            if let logo = airport.logoUrl.flatMap(URL.init) {
                AsyncImage(url: logo) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(size * 0.16)
                    case .empty:
                        ProgressView().tint(Theme.sky).scaleEffect(0.6)
                    case .failure:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24)
                .strokeBorder(Color(.systemGray5), lineWidth: 1)
        )
    }

    private var fallbackIcon: some View {
        Image(systemName: "airplane.departure")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.navy)
    }
}
