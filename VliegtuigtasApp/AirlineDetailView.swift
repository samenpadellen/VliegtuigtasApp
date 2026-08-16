import SwiftUI

private var airlineDetailStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct AirlineDetailView: View {
    let airline: Airline
    @EnvironmentObject private var nav: AppNavigator
    @State private var detail: Airline?
    @State private var matchingBags: [Bag] = []
    @State private var selectedBagId: String?
    @State private var isLoading = false
    @State private var navigateToCheck = false
    // Merkkleur uit het logo: kleurt de hero en accenten subtiel mee met de
    // maatschappij (KLM-blauw, Ryanair-navy, Transavia-groen …).
    @State private var brandTint: Color?
    @StateObject private var logoLoader = ImageLoader()
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { brandTint ?? Theme.sky }

    var display: Airline { detail ?? airline }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                    content
                        .padding(.horizontal, Theme.Spacing.base)
                        .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground))

            // Zwevende terugknop: de merkkleur-gradient loopt nu helemaal
            // door tot boven, dus de knop zweeft los over de hero heen in
            // plaats van in een systeem-navigatiebalk te zitten.
            HStack {
                FloatingBackButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.base)
            .padding(.top, airlineDetailStatusBarHeight + 10)
        }
        .navigationBarHidden(true)
        .task { await loadDetail() }
        .onAppear {
            if let url = display.bestLogoUrl { logoLoader.load(url) }
        }
        .onReceive(logoLoader.$image) { image in
            guard let color = image?.brandColor else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                brandTint = Color(uiColor: color)
            }
        }
        .overlay { if isLoading && detail == nil { LoadingOverlay() } }
        .navigationDestination(isPresented: $navigateToCheck) {
            BaggageCheckView(preselected: display)
        }
        .navigationDestination(item: $selectedBagId) { bagId in
            BagDetailView(bagId: bagId)
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Achtergrondverloop in de merkkleur van de maatschappij, tot
            // helemaal boven de statusbalk door (geen kale naad meer).
            LinearGradient(
                colors: [accent.opacity(0.16), Color(.systemGroupedBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 200 + airlineDetailStatusBarHeight)

            VStack(spacing: 12) {
                // Logo als app-icoon-tegel: vierkante logo's (met eigen
                // achtergrondvlak, zoals TUI) krijgen ronde hoeken en vullen
                // de tegel netjes; brede wordmarks passen er ook gewoon in.
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .fill(Color(.systemBackground))
                        .frame(width: 96, height: 96)
                        .cardElevation()
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                        )

                    if display.bestLogoUrl != nil {
                        AuthorisedImage(urlString: display.bestLogoUrl)
                            .frame(width: 66, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    } else {
                        Text(display.name.prefix(2).uppercased())
                            .font(.frutiger(size: 26, weight: .bold))
                            .foregroundStyle(Theme.sky)
                    }
                }

                VStack(spacing: 4) {
                    Text(display.name)
                        .font(.frutiger(size: 24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    if let date = display.lastVerifiedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.green)
                            Text("Geverifieerd op \(formattedDate(date))")
                                .font(.frutiger(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.lg)
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
                        .font(.frutiger(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.base)
                .background(Theme.inkGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                // bewust eigen schaduw: primaire CTA-knop krijgt een navy-tinted
                // schaduw die de merkkleur oppikt, niet de standaard kaartschaduw
                .shadow(color: Theme.navy.opacity(0.30), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            if #available(iOS 26.0, *) {
                PakAdviesButton(airline: display)
            }

            if hasBaggageOverview {
                sectionHeader("De bagage van \(display.name) in één oogopslag")
                baggageOverviewRow
            }

            if let variants = display.variants, !variants.isEmpty {
                sectionHeader("Bagageregels")
                ForEach(variants) { variant in
                    VariantCard(variant: variant)
                }
            }

            if hasCheckedBagExtras {
                checkedBagExtrasSection
            }

            if let notes = display.extraNotes {
                sectionHeader("Extra informatie")
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Theme.sky)
                        .font(.system(size: 18))
                    Text(notes)
                        .font(.frutiger(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.base)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .cardElevation()
            }

            // Tassen die gegarandeerd passen: het logische koopmoment als je
            // je toch al in de regels van deze maatschappij verdiept.
            if !matchingBags.isEmpty {
                sectionHeader("Tassen & koffers die passen bij \(display.name)")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(matchingBags.prefix(6)) { bag in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                APIClient.shared.sendEvent("bag_open_airline_detail", path: "/airline/\(display.slug)")
                                selectedBagId = bag.id
                            } label: {
                                MatchingBagCard(bag: bag)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.base)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .padding(.horizontal, -Theme.Spacing.base)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    APIClient.shared.sendEvent("shop_cta_airline_detail", path: "/airline/\(display.slug)")
                    nav.openShop(airlineSlug: display.slug)
                } label: {
                    HStack(spacing: 6) {
                        Text("Bekijk alles wat past in de shop")
                            .font(.frutiger(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.navy.opacity(0.07))
                    .foregroundStyle(Theme.navy)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
            }

            if let sourceUrl = display.sourceUrl, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Bekijk officiële bagagepagina")
                            .font(.frutiger(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Theme.sky)
                    .padding(Theme.Spacing.md)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
            }
        }
        .pageEntrance()
    }

    // MARK: - Bagagesoorten in één oogopslag (zoals op vliegtuigtas.com)

    private var kleinItemDims: String? {
        dims(display.personalItemLCm, display.personalItemWCm, display.personalItemDCm)
    }

    /// De variant die het duidelijkst grote handbagage toont; anders de eerste beschikbare.
    private var grootHandbagageVariant: AirlineVariant? {
        display.variants?.first { $0.includesLargeBag == true } ?? display.variants?.first
    }

    private var ruimbagageDims: String? {
        dims(display.checkedBagMaxLCm, display.checkedBagMaxWCm, display.checkedBagMaxDCm)
    }

    private var hasBaggageOverview: Bool {
        kleinItemDims != nil || grootHandbagageVariant != nil || ruimbagageDims != nil || display.checkedBagMaxWeightKg != nil
    }

    private var baggageOverviewRow: some View {
        HStack(spacing: 10) {
            BaggageTypeCard(
                icon: "backpack.fill",
                color: Theme.sky,
                title: "Klein item",
                subtitle: "Aan boord meenemen",
                detail: kleinItemDims ?? grootHandbagageVariant?.smallDimString,
                priceLabel: "Meestal gratis"
            )
            BaggageTypeCard(
                icon: "bag.fill",
                color: Theme.green,
                title: "Grote handbagage",
                subtitle: "In het bagagevak boven je hoofd",
                detail: grootHandbagageVariant?.largeDimString,
                priceLabel: grootHandbagageVariant?.priceIndicationEur.map(euroLabel).map { "Vanaf \($0)" }
                    ?? "Afhankelijk van tarief"
            )
            BaggageTypeCard(
                icon: "suitcase.rolling.fill",
                color: Theme.orange,
                title: "Ruimbagage",
                subtitle: "Inchecken bij de balie",
                detail: ruimbagageDims,
                priceLabel: display.checkedBagPriceFromEur.map(euroLabel).map { "Vanaf \($0)" }
                    ?? (display.checkedBagIncluded == true ? "Vaak inbegrepen" : nil)
            )
        }
    }

    // MARK: - Ruimbagage & extra's

    private var hasCheckedBagExtras: Bool {
        display.checkedBagIncluded != nil
            || display.checkedBagPriceFromEur != nil
            || display.overweightFeePerKgEur != nil
            || display.oversizeFeeEur != nil
            || display.priorityBoardingPriceEur != nil
    }

    private var checkedBagExtrasSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Ruimbagage & extra's")
            VStack(spacing: 0) {
                if let included = display.checkedBagIncluded {
                    SpecRow(icon: "checkmark.seal", label: "Standaard inbegrepen",
                            value: included ? "Ja" : "Nee")
                    Divider()
                }
                if let weight = display.checkedBagMaxWeightKg {
                    SpecRow(icon: "scalemass", label: "Max. gewicht",
                            value: "\(Int(weight)) kg")
                    Divider()
                }
                if let price = display.checkedBagPriceFromEur.map(euroLabel) {
                    SpecRow(icon: "eurosign.circle", label: "Vanaf-prijs", value: price)
                    Divider()
                }
                if let fee = display.overweightFeePerKgEur.map(euroLabel) {
                    SpecRow(icon: "scalemass.fill", label: "Overgewicht", value: "\(fee) / kg")
                    Divider()
                }
                if let fee = display.oversizeFeeEur.map(euroLabel) {
                    SpecRow(icon: "arrow.up.left.and.arrow.down.right", label: "Te grote tas", value: fee)
                    Divider()
                }
                if let fee = display.priorityBoardingPriceEur.map(euroLabel) {
                    SpecRow(icon: "star.fill", label: "Priority boarding", value: fee)
                }
            }
            .padding(.horizontal, Theme.Spacing.base)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .cardElevation()
        }
    }

    private func dims(_ l: Double?, _ w: Double?, _ d: Double?) -> String? {
        guard let l, let w, let d else { return nil }
        return "\(Int(l)) × \(Int(w)) × \(Int(d)) cm"
    }

    private func euroLabel(_ value: Double) -> String {
        let symbol = (display.currency ?? "EUR") == "EUR" ? "€" : (display.currency ?? "") + " "
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(symbol)\(Int(value))"
            : String(format: "\(symbol)%.2f", value)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.frutiger(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.xs)
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateStyle = .medium
        return f
    }()

    private func formattedDate(_ raw: String) -> String {
        guard let date = Self.isoDateFormatter.date(from: raw) else { return raw }
        return Self.displayDateFormatter.string(from: date)
    }

    private func loadDetail() async {
        isLoading = true
        async let detailTask = APIClient.shared.airline(slug: airline.slug)
        async let bagsTask = APIClient.shared.bags(airline: airline.slug)
        detail = try? await detailTask
        matchingBags = (try? await bagsTask) ?? []
        isLoading = false
    }
}

// MARK: - Baggage type card ("in één oogopslag", zoals op vliegtuigtas.com)

private struct BaggageTypeCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let detail: String?
    let priceLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.frutiger(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.frutiger(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let detail {
                Text(detail)
                    .font(.frutiger(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer(minLength: 0)

            if let priceLabel {
                Text(priceLabel)
                    .font(.frutiger(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .cardElevation()
    }
}

// MARK: - Passende-tas kaart (carrousel op de detailpagina)

private struct MatchingBagCard: View {
    let bag: Bag

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color.white
                if bag.imageUrl != nil {
                    AuthorisedImage(urlString: bag.imageUrl)
                        .padding(Theme.Spacing.sm)
                } else {
                    Image(systemName: "bag")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Theme.navy.opacity(0.15))
                }
            }
            .frame(width: 128, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

            Text(bag.name)
                .font(.frutiger(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(height: 28, alignment: .top)

            HStack(spacing: 4) {
                if let price = bag.displayPrice {
                    Text(price)
                        .font(.frutiger(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.navy)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.green)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(width: 144)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .cardElevation()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

// MARK: - Spec row (Ruimbagage & extra's)

private struct SpecRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.navy)
                .frame(width: 20)
            Text(label)
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.frutiger(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.md)
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
                            .font(.frutiger(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if let large = variant.includesLargeBag {
                            Text(large ? "Incl. grote handbagage" : "Klein persoonlijk item")
                                .font(.frutiger(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    if let large = variant.includesLargeBag {
                        Image(systemName: large ? "bag.fill" : "bag")
                            .font(.system(size: 14))
                            .foregroundStyle(large ? Theme.green : Theme.orange)
                            .padding(Theme.Spacing.sm)
                            .background((large ? Theme.green : Theme.orange).opacity(0.1))
                            .clipShape(Circle())
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.Spacing.base)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, Theme.Spacing.base)

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
                                .font(.frutiger(size: 14))
                        }
                        .padding(.horizontal, Theme.Spacing.base)
                    }

                    if let notes = variant.notes {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Theme.yellow)
                                .font(.system(size: 14))
                            Text(notes)
                                .font(.frutiger(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, Theme.Spacing.base)
                    }
                }
                .padding(.vertical, Theme.Spacing.base)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .cardElevation()
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
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(dims)
                    .font(.frutiger(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if let w = weight {
                    Text("max. \(String(format: "%.0f", w)) kg")
                        .font(.frutiger(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.base)
        .padding(.vertical, Theme.Spacing.sm)
    }
}
