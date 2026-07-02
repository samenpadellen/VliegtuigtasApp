import SwiftUI
import ImageIO

// MARK: - Card

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.navyGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.navy.opacity(0.30), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Native Liquid Glass

@available(iOS 26.0, *)
private func resolvedGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    /// Past Apple's eigen Liquid Glass-materiaal toe (`glassEffect`, iOS 26+) op
    /// zwevende bediening boven foto's/content — géén zelfgemaakte "glas-look"
    /// met handmatige opacity/blur, maar het echte systeem-gerenderde materiaal.
    /// Op oudere OS-versies valt dit netjes terug op het standaard systeemmateriaal
    /// dat hiervoor al gebruikt werd.
    @ViewBuilder
    func glassChrome<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        legacyFill: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial)
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(resolvedGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(legacyFill, in: shape)
        }
    }
}

// MARK: - Zoom-navigatie (iOS 18 hero-overgang) & scroll-transities

extension View {
    /// Markeert een kaart als bron voor de native zoom-navigatieovergang
    /// (iOS 18+): de detailpagina groeit vloeiend uit de kaart zelf, en zoomt
    /// bij teruggaan weer terug — het moderne systeemgedrag uit o.a. de App
    /// Store en Foto's. Op oudere versies gewoon de standaard push.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Tegenhanger van `zoomSource` voor de bestemmingspagina.
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }

    /// Subtiele scroll-transitie voor horizontale carrousels: kaarten die de
    /// schermrand naderen vervagen en krimpen licht mee met het scrollen —
    /// native `scrollTransition`-gedrag, geen eigen scroll-observatie.
    func carouselTransition() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.55)
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
        }
    }
}

// MARK: - Micro-animaties: tikbare kaarten en pagina-entrees

/// Consistente "druk-in"-microanimatie voor kaarten/rijen die naar een andere
/// pagina navigeren (NavigationLink, tab-wissel-knoppen). Geeft direct tactiele
/// feedback op het moment van tikken, in plaats van dat de tik "dood" aanvoelt
/// tot de volgende pagina verschijnt.
struct PressableCardStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

/// Zachte entree-animatie voor het belangrijkste blok op een nieuw geopende
/// pagina (detailschermen e.d.): een korte fade + opschuif zodra de content
/// klaar is, zodat "naar een andere pagina gaan" ook echt als een beweging
/// aanvoelt in plaats van een abrupte wissel.
struct PageEntranceModifier: ViewModifier {
    @State private var appeared = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func pageEntrance(delay: Double = 0) -> some View {
        modifier(PageEntranceModifier(delay: delay))
    }
}

// MARK: - Authenticated image loader

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private static let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 80 * 1024 * 1024 // ~80MB aan gedecodeerde pixels
        return cache
    }()

    private static let diskCacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VTImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func diskPath(for key: String) -> URL {
        let safeName = String(abs(key.hashValue))
        return diskCacheURL.appendingPathComponent(safeName)
    }

    /// Downsamplet naar een schermvriendelijke maximale afmeting vóór het
    /// decoderen naar een volledige bitmap. Productfoto's komen soms op
    /// meerdere MB's volle resolutie binnen; zonder downsampling decodeert
    /// elke kaart in een grid/scroll die volle bitmap, wat geheugen opblaast
    /// en scrollen minder soepel maakt. Dit gebeurt off-main (in de Task),
    /// dus blokkeert de UI niet.
    nonisolated private static func downsampled(_ data: Data, maxDimension: CGFloat = 900) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    private static func cost(of image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }

    func load(_ urlString: String) {
        let key = urlString as NSString

        if let cached = Self.memoryCache.object(forKey: key) {
            image = cached; return
        }

        let diskURL = Self.diskPath(for: urlString)
        if let data = try? Data(contentsOf: diskURL), let cachedImg = Self.downsampled(data) {
            Self.memoryCache.setObject(cachedImg, forKey: key, cost: Self.cost(of: cachedImg))
            image = cachedImg
            return
        }

        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer lFkEQW18oyMrdMsbfNK1DtnDnoCcqwNSBRfMCXmszUgbAoLf",
                     forHTTPHeaderField: "Authorization")
        Task {
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let img = Self.downsampled(data) else { return }
            Self.memoryCache.setObject(img, forKey: key, cost: Self.cost(of: img))
            try? data.write(to: diskURL)
            image = img
        }
    }
}

struct AuthorisedImage: View {
    let urlString: String?
    var fill: Bool = false
    @StateObject private var loader = ImageLoader()

    var body: some View {
        ZStack {
            if let img = loader.image {
                Group {
                    if fill {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(uiImage: img).resizable().scaledToFit()
                    }
                }
                // Zachte fade zodra een foto binnenkomt, in plaats van een harde
                // "pop" op het scherm — subtiele microanimatie die overal geldt
                // waar deze component gebruikt wordt.
                .transition(.opacity.animation(.easeOut(duration: 0.25)))
            } else {
                Color.clear
            }
        }
        .task(id: urlString) {
            if let s = urlString { loader.load(s) }
        }
    }
}

// MARK: - Airline logo

struct AirlineLogo: View {
    let airline: Airline
    let size: CGFloat

    var body: some View {
        Group {
            if airline.bestLogoUrl != nil {
                AuthorisedImage(urlString: airline.bestLogoUrl)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size * 0.6)
        .overlay(alignment: .bottomTrailing) {
            if let emoji = airline.flagEmoji {
                Text(emoji)
                    .font(.system(size: max(size * 0.28, 10)))
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .offset(x: size * 0.06, y: size * 0.04)
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Theme.skyLight)
            Text(airline.name.prefix(2).uppercased())
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.sky)
        }
    }
}

// MARK: - Bag color mapping

/// Vertaalt een kleurnaam uit de productdata (NL of EN) naar een weergavekleur
/// voor kleine kleur-swatches, zoals de uitvoeringskeuze in Apple's productpagina's.
enum BagColorMap {
    private static let table: [String: Color] = [
        "zwart": .black, "black": .black,
        "wit": .white, "white": .white,
        "grijs": Color(.systemGray), "grey": Color(.systemGray), "gray": Color(.systemGray),
        "antraciet": Color(.systemGray2), "charcoal": Color(.systemGray2),
        "blauw": .blue, "blue": .blue,
        "navy": Theme.navy, "marineblauw": Theme.navy, "donkerblauw": Theme.navy,
        "lichtblauw": Theme.sky, "sky": Theme.sky,
        "rood": .red, "red": .red, "bordeaux": Color(red: 0.45, green: 0.09, blue: 0.13),
        "groen": .green, "green": .green, "olijf": Color(red: 0.42, green: 0.45, blue: 0.24),
        "geel": Theme.yellow, "yellow": Theme.yellow,
        "oranje": Theme.orange, "orange": Theme.orange,
        "bruin": .brown, "brown": .brown, "cognac": Color(red: 0.63, green: 0.35, blue: 0.15),
        "beige": Color(red: 0.90, green: 0.82, blue: 0.68), "camel": Color(red: 0.76, green: 0.60, blue: 0.42),
        "roze": .pink, "pink": .pink,
        "paars": .purple, "purple": .purple,
        "goud": Color(red: 0.83, green: 0.69, blue: 0.22), "gold": Color(red: 0.83, green: 0.69, blue: 0.22),
        "zilver": Color(.systemGray3), "silver": Color(.systemGray3),
    ]

    static func color(for name: String) -> Color {
        table[name.lowercased()] ?? Theme.textSecondary.opacity(0.4)
    }
}

// MARK: - Verdict badge

struct VerdictBadge: View {
    let verdict: Verdict
    let message: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
            if let msg = message {
                Text(msg).font(.body1).multilineTextAlignment(.leading)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.verdictColor(verdict))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var iconName: String {
        switch verdict {
        case .ok:      return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail:    return "xmark.circle.fill"
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline2)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Number stepper field

struct MeasurementField: View {
    let label: String
    let unit: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption1).foregroundStyle(Theme.textSecondary)
            HStack {
                Button { value = max(range.lowerBound, value - step) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2).foregroundStyle(Theme.sky)
                }
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Button { value = min(range.upperBound, value + step) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2).foregroundStyle(Theme.sky)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Loading spinner overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.5)
        }
    }
}
