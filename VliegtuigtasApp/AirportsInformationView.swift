import SwiftUI

// MARK: - Airport Information View

struct AirportSelectionView: View {
    @StateObject private var airportsStore = AirportsStore.shared
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Airport) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nederlandse luchthavens")
                            .font(.frutiger(size: 24, weight: .bold))
                        Text("Kies een luchthaven voor security-info, tips en aankomsttijden.")
                            .font(.frutiger(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(airportsStore.airports) { airport in
                            NavigationLink(destination: AirportDetailView(airport: airport)) {
                                airportRow(airport)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Vertrouwensnoot: eerlijk over hoe actueel de info is.
                    Label(
                        "Regels en tijden wijzigen regelmatig — controleer vlak voor vertrek altijd de officiële luchthavensite.",
                        systemImage: "info.circle"
                    )
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Luchthavens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gereed") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.navy)
                }
            }
        }
    }

    @ViewBuilder
    private func airportRow(_ airport: Airport) -> some View {
        HStack(spacing: 12) {
            AirportLogo(airport: airport, size: 44)
                .opacity(airport.isOperational ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 4) {
                Text(airport.name)
                    .font(.frutiger(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text(airport.iata)
                        .font(.frutiger(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(airport.isOperational ? Theme.navy : Color(.systemGray))
                        .clipShape(Capsule())
                    Text(airport.displayType)
                        .font(.frutiger(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if airport.isOperational {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.system(size: 13, weight: .semibold))
            } else {
                Text("Binnenkort")
                    .font(.frutiger(size: 10, weight: .bold))
                    .foregroundStyle(Theme.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .opacity(airport.isOperational ? 1 : 0.7)
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
                            VStack(alignment: .leading, spacing: 3) {
                                Text(airport.name)
                                    .font(.frutiger(size: 24, weight: .bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(airport.city)
                                    .font(.frutiger(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        HStack(spacing: 8) {
                            Badge(text: airport.iata, color: Theme.navy)
                            Badge(text: airport.displayType, color: Theme.sky)
                        }
                        websiteLink
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Divider().padding(.horizontal, 20)

                    // Nog niet operationeel (Lelystad): eerlijk en duidelijk.
                    if !airport.isOperational {
                        notYetOpenBanner
                    }

                    // Maatschappijen die hier vliegen
                    if let airlines = airport.airlineExamples, !airlines.isEmpty {
                        airlinesSection(airlines)
                    }

                    // Security features
                    if hasSecurityInfo(airport) {
                        securitySection
                    }

                    // Recommendations
                    if airport.recommendedArrivalMinutes != nil {
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
                                        .font(.frutiger(size: 14, weight: .semibold))
                                }
                                Text(notes)
                                    .font(.frutiger(size: 13))
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

    // MARK: - Header-onderdelen

    @ViewBuilder
    private var websiteLink: some View {
        if let urlString = airport.officialUrl, let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Officiële website")
                        .font(.frutiger(size: 13, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.navy.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.top, 2)
        }
    }

    private var notYetOpenBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nog niet open voor passagiers")
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Deze luchthaven verwerkt nog geen commerciële vluchten. We houden de status in de gaten.")
                    .font(.frutiger(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func airlinesSection(_ airlines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "airplane")
                    .foregroundStyle(Theme.sky)
                Text("Maatschappijen die hier vliegen")
                    .font(.frutiger(size: 14, weight: .semibold))
            }

            // Flexibele chip-wrap zodat het bij elk aantal netjes oogt.
            FlowChips(items: airlines)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var securitySection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Theme.sky)
                    Text("Security-informatie")
                        .font(.frutiger(size: 14, weight: .semibold))
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
                    Text("Goed om te weten")
                        .font(.frutiger(size: 14, weight: .semibold))
                }

                if let minutes = airport.recommendedArrivalMinutes {
                    recommendationRow(icon: "calendar", label: "Op tijd zijn (normaal)", value: "\(minutes) min voor vertrek")
                }

                if let minutesHigh = airport.recommendedArrivalMinutesHighSeason {
                    recommendationRow(icon: "calendar.badge.exclamationmark", label: "Op tijd zijn (piek)", value: "\(minutesHigh) min voor vertrek")
                }

                if let opensAt = airport.airportOpensAt {
                    recommendationRow(icon: "sunrise.fill", label: "Luchthaven open vanaf", value: "\(opensAt) uur")
                }

                if let lockers = airport.hasBaggageLockers {
                    recommendationRow(
                        icon: "lock.square.fill",
                        label: "Bagagekluizen",
                        value: lockers ? "Aanwezig" : "Niet aanwezig"
                    )
                }

                if let fastTrack = airport.fastTrackPrice {
                    recommendationRow(icon: "bolt.fill", label: "Fast-track", value: "vanaf €\(String(format: "%.2f", fastTrack))")
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
                    .font(.frutiger(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(airport.tips ?? [], id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Theme.sky)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(tip)
                            .font(.frutiger(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let tips = airport.tips, !tips.isEmpty {
                    Divider()
                    SaveToRemindersButton(
                        titles: tips,
                        notes: "Reistip · \(airport.name)",
                        label: "Bewaar tips in Herinneringen"
                    )
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
                    .font(.frutiger(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(airport.warningMessages ?? [], id: \.self) { warning in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.red)
                            .font(.system(size: 14))
                        Text(warning)
                            .font(.frutiger(size: 13))
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
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.frutiger(size: 13, weight: .semibold))
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
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.frutiger(size: 13, weight: .semibold))
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
                            .font(.frutiger(size: 28, weight: .bold))
                        Text("Deze regels gelden op alle Nederlandse luchthavens")
                            .font(.frutiger(size: 13))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
                                }

                                VStack(spacing: 8) {
                                    ForEach(rules.prohibitedItems, id: \.name) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "xmark.circle")
                                                .foregroundStyle(Theme.red)
                                                .font(.system(size: 12))
                                            Text(item.name)
                                                .font(.frutiger(size: 13))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)

                        SaveToRemindersButton(
                            titles: reminderTitles(for: rules),
                            notes: "EU-handbagageregels · Vliegtuigtas",
                            label: "Bewaar regels in Herinneringen"
                        )
                        .padding(.horizontal, 20)

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gereed") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.navy)
                }
            }
        }
    }

    private func rulesCard(title: String, description: String, details: [String] = []) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(description)
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)

                if !details.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(details, id: \.self) { detail in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.sky)
                                    .frame(width: 4, height: 4)
                                Text(detail)
                                    .font(.frutiger(size: 12))
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

    /// Beknopte, actiegerichte samenvatting van de EU-regels als losse
    /// herinneringen — geen lappen tekst, maar precies wat je moet onthouden
    /// terwijl je inpakt.
    private func reminderTitles(for rules: EULuggageRules) -> [String] {
        [
            "Vloeistoffen: max. \(rules.fluidRule.maxMlPerBottle) ml per verpakking, samen in één zakje van \(rules.fluidRule.maxTotalLiters == 1 ? "1" : "\(rules.fluidRule.maxTotalLiters)") liter",
            "Powerbanks & losse batterijen in handbagage (niet in ruimbagage)",
            "E-sigaretten/vapes alleen in handbagage",
            "Scherpe voorwerpen (lemmet > 6 cm) niet in handbagage"
        ]
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
                            .font(.frutiger(size: 28, weight: .bold))
                        Text("Informatie voor vluchten van buiten de EU")
                            .font(.frutiger(size: 13))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
                                }

                                VStack(spacing: 8) {
                                    customsRow(icon: "circle", label: "Sterke drank (>22%)", value: customs.alcohol.strongSpirits)
                                    customsRow(icon: "circle", label: "Mousserende wijn", value: customs.alcohol.sparklingWine)
                                }

                                if let notes = customs.alcohol.notes {
                                    Divider().padding(.vertical, 4)
                                    Text(notes)
                                        .font(.frutiger(size: 12))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
                                }

                                VStack(spacing: 8) {
                                    ForEach(customs.restrictedItems, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "xmark.circle")
                                                .foregroundStyle(Theme.red)
                                                .font(.system(size: 12))
                                            Text(item)
                                                .font(.frutiger(size: 13))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gereed") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.navy)
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
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.frutiger(size: 13, weight: .semibold))
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
                            .font(.frutiger(size: 28, weight: .bold))
                        Text("Procedure en je rechten")
                            .font(.frutiger(size: 13))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
                                }

                                Text(issues.immediateReporting)
                                    .font(.frutiger(size: 13))
                                    .foregroundStyle(Theme.textSecondary)

                                Divider().padding(.vertical, 4)

                                Text(issues.pirForm)
                                    .font(.frutiger(size: 13))
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
                                    .font(.frutiger(size: 14, weight: .semibold))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
                                }

                                Text(issues.baggageRedelivery)
                                    .font(.frutiger(size: 13))
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
                                        .font(.frutiger(size: 14, weight: .semibold))
                                }

                                VStack(spacing: 12) {
                                    ForEach(issues.tips, id: \.self) { tip in
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(Theme.sky)
                                                .frame(width: 4, height: 4)
                                                .padding(.top, 7)
                                            Text(tip)
                                                .font(.frutiger(size: 12))
                                                .foregroundStyle(Theme.textSecondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }

                                    Divider()
                                    SaveToRemindersButton(
                                        titles: issues.tips,
                                        notes: "Bagage kwijt of beschadigd — checklist",
                                        label: "Bewaar checklist in Herinneringen"
                                    )
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gereed") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.navy)
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
                        .font(.frutiger(size: 14, weight: .semibold))
                }

                Text(claim.description)
                    .font(.frutiger(size: 13))
                    .foregroundStyle(Theme.textSecondary)

                VStack(spacing: 6) {
                    HStack {
                        Text("Termijn melden:")
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("Binnen \(claim.daysToReport) dagen")
                            .font(.frutiger(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.sky)
                    }

                    HStack {
                        Text("Max. vergoeding:")
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("€\(String(format: "%.0f", claim.maxCompensationEur))")
                            .font(.frutiger(size: 12, weight: .semibold))
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
            .font(.frutiger(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Flow chips (regelbrekende chips)

/// Toont korte labels als chips die vanzelf naar een nieuwe regel wrappen —
/// netjes bij één maatschappij én bij vijf. Gebruikt de native Layout-API.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.skyLight)
                    .clipShape(Capsule())
            }
        }
    }
}

/// Eenvoudige wrap-layout: plaatst subviews op een rij en breekt af zodra de
/// beschikbare breedte op is.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + lineSpacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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
