import SwiftUI
import ImageIO
import Vision
import CoreImage

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
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.yellow)
                }
                Text(title).font(.frutiger(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.inkGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.ink.opacity(0.35), radius: 10, x: 0, y: 4)
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

/// Alleen op iPhone: iPadOS heeft bekende hit-testing-problemen met
/// matchedTransitionSource in (horizontale) ScrollViews — kaarten reageren
/// dan niet of pas na meerdere tikken. Dit was de oorzaak van de
/// App Review-rejectie "buttons unresponsive" op iPad. Op iPad vallen we
/// terug op de standaard push; functioneel identiek, alleen zonder de
/// zoom-animatie.
private let zoomTransitionsSupported = UIDevice.current.userInterfaceIdiom == .phone

extension View {
    /// Markeert een kaart als bron voor de native zoom-navigatieovergang
    /// (iOS 18+, alleen iPhone): de detailpagina groeit vloeiend uit de kaart
    /// zelf, en zoomt bij teruggaan weer terug. Elders de standaard push.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *), zoomTransitionsSupported {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Tegenhanger van `zoomSource` voor de bestemmingspagina.
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *), zoomTransitionsSupported {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }

    /// Subtiele scroll-transitie voor horizontale carrousels: kaarten die de
    /// schermrand naderen vervagen en krimpen licht mee met het scrollen —
    /// native `scrollTransition`-gedrag. Alleen op iPhone, om elke interactie
    /// met pointer-hit-testing op iPad uit te sluiten.
    @ViewBuilder
    func carouselTransition() -> some View {
        if zoomTransitionsSupported {
            scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.55)
                    .scaleEffect(phase.isIdentity ? 1 : 0.94)
            }
        } else {
            self
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

    nonisolated private static let diskCacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VTImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Stabiele bestandsnaam per URL (FNV-1a). `hashValue` kan hier niet
    /// gebruikt worden: Swift randomiseert de hash-seed per proces, dus
    /// dezelfde foto kreeg bij elke app-start een andere naam. Gevolg: de
    /// schijfcache sloeg nooit aan ná een herstart, de map liep vol met
    /// duplicaten, en bij een botsing kon de foto van een ándere URL worden
    /// teruggegeven.
    nonisolated private static func diskPath(for key: String) -> URL {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return diskCacheURL.appendingPathComponent(String(hash, radix: 16))
    }

    /// Alleen "vliegtuigtas.com" (en subdomeinen) telt als onze eigen API —
    /// productfoto's wijzen vaak naar externe CDN's (bol.com, Shopify, …)
    /// die geen bearer-token horen te krijgen.
    nonisolated private static func isOwnAPIHost(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host == "vliegtuigtas.com" || host.hasSuffix(".vliegtuigtas.com")
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
        return leveled(UIImage(cgImage: cgImage))
    }

    /// Corrigeert een scheve horizon automatisch, zoals Foto's "Rechtzetten".
    /// Reisfoto's komen hier ongecureerd binnen (Unsplash/Pexels-zoekresultaat
    /// op bestemmingsnaam) — een scheve architectuurfoto die in de volle
    /// afbeelding een bewuste dutch angle is, oogt in een klein, uitgesneden
    /// kaartje al snel als "geladen onder een verkeerde hoek". Vision's
    /// horizondetectie draait 'm recht vóórdat 'm ooit getoond wordt.
    ///
    /// Bewust terughoudend: bij een kleine hoek (al recht) of een grote hoek
    /// (Vision heeft waarschijnlijk geen echte horizon gevonden, bijv. een
    /// close-up zonder lucht) blijft de foto ongewijzigd — beter een
    /// onaangeroerde foto dan een verkeerd "gecorrigeerde".
    nonisolated private static func leveled(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let request = VNDetectHorizonRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first as? VNHorizonObservation,
              abs(observation.angle) > (0.5 * .pi / 180),
              abs(observation.angle) < (20 * .pi / 180)
        else { return image }

        let angle = observation.angle
        let ciImage = CIImage(cgImage: cgImage)
        let rotated = ciImage.transformed(by: CGAffineTransform(rotationAngle: angle))

        // Roteren legt de hoeken van het beeld bloot (transparant) — hier
        // terugsnijden naar een rechthoek die met zekerheid volledig binnen
        // het geroteerde beeld valt. `k` is de wiskundige grens voor een
        // vierkant dat om zijn midden roteert; de 0.85 is extra marge omdat
        // een niet-vierkante foto (zoals de meeste hier) net iets minder
        // ruimte overhoudt dan een vierkant bij dezelfde hoek — leeg-geverifieerd
        // tot de maximale hoek hierboven (20°) op een 900×630-formaat.
        let k = 1 / (cos(abs(angle)) + sin(abs(angle))) * 0.85
        let cropWidth = ciImage.extent.width * k
        let cropHeight = ciImage.extent.height * k
        let cropRect = CGRect(
            x: rotated.extent.midX - cropWidth / 2,
            y: rotated.extent.midY - cropHeight / 2,
            width: cropWidth, height: cropHeight
        )
        let cropped = rotated.cropped(to: cropRect)

        let context = CIContext()
        guard let leveledCG = context.createCGImage(cropped, from: cropped.extent) else { return image }
        return UIImage(cgImage: leveledCG, scale: image.scale, orientation: .up)
    }

    private static func cost(of image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }

    /// Gelijktijdige aanvragen voor dezelfde URL delen één download —
    /// hetzelfde productlogo in carrousel én grid werd voorheen dubbel gehaald.
    @MainActor
    private static var inFlight: [String: Task<UIImage?, Never>] = [:]

    func load(_ urlString: String) {
        let key = urlString as NSString

        // Geheugencache: synchroon, geen flikker.
        if let cached = Self.memoryCache.object(forKey: key) {
            image = cached; return
        }

        // Disk en netwerk volledig off-main: het synchroon lezen +
        // downsamplen van schijf in scrollende grids gaf haperingen.
        Task { @MainActor [weak self] in
            if let img = await Self.fetch(urlString) {
                self?.image = img
            }
        }
    }

    @MainActor
    private static func fetch(_ urlString: String) async -> UIImage? {
        if let existing = inFlight[urlString] {
            return await existing.value
        }

        let task = Task<UIImage?, Never>.detached(priority: .userInitiated) {
            let diskURL = diskPath(for: urlString)
            if let data = try? Data(contentsOf: diskURL), let img = downsampled(data) {
                return img
            }
            guard let url = URL(string: urlString) else { return nil }
            var req = URLRequest(url: url)
            // Alleen ons eigen bearer-token meesturen naar onze eigen API —
            // productfoto's komen vaak van externe CDN's (bol.com, Shopify).
            // media.s-bol.com bleek een onverwachte Authorization-header af
            // te straffen met 401, waardoor precies de tassen met een
            // bol.com-foto nooit laadden ("de helft wel, de helft niet").
            // Het token hoort daar sowieso niet te lekken.
            if isOwnAPIHost(url) {
                req.setValue("Bearer \(APIClient.shared.publicClientKey)",
                             forHTTPHeaderField: "Authorization")
            }
            // Eén nieuwe poging bij een transiënte hapering (timeout, 5xx),
            // zodat een kortstondig netwerkblip een foto niet voorgoed leeg
            // laat — deze view herlaadt zichzelf niet vanzelf.
            for attempt in 0..<2 {
                if attempt > 0 { try? await Task.sleep(nanoseconds: 400_000_000) }
                guard let (data, resp) = try? await URLSession.shared.data(for: req) else { continue }
                guard let http = resp as? HTTPURLResponse else { continue }
                if http.statusCode == 200, let img = downsampled(data) {
                    try? data.write(to: diskURL)
                    return img
                }
                if (400..<500).contains(http.statusCode) { break } // geen zin te herhalen
            }
            return nil
        }

        inFlight[urlString] = task
        let image = await task.value
        inFlight[urlString] = nil

        if let image {
            memoryCache.setObject(image, forKey: urlString as NSString, cost: cost(of: image))
        }
        return image
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
                        // Fill-modus loopt buiten zijn kader (het kader clipt
                        // alleen visueel) — nooit hit-testbaar laten zijn,
                        // anders steelt de overloop tikken van views eromheen.
                        Image(uiImage: img).resizable().scaledToFill()
                            .allowsHitTesting(false)
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

// MARK: - Zwevende terugknop

/// Eén consistente terugknop voor alle detailpagina's: navy-getint glas met
/// witte chevron — altijd zichtbaar, óók op witte productfoto's en lichte
/// hero's. Minimaal 44×44pt raakvlak (Apple's richtlijn), met ruime
/// contentShape zodat een tik ernaast ook gewoon raak is.
struct FloatingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .glassChrome(in: Circle(), tint: Theme.ink, interactive: true,
                             legacyFill: AnyShapeStyle(Theme.ink.opacity(0.85)))
                .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 2)
                .contentShape(Circle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ga terug")
    }
}

// MARK: - Merkkleur uit een logo

extension UIImage {
    /// Gemiddelde merkkleur van een logo: negeert transparante en bijna-witte
    /// pixels (het achtergrondvlak), zodat de dominante logokleur overblijft.
    /// Bewust goedkoop (24×24 sample) — dit draait op de detailpagina.
    var brandColor: UIColor? {
        guard let cg = cgImage else { return nil }
        let side = 24
        var data = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &data, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        var r = 0.0, g = 0.0, b = 0.0, count = 0.0
        for i in stride(from: 0, to: data.count, by: 4) {
            guard data[i + 3] > 128 else { continue }                    // transparant
            let red = Double(data[i]), green = Double(data[i + 1]), blue = Double(data[i + 2])
            if red > 232, green > 232, blue > 232 { continue }           // witvlak
            r += red; g += green; b += blue; count += 1
        }
        guard count > 20 else { return nil }                             // te weinig signaal
        return UIColor(red: r / count / 255, green: g / count / 255,
                       blue: b / count / 255, alpha: 1)
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
        // Bewust geen landvlag-overlay meer: die gaf visuele ruis op elk logo.
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Theme.skyLight)
            Text(airline.name.prefix(2).uppercased())
                .font(.frutiger(size: size * 0.25, weight: .bold))
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

// MARK: - Seizoensfoto's

/// Kiest de hero-foto op basis van het seizoen: in december zie je sneeuw, in
/// juli palmen. Zo voelt de app mee met het moment waarop je hem opent, zonder
/// dat er ook maar iets ingesteld hoeft te worden.
///
/// Ontbreekt een seizoensfoto in de assets, dan valt hij terug op de bestaande
/// hero. Dat is geen luxe: `Image("naam")` met een onbekende naam rendert als
/// een leeg vlak, en dan zou het belangrijkste beeld van de app zomaar
/// verdwijnen op 1 december.
enum SeasonalPhoto {
    /// De foto die altijd bestaat, en waar we op terugvallen.
    static let fallback = "PhotoWindowWing"

    enum Season: String, CaseIterable {
        case winter, lente, zomer, herfst

        /// Meteorologische seizoenen op het noordelijk halfrond — dat sluit aan
        /// bij wanneer Nederlanders wintersport of zomervakantie boeken.
        static func current(_ date: Date = .now) -> Season {
            switch Calendar.current.component(.month, from: date) {
            case 12, 1, 2: return .winter
            case 3, 4, 5:  return .lente
            case 6, 7, 8:  return .zomer
            default:       return .herfst
            }
        }

        var assetName: String {
            switch self {
            case .winter: return "PhotoSeasonWinter"
            case .lente:  return "PhotoSeasonSpring"
            case .zomer:  return "PhotoSeasonSummer"
            case .herfst: return "PhotoSeasonAutumn"
            }
        }
    }

    /// Naam van de hero-foto voor nu, of de terugval als die er niet is.
    static var heroAssetName: String {
        let preferred = Season.current().assetName
        return UIImage(named: preferred) != nil ? preferred : fallback
    }
}

/// Hero-afbeelding die met het seizoen meebeweegt. Gebruikt overal dezelfde
/// keuze, zodat Start en Check hetzelfde beeld tonen.
struct SeasonalHeroImage: View {
    var body: some View {
        Image(SeasonalPhoto.heroAssetName)
            .resizable()
            .scaledToFill()
    }
}

/// Foto van luchthavenbewegwijzering als kop boven het luchthavenscherm.
/// Verschijnt alleen als de afbeelding daadwerkelijk in de assets zit — zo
/// staat er nooit een leeg vlak boven de lijst.
struct SignageHeader: View {
    var height: CGFloat = 130

    var body: some View {
        if UIImage(named: "PhotoAirportSigns") != nil {
            Image("PhotoAirportSigns")
                .resizable()
                .scaledToFill()
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, Color(.systemGroupedBackground)],
                        startPoint: .center, endPoint: .bottom
                    )
                    .frame(height: height * 0.5)
                }
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Luchthaven-illustratie

/// Vlakke illustratie van een vliegtuig op het platform, met verkeerstoren.
/// Volledig in SwiftUI getekend in plaats van als afbeelding: zo schaalt hij
/// scherp mee op elk formaat, weegt hij niets in de app-bundel, en kunnen de
/// kleuren meebewegen met licht/donker.
///
/// Bedoeld voor lege staten — daar waar nog niets te tonen valt en een kale
/// tekstregel het scherm doods maakt.
struct AirportScene: View {
    var height: CGFloat = 150

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let groundY = h * 0.70
            // Middellijn van het toestel; iets rechts van het midden zodat de
            // toren links ademruimte houdt.
            let cx = w * 0.56

            ZStack(alignment: .topLeading) {
                sky
                ground(w: w, h: h, groundY: groundY)
                tower(w: w, h: h, groundY: groundY)
                plane(w: w, h: h, groundY: groundY, cx: cx)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityHidden(true)
    }

    // MARK: Kleuren — oplopend in verzadiging, zoals in een vlakke illustratie

    private var skyTint: Color { Theme.sky.opacity(0.14) }
    private var apronTint: Color { Theme.sky.opacity(0.22) }
    private var stripTint: Color { Theme.sky.opacity(0.34) }
    private var towerTint: Color { Theme.sky.opacity(0.28) }
    private var planeTint: Color { Theme.sky.opacity(0.85) }
    private var planeDark: Color { Theme.navy.opacity(0.55) }

    // MARK: Onderdelen

    private var sky: some View {
        Rectangle().fill(skyTint)
    }

    private func ground(w: CGFloat, h: CGFloat, groundY: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(apronTint)
                .frame(width: w, height: h - groundY)
                .offset(y: groundY)
            Rectangle()
                .fill(stripTint)
                .frame(width: w, height: max(h * 0.10, 6))
                .offset(y: h - max(h * 0.10, 6))
        }
    }

    /// Verkeerstoren: smalle schacht met een breder uitlopend hoofd.
    private func tower(w: CGFloat, h: CGFloat, groundY: CGFloat) -> some View {
        let towerX = w * 0.13
        let headW = w * 0.055
        let shaftW = w * 0.022
        let headTop = h * 0.14
        let headH = h * 0.17
        return ZStack(alignment: .topLeading) {
            // Schacht
            Rectangle()
                .fill(towerTint)
                .frame(width: shaftW, height: groundY - (headTop + headH) + 2)
                .offset(x: towerX - shaftW / 2, y: headTop + headH - 2)
            // Hoofd: naar boven verbredend
            Path { p in
                let left = towerX - headW / 2
                let right = towerX + headW / 2
                p.move(to: CGPoint(x: left + headW * 0.18, y: headTop))
                p.addLine(to: CGPoint(x: right - headW * 0.18, y: headTop))
                p.addLine(to: CGPoint(x: right, y: headTop + headH * 0.55))
                p.addLine(to: CGPoint(x: right - headW * 0.28, y: headTop + headH))
                p.addLine(to: CGPoint(x: left + headW * 0.28, y: headTop + headH))
                p.addLine(to: CGPoint(x: left, y: headTop + headH * 0.55))
                p.closeSubpath()
            }
            .fill(towerTint)
        }
    }

    /// Vliegtuig van voren: romp als cirkel, doorlopende vleugels, staartvin,
    /// twee motoren en het landingsgestel.
    private func plane(w: CGFloat, h: CGFloat, groundY: CGFloat, cx: CGFloat) -> some View {
        let bodyR = h * 0.13
        let bodyCY = groundY - h * 0.20
        let wingSpan = w * 0.72
        let wingY = bodyCY + bodyR * 0.15

        return ZStack(alignment: .topLeading) {
            // Staartvin
            Path { p in
                p.move(to: CGPoint(x: cx, y: bodyCY - bodyR * 3.1))
                p.addLine(to: CGPoint(x: cx + bodyR * 0.20, y: bodyCY - bodyR * 0.6))
                p.addLine(to: CGPoint(x: cx - bodyR * 0.20, y: bodyCY - bodyR * 0.6))
                p.closeSubpath()
            }
            .fill(planeTint)

            // Hoogteroeren
            Capsule()
                .fill(planeTint)
                .frame(width: w * 0.26, height: max(h * 0.018, 2))
                .offset(x: cx - w * 0.13, y: bodyCY - bodyR * 1.05)

            // Hoofdvleugels: van de romp naar buiten aflopend
            Path { p in
                p.move(to: CGPoint(x: cx - bodyR * 0.9, y: wingY))
                p.addLine(to: CGPoint(x: cx - wingSpan / 2, y: wingY + h * 0.045))
                p.addLine(to: CGPoint(x: cx - wingSpan / 2, y: wingY + h * 0.075))
                p.addLine(to: CGPoint(x: cx - bodyR * 0.9, y: wingY + h * 0.085))
                p.closeSubpath()
            }
            .fill(planeTint)
            Path { p in
                p.move(to: CGPoint(x: cx + bodyR * 0.9, y: wingY))
                p.addLine(to: CGPoint(x: cx + wingSpan / 2, y: wingY + h * 0.045))
                p.addLine(to: CGPoint(x: cx + wingSpan / 2, y: wingY + h * 0.075))
                p.addLine(to: CGPoint(x: cx + bodyR * 0.9, y: wingY + h * 0.085))
                p.closeSubpath()
            }
            .fill(planeTint)

            // Motoren
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(planeDark)
                    .frame(width: bodyR * 0.85, height: bodyR * 0.72)
                    .offset(x: cx + CGFloat(side) * bodyR * 1.75 - bodyR * 0.42,
                            y: wingY + h * 0.055)
            }

            // Landingsgestel: neuswiel en twee hoofdstellen
            ForEach([-1.0, 0.0, 1.0], id: \.self) { side in
                let legX = cx + CGFloat(side) * bodyR * 1.15
                let legTop = bodyCY + bodyR * 0.75
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(planeDark)
                        .frame(width: max(bodyR * 0.10, 1.5), height: groundY - legTop - bodyR * 0.22)
                        .offset(x: legX - bodyR * 0.05, y: legTop)
                    Capsule()
                        .fill(planeDark)
                        .frame(width: bodyR * 0.34, height: bodyR * 0.22)
                        .offset(x: legX - bodyR * 0.17, y: groundY - bodyR * 0.22)
                }
            }

            // Romp
            Circle()
                .fill(planeTint)
                .frame(width: bodyR * 2, height: bodyR * 2)
                .offset(x: cx - bodyR, y: bodyCY - bodyR)

            // Cockpitramen
            Capsule()
                .fill(planeDark)
                .frame(width: bodyR * 0.95, height: bodyR * 0.26)
                .offset(x: cx - bodyR * 0.475, y: bodyCY - bodyR * 0.20)
        }
    }
}

// MARK: - Vertrekbord-bouwstenen
//
// De opbouw van de vluchtdetailkaart, losgetrokken zodat andere schermen 'm
// kunnen hergebruiken: context klein bovenaan, de kernwaarde groot, een
// statuspil eronder, dan feitregels waarvan de handelingsgerichte waarde geel
// oplicht, en onderaan een informatiestrip.

/// Statuspil zoals op een vertrekbord: kort, gekleurd, in één oogopslag te
/// lezen. De toon bepaalt de kleur, zodat "op tijd" overal hetzelfde groen is.
struct StatusPill: View {
    enum Tone { case positive, warning, negative, neutral }

    let text: String
    var tone: Tone = .neutral

    private var color: Color {
        switch tone {
        case .positive: return Theme.green
        case .warning:  return Theme.orange
        case .negative: return Theme.red
        case .neutral:  return Theme.textSecondary
        }
    }

    var body: some View {
        Text(text)
            .font(.frutiger(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

/// Label met waarde. `highlighted` zet de waarde in een geel pilletje — bewaar
/// dat voor het getal waar iemand daadwerkelijk naar zoekt (gate, bagageband,
/// aantal resterende items), niet voor elk veld.
struct FactLine: View {
    let label: String
    let value: String
    var highlighted: Bool = false
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        HStack(spacing: 5) {
            if alignment == .trailing { Spacer(minLength: 0) }
            Text(label)
                .font(.frutiger(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(highlighted ? Theme.ink : Theme.textPrimary)
                .padding(.horizontal, highlighted ? 6 : 0)
                .padding(.vertical, highlighted ? 2 : 0)
                .background(
                    highlighted ? AnyShapeStyle(Theme.yellow) : AnyShapeStyle(Color.clear),
                    in: RoundedRectangle(cornerRadius: 4)
                )
            if alignment == .leading { Spacer(minLength: 0) }
        }
    }
}

/// Strip onderaan een kaart: icoon, één regel tekst, en rechts optioneel een
/// waarde die eruit mag springen.
struct InfoStrip: View {
    let icon: String
    let text: String
    var trailingLabel: String? = nil
    var trailingValue: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.navy)
            Text(text)
                .font(.frutiger(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let trailingValue {
                HStack(spacing: 4) {
                    if let trailingLabel {
                        Text(trailingLabel)
                            .font(.frutiger(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(trailingValue)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.skyLight)
    }
}

/// Kop in vertrekbord-stijl: context klein, kernwaarde groot, status eronder.
struct BoardHeadline: View {
    let context: String
    let value: String
    var secondary: String? = nil
    var status: (text: String, tone: StatusPill.Tone)? = nil
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 5) {
            Text(context)
                .font(.frutiger(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let secondary {
                    Text(secondary)
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if let status {
                StatusPill(text: status.text, tone: status.tone)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

// MARK: - Paspoortstempel

/// Inreisstempel in paspoortstijl: bordeauxrood, licht scheef, met de naam van
/// de reiziger erin. Hetzelfde motief als de omslag van het reispaspoort, zodat
/// dat gevoel op meer plekken in de app terugkomt dan alleen dat ene scherm.
struct PassportStamp: View {
    let place: String
    let date: Date
    /// Vaste hoek per stempel: gevarieerd tussen plekken, maar stabiel tussen
    /// herteken-beurten — een stempel die rondspringt oogt slordig.
    var angle: Double = -7

    @ObservedObject private var session = UserSession.shared

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private var ink: Color { Color(red: 0.42, green: 0.10, blue: 0.17) }

    var body: some View {
        VStack(spacing: 3) {
            Text("VLIEGTUIGTAS")
                .font(.system(size: 7, weight: .black, design: .serif))
                .kerning(1.6)
            Text(place.uppercased())
                .font(.system(size: 13, weight: .black, design: .serif))
                .kerning(1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Rectangle()
                .fill(ink.opacity(0.55))
                .frame(width: 60, height: 1)
            Text(Self.formatter.string(from: date).uppercased())
                .font(.system(size: 8, weight: .bold, design: .serif))
                .kerning(0.6)
            Text(session.firstName.isEmpty ? "REIZIGER" : session.firstName.uppercased())
                .font(.system(size: 8, weight: .bold, design: .serif))
                .kerning(1.2)
        }
        .foregroundStyle(ink.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(ink.opacity(0.6), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ink.opacity(0.25), lineWidth: 1)
                .padding(-4)
        )
        .rotationEffect(.degrees(angle))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stempel: \(place), \(Self.formatter.string(from: date))")
    }
}

// MARK: - Bestemming-chip (cirkel + label)

/// Ronde foto/vlag-chip met label eronder, voor horizontaal scrollende
/// bestemming-stroken — dezelfde taal als "populaire bestemmingen"-rijen in
/// reis-apps: herkenbaar op klein formaat, uitnodigend om doorheen te swipen.
struct DestinationChip: View {
    let photoUrl: String?
    let flagEmoji: String?
    let label: String
    var size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Theme.skyLight)
                    if let photoUrl {
                        AuthorisedImage(urlString: photoUrl, fill: true)
                    } else if let flagEmoji {
                        Text(flagEmoji).font(.system(size: size * 0.4))
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.yellow, lineWidth: 2))

                Text(label)
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .frame(width: size + 12)
            }
        }
        .buttonStyle(.pressableCard)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline2)
                .foregroundStyle(Theme.textPrimary)
            // Klein geel accentstreepje — terugkerend merkmotief, geïnspireerd
            // op platform-bewegwijzering, dat de app onderscheidt van een
            // generiek blauw/wit maatschappij-scherm.
            Capsule()
                .fill(Theme.yellow)
                .frame(width: 22, height: 3)
        }
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
                        .font(.frutiger(size: 22, weight: .bold, relativeTo: .title2)).foregroundStyle(Theme.sky)
                }
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(.frutiger(size: 18, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                Button { value = min(range.upperBound, value + step) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.frutiger(size: 22, weight: .bold, relativeTo: .title2)).foregroundStyle(Theme.sky)
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

// MARK: - Bewaar in Herinneringen

/// Knop die één of meer tips/checklist-items in de Herinneringen-app opslaat.
/// Regelt zelf de toestemmingsvraag en toont feedback (opgeslagen / geen
/// toegang). Herbruikbaar op de luchthaven-tips, EU-regels, bagage-hulp, enz.
struct SaveToRemindersButton: View {
    /// De items die als aparte herinneringen worden opgeslagen.
    let titles: [String]
    /// Optionele context die bij elke herinnering als notitie meegaat.
    var notes: String? = nil
    var label: String = "Bewaar in Herinneringen"
    /// Compacte variant (klein, voor naast een enkele tip) vs. volle breedte.
    var compact: Bool = false

    @State private var state: SaveState = .idle
    @State private var showDeniedAlert = false

    private enum SaveState { case idle, saving, saved }

    var body: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 7) {
                Group {
                    if state == .saving {
                        ProgressView().tint(Theme.navy).scaleEffect(0.7)
                    } else {
                        Image(systemName: state == .saved ? "checkmark.circle.fill" : "checklist")
                            .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    }
                }
                Text(state == .saved ? "Opgeslagen" : label)
                    .font(.frutiger(size: compact ? 12 : 14, weight: .semibold))
            }
            .foregroundStyle(state == .saved ? Theme.green : Theme.navy)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 8 : 12)
            .frame(maxWidth: compact ? nil : .infinity)
            .background((state == .saved ? Theme.green : Theme.navy).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14))
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .alert("Geen toegang tot Herinneringen", isPresented: $showDeniedAlert) {
            Button("Naar Instellingen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Geef Vliegtuigtas toegang tot Herinneringen in Instellingen om tips te bewaren.")
        }
    }

    private func save() async {
        guard !titles.isEmpty else { return }
        state = .saving
        let ok: Bool
        if titles.count == 1 {
            ok = await RemindersService.shared.saveReminder(title: titles[0], notes: notes)
        } else {
            ok = await RemindersService.shared.saveReminders(titles: titles, notes: notes) > 0
        }
        if ok {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.3)) { state = .saved }
        } else {
            state = .idle
            // Alleen de instellingen-alert tonen als toegang echt geweigerd is.
            let status = RemindersService.shared.authorizationStatus
            if status == .denied || status == .restricted {
                showDeniedAlert = true
            }
        }
    }
}

// MARK: - Inline retry-/foutstaat

/// Compacte, herbruikbare "er ging iets mis"-staat met een opnieuw-knop.
/// Voor plekken waar een volledig scherm te veel is (een carrousel, een
/// sectie), maar we de gebruiker toch niet in het ongewisse willen laten.
struct InlineRetryState: View {
    let message: String
    var systemImage: String = "wifi.exclamationmark"
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onRetry) {
                Label("Opnieuw proberen", systemImage: "arrow.clockwise")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Theme.navy.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

