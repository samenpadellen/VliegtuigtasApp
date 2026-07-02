import SwiftUI

private var bagDetailStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct BagDetailView: View {
    let bagId: String

    @EnvironmentObject private var airlineStore: AirlineStore
    @State private var detail: BagDetail?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    // Airlines die de tas NIET accepteren
    private var notAccepted: [Airline] {
        guard let matched = detail?.matchedAirlines else { return airlineStore.airlines }
        let matchedIds = Set(matched.map(\.id))
        return airlineStore.airlines.filter { !matchedIds.contains($0.id) }
    }

    var body: some View {
        Group {
            if isLoading && detail == nil {
                loadingView
            } else if let d = detail {
                detailContent(d)
            } else {
                errorView
            }
        }
        .navigationBarHidden(true)
        .task { await load() }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack { ProgressView().tint(Theme.sky) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag.badge.questionmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.navy.opacity(0.30))
            Text("Tas niet gevonden")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Button("Terug") { dismiss() }
                .foregroundStyle(Theme.navy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Main content

    private func detailContent(_ d: BagDetail) -> some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroPhoto(d)

                    VStack(spacing: 22) {
                        // 1. Naam + prijs + CTA
                        productInfo(d)

                        // 2. Afmetingen (altijd direct na productinfo)
                        if d.dimensionsLabel != nil || d.length != nil || d.weight != nil || d.volumeLiters != nil || d.fitType != nil {
                            specsSection(d)
                        }

                        // 3. Kleuren
                        if let colors = d.colors, !colors.isEmpty {
                            colorsSection(colors)
                        }

                        // 4. Niet geaccepteerd (bovenaan airlines blok)
                        if !notAccepted.isEmpty {
                            airlineBlock(
                                title: "Niet geaccepteerd",
                                subtitle: "\(notAccepted.count) maatschappij\(notAccepted.count == 1 ? "" : "en") accepteren deze tas niet",
                                airlines: notAccepted,
                                style: .rejected
                            )
                        }

                        // 5. Geaccepteerd
                        if let matched = d.matchedAirlines, !matched.isEmpty {
                            airlineBlock(
                                title: "Geaccepteerd door",
                                subtitle: "\(matched.count) maatschappij\(matched.count == 1 ? "" : "en") accepteren deze tas",
                                airlines: matched,
                                style: .accepted
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    .pageEntrance()

                    if let similar = d.similarBags, !similar.isEmpty {
                        similarSection(similar)
                            .padding(.top, 12)
                            .pageEntrance(delay: 0.06)
                    }

                    Spacer(minLength: 48)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground))

            // Zwevende terugknop
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .glassChrome(in: Circle(), interactive: true, legacyFill: AnyShapeStyle(.black.opacity(0.28)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, bagDetailStatusBarHeight + 10)
        }
    }

    // MARK: - Hero photo

    private func heroPhoto(_ d: BagDetail) -> some View {
        ZStack(alignment: .bottom) {
            Color.white.frame(height: bagDetailStatusBarHeight + 340)

            if d.imageUrl != nil {
                AuthorisedImage(urlString: d.imageUrl, fill: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: bagDetailStatusBarHeight + 340)
                    .clipped()
            } else {
                Image(systemName: "bag.fill")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Theme.navy.opacity(0.10))
            }

            LinearGradient(
                colors: [Color(.systemGroupedBackground), .clear],
                startPoint: .bottom,
                endPoint: .init(x: 0.5, y: 0.72)
            )
        }
        .frame(height: bagDetailStatusBarHeight + 340)
        .clipped()
    }

    // MARK: - Product info + CTA

    private func productInfo(_ d: BagDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                if let brand = d.brand {
                    Text(brand.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy.opacity(0.45))
                        .kerning(1.2)
                }
                Text(d.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    if let label = d.displayPrice {
                        Text(label)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.navy)
                    }
                    if let domain = d.shopDomain {
                        HStack(spacing: 5) {
                            if d.shopLogoUrl != nil {
                                AuthorisedImage(urlString: d.shopLogoUrl)
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            Text(domain)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Spacer()

                if let url = d.affiliateUrl.flatMap(URL.init) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text("Bekijk aanbieding")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Theme.navyGradient)
                        .clipShape(Capsule())
                        .shadow(color: Theme.navy.opacity(0.28), radius: 10, x: 0, y: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Specs

    private func specsSection(_ d: BagDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Afmetingen & specificaties")

            HStack(spacing: 10) {
                if let label = d.dimensionsLabel ?? {
                    let p = [d.length, d.width, d.depth].compactMap { $0.map { "\(Int($0))" } }
                    return p.count == 3 ? p.joined(separator: "×") + " cm" : nil
                }() {
                    specPill(icon: "ruler", label: "Maten", value: label)
                }
                if let wt = d.weight {
                    specPill(icon: "scalemass", label: "Gewicht", value: String(format: "%.1f kg", wt))
                }
                if let vol = d.volumeLiters {
                    specPill(icon: "cube", label: "Inhoud", value: String(format: "%.1f L", vol))
                }
                if let fit = d.fitType {
                    specPill(icon: fit.icon, label: "Type", value: fit.label)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func specPill(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.navy.opacity(0.55))
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    // MARK: - Colors

    private func colorsSection(_ colors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Beschikbare kleuren")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { color in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(BagColorMap.color(for: color))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Color(.systemGray4), lineWidth: 0.8))
                            Text(color.capitalized)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color(.systemGray5), lineWidth: 1.2))
                    }
                }
                .padding(.leading, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Airline blokken

    private enum AirlineStyle { case accepted, rejected }

    private func airlineBlock(
        title: String,
        subtitle: String,
        airlines: [Airline],
        style: AirlineStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: style == .accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(style == .accepted ? Color.green : Color.red)
                    sectionHeader(title)
                }
                Text(subtitle)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 8) {
                ForEach(airlines) { ma in
                    NavigationLink(destination: AirlineDetailView(airline: ma)) {
                        HStack(spacing: 14) {
                            AirlineLogo(airline: ma, size: 42)
                            Text(ma.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if style == .rejected {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.60))
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary.opacity(0.4))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            style == .rejected
                                ? Color.red.opacity(0.04)
                                : Color(.systemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    style == .rejected ? Color.red.opacity(0.12) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Similar bags

    private func similarSection(_ bags: [Bag]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Vergelijkbare tassen")
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(bags) { bag in
                        NavigationLink(destination: BagDetailView(bagId: bag.id)) {
                            SimilarBagTile(bag: bag)
                        }
                        .buttonStyle(.pressableCard)
                        .carouselTransition()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
    }

    private func load() async {
        isLoading = true
        async let detailTask = APIClient.shared.bag(id: bagId)
        async let airlinesTask: () = airlineStore.load()
        detail = try? await detailTask
        await airlinesTask
        isLoading = false
    }
}

// MARK: - Similar bag tile

private struct SimilarBagTile: View {
    let bag: Bag

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.white
                if bag.imageUrl != nil {
                    AuthorisedImage(urlString: bag.imageUrl, fill: true)
                } else {
                    Image(systemName: "bag")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Theme.navy.opacity(0.12))
                }
            }
            .frame(width: 148, height: 148)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 14, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 14
            ))

            VStack(alignment: .leading, spacing: 4) {
                if let brand = bag.brand {
                    Text(brand.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy.opacity(0.45))
                        .kerning(0.5)
                }
                Text(bag.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let label = bag.displayPrice {
                    Text(label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy)
                        .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(width: 148, alignment: .leading)
        }
        .frame(width: 148)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
