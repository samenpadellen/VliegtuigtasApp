import SwiftUI

private var bagDetailStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

/// Seconden tussen het automatisch doorbladeren van de foto-carrousel.
private let autoScrollInterval: Double = 4

struct BagDetailView: View {
    let bagId: String

    @EnvironmentObject private var airlineStore: AirlineStore
    @ObservedObject private var flightsStore = FlightsStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detail: BagDetail?
    @State private var isLoading = true
    @State private var selectedImage = 0
    // Volledige productgallerij (foto's groot bekijken + eventuele video).
    @State private var showGallery = false
    @State private var galleryStartIndex = 0
    // Beide airline-lijsten starten ingeklapt: de detailpagina blijft rustig
    // en de gebruiker vouwt open wat hij wil zien.
    @State private var acceptedExpanded = false
    @State private var rejectedExpanded = false
    @Environment(\.dismiss) private var dismiss

    // Airlines die de tas NIET accepteren
    private var notAccepted: [Airline] {
        guard let matched = detail?.matchedAirlines else { return airlineStore.airlines }
        let matchedIds = Set(matched.map(\.id))
        return airlineStore.airlines.filter { !matchedIds.contains($0.id) }
    }

    /// Slugs van maatschappijen die de gebruiker al kent uit zijn opgeslagen
    /// vluchten — daar stemmen we de detailpagina op af.
    private var knownAirlineSlugs: Set<String> {
        Set(flightsStore.flights.compactMap(\.airlineSlug))
    }

    /// De bekende maatschappij(en) van de gebruiker die deze tas accepteren.
    /// Die zetten we bovenaan met een vinkje + koop-CTA — precies de tassen
    /// die relevant zijn voor de vlucht die de gebruiker al heeft ingepland.
    private func knownAccepted(_ d: BagDetail) -> [Airline] {
        guard !knownAirlineSlugs.isEmpty else { return [] }
        return (d.matchedAirlines ?? []).filter { knownAirlineSlugs.contains($0.slug) }
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
                .font(.frutiger(size: 17, weight: .semibold))
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

                        // 4. Bekende maatschappij van de gebruiker die deze
                        //    tas accepteert — prominent met vinkje + koop-CTA.
                        let known = knownAccepted(d)
                        if !known.isEmpty {
                            knownAirlineHighlight(known, bag: d)
                        }

                        // 5. Geaccepteerd (ingeklapt)
                        if let matched = d.matchedAirlines, !matched.isEmpty {
                            collapsibleAirlineBlock(
                                title: "Geaccepteerd bij deze airlines",
                                subtitle: "\(matched.count) maatschappij\(matched.count == 1 ? "" : "en") accepteren deze tas",
                                airlines: matched,
                                style: .accepted,
                                isExpanded: $acceptedExpanded
                            )
                        }

                        // 6. Niet geaccepteerd (ingeklapt, onderaan)
                        if !notAccepted.isEmpty {
                            collapsibleAirlineBlock(
                                title: "Niet geaccepteerd bij deze airlines",
                                subtitle: "\(notAccepted.count) maatschappij\(notAccepted.count == 1 ? "" : "en") accepteren deze tas niet",
                                airlines: notAccepted,
                                style: .rejected,
                                isExpanded: $rejectedExpanded
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
                FloatingBackButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, bagDetailStatusBarHeight + 10)
        }
    }

    // MARK: - Hero photo

    private func heroPhoto(_ d: BagDetail) -> some View {
        let images = d.galleryImageUrls
        let heroHeight = bagDetailStatusBarHeight + 340
        let hasVideo = d.localVideoURL != nil

        return ZStack(alignment: .bottom) {
            Color.white.frame(height: heroHeight)

            if images.isEmpty && !hasVideo {
                Image(systemName: "bag.fill")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Theme.navy.opacity(0.10))
            } else if images.count == 1 {
                AuthorisedImage(urlString: images[0], fill: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight)
                    .clipped()
            } else if images.count > 1 {
                // Meerdere shop-afbeeldingen: horizontaal veegbaar. Eigen
                // stippen (hieronder) i.p.v. de systeem-index, zodat ze niet
                // wegvallen achter het onderste verloop.
                TabView(selection: $selectedImage) {
                    ForEach(Array(images.enumerated()), id: \.offset) { idx, url in
                        AuthorisedImage(urlString: url, fill: true)
                            .frame(maxWidth: .infinity)
                            .frame(height: heroHeight)
                            .clipped()
                            .tag(idx)
                    }
                }
                .frame(height: heroHeight)
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            LinearGradient(
                colors: [Color(.systemGroupedBackground), .clear],
                startPoint: .bottom,
                endPoint: .init(x: 0.5, y: 0.72)
            )
            .allowsHitTesting(false)

            if images.count > 1 {
                pageDots(count: images.count)
                    .padding(.bottom, 74)
            }
        }
        .frame(height: heroHeight)
        .clipped()
        // Tik op de foto → volledige gallerij, op de huidige foto.
        .contentShape(Rectangle())
        .onTapGesture { openGallery(imageIndex: selectedImage, hasVideo: hasVideo) }
        // "Bekijk productgallerij" + eventueel een video-play-knop, zodat
        // duidelijk is dat je de foto's groot kunt bekijken.
        .overlay(alignment: .topTrailing) {
            if !images.isEmpty || hasVideo {
                galleryButton(imageCount: images.count, hasVideo: hasVideo)
                    .padding(.top, bagDetailStatusBarHeight + 10)
                    .padding(.trailing, 20)
            }
        }
        .overlay {
            if hasVideo {
                Button {
                    openGallery(imageIndex: 0, hasVideo: hasVideo, startAtVideo: true)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Video afspelen")
            }
        }
        // Automatisch doorbladeren: de task herstart bij élke wijziging van
        // selectedImage — dus ook na een handmatige veeg begint de teller
        // opnieuw, zodat een foto na interactie niet meteen doorspringt.
        // Respecteert "Verminder beweging": dan bladert er niets vanzelf.
        .task(id: selectedImage) {
            guard images.count > 1, !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(autoScrollInterval))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                selectedImage = (selectedImage + 1) % images.count
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            ProductGalleryView(
                imageUrls: images,
                videoURL: d.localVideoURL,
                title: d.name,
                selection: galleryStartIndex
            )
        }
    }

    /// Compacte "Bekijk productgallerij"-knop rechtsboven op de foto.
    private func galleryButton(imageCount: Int, hasVideo: Bool) -> some View {
        Button {
            openGallery(imageIndex: selectedImage, hasVideo: hasVideo)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: hasVideo ? "play.rectangle.fill" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                Text(hasVideo ? "Bekijk video & foto's" : "Bekijk foto's")
                    .font(.frutiger(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bekijk productgallerij")
    }

    /// Opent de gallerij op de juiste pagina (video staat vooraan als die er is).
    private func openGallery(imageIndex: Int, hasVideo: Bool, startAtVideo: Bool = false) {
        if startAtVideo {
            galleryStartIndex = 0
        } else {
            galleryStartIndex = (hasVideo ? 1 : 0) + imageIndex
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showGallery = true
    }

    /// Stip-indicator voor de foto-carrousel — actieve stip breder in navy,
    /// de rest gedempt. Tikbaar om direct naar een foto te springen.
    private func pageDots(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == selectedImage ? Theme.navy : Theme.navy.opacity(0.22))
                    .frame(width: i == selectedImage ? 18 : 6, height: 6)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedImage = i
                        }
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedImage)
    }

    // MARK: - Product info + CTA

    private func productInfo(_ d: BagDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                if let brand = d.brand {
                    Text(brand.uppercased())
                        .font(.frutiger(size: 11, weight: .bold))
                        .foregroundStyle(Theme.navy.opacity(0.45))
                        .kerning(1.2)
                }
                Text(d.name)
                    .font(.frutiger(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    if let label = d.displayPrice {
                        Text(label)
                            .font(.frutiger(size: 32, weight: .black))
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
                                .font(.frutiger(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Spacer()

                if let url = d.affiliateUrl.flatMap(URL.init) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text("Bekijk aanbieding")
                                .font(.frutiger(size: 14, weight: .bold))
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
                    .font(.frutiger(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(value)
                .font(.frutiger(size: 12, weight: .semibold))
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
                                .font(.frutiger(size: 12, weight: .medium))
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

    // MARK: - Bekende maatschappij van de gebruiker (vinkje + koop-CTA)

    /// Toont de maatschappij die de gebruiker al kent (uit een opgeslagen
    /// vlucht) en die deze tas accepteert — met een groen vinkje en een
    /// directe koop-CTA, want dit is precies de tas die bij zijn vlucht past.
    private func knownAirlineHighlight(_ airlines: [Airline], bag d: BagDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.green)
                sectionHeader("Past bij jouw vlucht")
            }

            ForEach(airlines) { ma in
                VStack(spacing: 12) {
                    NavigationLink(destination: AirlineDetailView(airline: ma)) {
                        HStack(spacing: 14) {
                            AirlineLogo(airline: ma, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ma.name)
                                    .font(.frutiger(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Label("Deze tas is toegestaan", systemImage: "checkmark.circle.fill")
                                    .font(.frutiger(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.green)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary.opacity(0.4))
                        }
                    }
                    .buttonStyle(.pressableCard)

                    if let url = d.affiliateUrl.flatMap(URL.init) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Koop deze tas")
                                    .font(.frutiger(size: 14, weight: .bold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Theme.navyGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Theme.navy.opacity(0.25), radius: 8, x: 0, y: 3)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            APIClient.shared.sendEvent("bag_buy_known_airline", path: "/bag/\(d.id)")
                        })
                    }
                }
                .padding(14)
                .background(Theme.green.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.green.opacity(0.25), lineWidth: 1.2)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Airline blokken (inklapbaar)

    private enum AirlineStyle { case accepted, rejected }

    /// Inklapbaar blok: standaard alleen een kop met aantal + chevron; tikken
    /// vouwt de volledige lijst uit. Houdt de detailpagina compact.
    private func collapsibleAirlineBlock(
        title: String,
        subtitle: String,
        airlines: [Airline],
        style: AirlineStyle,
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: style == .accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(style == .accepted ? Color.green : Color.red)
                    VStack(alignment: .leading, spacing: 2) {
                        sectionHeader(title)
                        Text(subtitle)
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
                .padding(14)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(spacing: 8) {
                    ForEach(airlines) { ma in
                        NavigationLink(destination: AirlineDetailView(airline: ma)) {
                            HStack(spacing: 14) {
                                AirlineLogo(airline: ma, size: 42)
                                Text(ma.name)
                                    .font(.frutiger(size: 15, weight: .semibold))
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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
            .font(.frutiger(size: 18, weight: .bold))
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
                        .font(.frutiger(size: 9, weight: .bold))
                        .foregroundStyle(Theme.navy.opacity(0.45))
                        .kerning(0.5)
                }
                Text(bag.name)
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let label = bag.displayPrice {
                    Text(label)
                        .font(.frutiger(size: 14, weight: .bold))
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
