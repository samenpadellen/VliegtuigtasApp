import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Kleuren (widget-extensie is zelfstandig, dus eigen mini-palet)

private enum WTheme {
    static let navy     = Color(red: 0.00, green: 0.19, blue: 0.53)
    static let navyDark = Color(red: 0.00, green: 0.12, blue: 0.38)
    static let sky      = Color(red: 0.00, green: 0.63, blue: 0.87)
    static let yellow   = Color(red: 0.99, green: 0.80, blue: 0.10)

    static let navyGradient = LinearGradient(
        colors: [navy, navyDark], startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Mini-API (alleen wat de widget nodig heeft)

private struct WVariant: Codable {
    let includesLargeBag: Bool?
    let smallLCm: Double?
    let smallWCm: Double?
    let smallDCm: Double?
    let largeLCm: Double?
    let largeWCm: Double?
    let largeDCm: Double?
    let maxWeightKg: Double?

    enum CodingKeys: String, CodingKey {
        case includesLargeBag = "includes_large_bag"
        case smallLCm = "small_l_cm"
        case smallWCm = "small_w_cm"
        case smallDCm = "small_d_cm"
        case largeLCm = "large_l_cm"
        case largeWCm = "large_w_cm"
        case largeDCm = "large_d_cm"
        case maxWeightKg = "max_weight_kg"
    }
}

private struct WAirline: Codable {
    let slug: String
    let name: String
    let personalItemLCm: Double?
    let personalItemWCm: Double?
    let personalItemDCm: Double?
    let variants: [WVariant]?

    enum CodingKeys: String, CodingKey {
        case slug, name, variants
        case personalItemLCm = "personal_item_l_cm"
        case personalItemWCm = "personal_item_w_cm"
        case personalItemDCm = "personal_item_d_cm"
    }
}

private struct WAPIResponse<T: Decodable>: Decodable {
    let data: T?
}

private enum WidgetAPI {
    static let apiKey = "lFkEQW18oyMrdMsbfNK1DtnDnoCcqwNSBRfMCXmszUgbAoLf"
    static let base = URL(string: "https://vliegtuigtas.com/api/public/v1")!
    static let cacheKey = "vt_widget_airlines_cache"

    static func fetchAirlines() async throws -> [WAirline] {
        var req = URLRequest(url: base.appendingPathComponent("airlines"))
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        let airlines = try JSONDecoder().decode(WAPIResponse<[WAirline]>.self, from: data).data ?? []
        // Cache voor offline intent-suggesties en snelle timelines.
        if let encoded = try? JSONEncoder().encode(airlines) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
        return airlines
    }

    static func cachedAirlines() -> [WAirline] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let airlines = try? JSONDecoder().decode([WAirline].self, from: data) else { return [] }
        return airlines
    }

    static func airlinesPreferringCache() async -> [WAirline] {
        let cached = cachedAirlines()
        if !cached.isEmpty { return cached }
        return (try? await fetchAirlines()) ?? []
    }
}

// MARK: - Regels afleiden uit een airline

private struct BagRules {
    let largeDims: String?
    let smallDims: String?
    let maxWeight: String?

    init(airline: WAirline) {
        func format(_ l: Double?, _ w: Double?, _ d: Double?) -> String? {
            guard let l, let w, let d else { return nil }
            return "\(Int(l))×\(Int(w))×\(Int(d))"
        }
        let variant = airline.variants?.first { $0.includesLargeBag == true } ?? airline.variants?.first
        largeDims = format(variant?.largeLCm, variant?.largeWCm, variant?.largeDCm)
        smallDims = format(variant?.smallLCm, variant?.smallWCm, variant?.smallDCm)
            ?? format(airline.personalItemLCm, airline.personalItemWCm, airline.personalItemDCm)
        maxWeight = variant?.maxWeightKg.map { "\(Int($0)) kg" }
    }
}

// MARK: - App Intent-configuratie (kies je maatschappij op de widget zelf)

struct AirlineEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Maatschappij"
    static var defaultQuery = AirlineEntityQuery()

    let id: String   // slug
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AirlineEntityQuery: EntityQuery {
    func entities(for identifiers: [AirlineEntity.ID]) async throws -> [AirlineEntity] {
        let airlines = await WidgetAPI.airlinesPreferringCache()
        return airlines
            .filter { identifiers.contains($0.slug) }
            .map { AirlineEntity(id: $0.slug, name: $0.name) }
    }

    func suggestedEntities() async throws -> [AirlineEntity] {
        let airlines = (try? await WidgetAPI.fetchAirlines()) ?? WidgetAPI.cachedAirlines()
        return airlines.map { AirlineEntity(id: $0.slug, name: $0.name) }
    }

    func defaultResult() async -> AirlineEntity? {
        let airlines = await WidgetAPI.airlinesPreferringCache()
        return airlines.first.map { AirlineEntity(id: $0.slug, name: $0.name) }
    }
}

struct SelectAirlineIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Kies maatschappij"
    static var description = IntentDescription("Toon de handbagageregels van jouw vliegmaatschappij.")

    @Parameter(title: "Maatschappij")
    var airline: AirlineEntity?
}

// MARK: - Timeline

struct BagageEntry: TimelineEntry {
    let date: Date
    let airlineName: String
    let slug: String?
    let largeDims: String?
    let smallDims: String?
    let maxWeight: String?
}

extension BagageEntry {
    static let placeholder = BagageEntry(
        date: .now, airlineName: "KLM", slug: nil,
        largeDims: "55×35×25", smallDims: "40×30×15", maxWeight: "12 kg"
    )

    var deepLink: URL? {
        guard let slug else { return URL(string: "vliegtuigtas://check") }
        return URL(string: "vliegtuigtas://check?airline=\(slug)")
    }
}

struct BagageProvider: AppIntentTimelineProvider {
    typealias Entry = BagageEntry
    typealias Intent = SelectAirlineIntent

    func placeholder(in context: Context) -> BagageEntry { .placeholder }

    func snapshot(for configuration: SelectAirlineIntent, in context: Context) async -> BagageEntry {
        await entry(for: configuration) ?? .placeholder
    }

    func timeline(for configuration: SelectAirlineIntent, in context: Context) async -> Timeline<BagageEntry> {
        let entry = await entry(for: configuration) ?? .placeholder
        // Bagageregels veranderen zelden — één keer per dag verversen is genoeg.
        let refresh = Calendar.current.date(byAdding: .hour, value: 24, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func entry(for configuration: SelectAirlineIntent) async -> BagageEntry? {
        let airlines = (try? await WidgetAPI.fetchAirlines()) ?? WidgetAPI.cachedAirlines()
        guard !airlines.isEmpty else { return nil }
        let chosen = configuration.airline.flatMap { entity in
            airlines.first { $0.slug == entity.id }
        } ?? airlines[0]
        let rules = BagRules(airline: chosen)
        return BagageEntry(
            date: .now,
            airlineName: chosen.name,
            slug: chosen.slug,
            largeDims: rules.largeDims,
            smallDims: rules.smallDims,
            maxWeight: rules.maxWeight
        )
    }
}

// MARK: - Solari-klepjes (statisch: widgets zijn snapshots)

/// Zelfde vertrekbord-look als in de app: donkere klepjes met monospaced
/// kapitalen en de horizontale naad. Zonder animatie, maar onmiskenbaar
/// hetzelfde bord.
private struct FlapTiles: View {
    let text: String
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: size * 0.14) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: size, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.78, height: size * 1.35)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.14)
                            .fill(Color(red: 0.03, green: 0.06, blue: 0.13))
                    )
                    .overlay(
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .frame(height: 1)
                    )
            }
        }
    }
}

// MARK: - Widget views

struct BagageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BagageEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:      inlineView
            case .accessoryCircular:    circularView
            case .accessoryRectangular: rectangularView
            case .systemMedium:         mediumView
            default:                    smallView
            }
        }
        .widgetURL(entry.deepLink)
    }

    // — Home screen: klein —

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WTheme.yellow)
                Text(entry.airlineName)
                    .font(.frutiger(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("HANDBAGAGE")
                    .font(.frutiger(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .kerning(0.8)
                FlapTiles(text: entry.largeDims ?? entry.smallDims ?? "—", size: 15)
                Text("cm" + (entry.maxWeight.map { " · max \($0)" } ?? ""))
                    .font(.frutiger(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WTheme.navyGradient }
    }

    // — Home screen: medium (cabine + klein item naast elkaar) —

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WTheme.yellow)
                Text(entry.airlineName)
                    .font(.frutiger(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text("Handbagage")
                    .font(.frutiger(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            HStack(spacing: 10) {
                dimBlock(
                    icon: "bag.fill",
                    title: "CABINEKOFFER",
                    dims: entry.largeDims,
                    footnote: entry.maxWeight.map { "max \($0)" }
                )
                dimBlock(
                    icon: "backpack.fill",
                    title: "ONDER DE STOEL",
                    dims: entry.smallDims,
                    footnote: "klein item"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WTheme.navyGradient }
    }

    private func dimBlock(icon: String, title: String, dims: String?, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.frutiger(size: 8, weight: .bold))
                    .kerning(0.6)
            }
            .foregroundStyle(.white.opacity(0.6))

            FlapTiles(text: dims ?? "—", size: 13)

            if let footnote {
                Text(footnote)
                    .font(.frutiger(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    // — Lock screen —
    // Let op: óók accessory-families hebben sinds iOS 17 een
    // containerBackground nodig, anders rendert WidgetKit ze niet.

    private var inlineView: some View {
        // Eén regel boven de klok: "KLM · 55×35×25 cm"
        Text("\(entry.airlineName) · \(entry.largeDims ?? entry.smallDims ?? "—") cm")
            .monospacedDigit()
            .containerBackground(for: .widget) { Color.clear }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                Text(entry.maxWeight ?? String(entry.airlineName.prefix(4)))
                    .font(.frutiger(size: 11, weight: .heavy))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()
                Text(entry.airlineName)
                    .font(.frutiger(size: 13, weight: .heavy))
                    .lineLimit(1)
            }
            Text("Cabine \(entry.largeDims ?? "—") cm")
                .font(.frutiger(size: 12, weight: .semibold))
                .monospacedDigit()
            Text("Stoel \(entry.smallDims ?? "—")" + (entry.maxWeight.map { " · \($0)" } ?? ""))
                .font(.frutiger(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Vlucht-aftelling: gedeelde data uit de App Group

private enum SharedFlight {
    static let suite = UserDefaults(suiteName: "group.com.vliegtuigtas.app")

    static var flightNumber: String? { nonEmpty(suite?.string(forKey: "vt_shared_flight_number")) }
    static var airlineName: String?  { nonEmpty(suite?.string(forKey: "vt_shared_flight_airline")) }
    static var airlineSlug: String?  { nonEmpty(suite?.string(forKey: "vt_shared_flight_slug")) }
    static var firstName: String?    { nonEmpty(suite?.string(forKey: "vt_shared_first_name")) }

    static var departure: Date? {
        guard let t = suite?.double(forKey: "vt_shared_flight_departure"), t > 0 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    /// "AMS → LHR", of nil als de route niet bekend is.
    static var routeLabel: String? {
        guard let dep = nonEmpty(suite?.string(forKey: "vt_shared_flight_dep_iata")),
              let arr = nonEmpty(suite?.string(forKey: "vt_shared_flight_arr_iata")) else { return nil }
        return "\(dep) → \(arr)"
    }

    static var arrivalAirport: String? { nonEmpty(suite?.string(forKey: "vt_shared_flight_arr_name")) }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}

// MARK: - Vlucht-aftelling: timeline

struct VluchtEntry: TimelineEntry {
    let date: Date
    let firstName: String?
    let flightNumber: String?
    let airlineName: String?
    let airlineSlug: String?
    let departure: Date?
    var routeLabel: String? = nil
    var arrivalAirport: String? = nil

    /// Hele dagen tot vertrek (0 = vandaag, negatief = geweest).
    var daysLeft: Int? {
        guard let departure else { return nil }
        let cal = Calendar.current
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: date),
            to: cal.startOfDay(for: departure)
        ).day
    }

    var hasUpcomingFlight: Bool {
        guard let daysLeft else { return false }
        return daysLeft >= 0
    }

    var greeting: String {
        firstName.map { "Hey \($0) 👋" } ?? "Jouw vlucht"
    }

    /// Korte variant voor de Solari-klepjes op de widget.
    var flapCountdown: String {
        guard let days = daysLeft, days >= 0 else { return "GEEN VLUCHT" }
        switch days {
        case 0:  return "VANDAAG"
        case 1:  return "MORGEN"
        default: return "\(days) DAGEN"
        }
    }

    var countdownTitle: String {
        guard let days = daysLeft, days >= 0 else { return "Geen vlucht gepland" }
        switch days {
        case 0:  return "Vandaag vliegen!"
        case 1:  return "Morgen vliegen!"
        default: return "Nog \(days) dagen"
        }
    }

    var bagReminder: String {
        guard let days = daysLeft, days >= 0 else {
            return "Zoek je vluchtnummer in de app en zet 'm hier neer."
        }
        switch days {
        case 0:  return firstName.map { "Goede reis, \($0)! ✈️" } ?? "Goede reis! ✈️"
        case 1:  return "Laatste check: past je handbagage?"
        case 2...4: return "Bijna zover, let op je koffer!"
        default: return "Let op je koffer: check alvast de maten."
        }
    }

    var deepLink: URL? {
        guard let airlineSlug else { return URL(string: "vliegtuigtas://check") }
        return URL(string: "vliegtuigtas://check?airline=\(airlineSlug)")
    }
}

extension VluchtEntry {
    static let placeholder = VluchtEntry(
        date: .now, firstName: "Wouter", flightNumber: "KL1234",
        airlineName: "KLM", airlineSlug: nil,
        departure: Calendar.current.date(byAdding: .day, value: 5, to: .now)
    )
}

struct VluchtProvider: TimelineProvider {
    func placeholder(in context: Context) -> VluchtEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (VluchtEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VluchtEntry>) -> Void) {
        // Eén entry voor nu + één per komende middernacht, zodat de aftelling
        // elke dag verspringt zonder netwerk of achtergrondwerk.
        var entries = [entry(at: .now)]
        let cal = Calendar.current
        if let departure = SharedFlight.departure, departure > .now {
            var day = cal.startOfDay(for: .now)
            for _ in 0..<30 {
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                entries.append(entry(at: next))
                if next > departure { break }
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> VluchtEntry {
        VluchtEntry(
            date: date,
            firstName: SharedFlight.firstName,
            flightNumber: SharedFlight.flightNumber,
            airlineName: SharedFlight.airlineName,
            airlineSlug: SharedFlight.airlineSlug,
            departure: SharedFlight.departure,
            routeLabel: SharedFlight.routeLabel,
            arrivalAirport: SharedFlight.arrivalAirport
        )
    }
}

// MARK: - Vlucht-aftelling: views

struct VluchtWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VluchtEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:      inlineView
            case .accessoryCircular:    circularView
            case .accessoryRectangular: rectangularView
            case .systemMedium:         mediumView
            default:                    smallView
            }
        }
        .widgetURL(entry.deepLink)
    }

    private var flightLine: String? {
        guard let number = entry.flightNumber else { return nil }
        if let airline = entry.airlineName { return "\(number) · \(airline)" }
        return number
    }

    // — Home screen: klein —

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.greeting)
                .font(.frutiger(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            if entry.hasUpcomingFlight {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WTheme.yellow)
                FlapTiles(text: entry.flapCountdown, size: 13)
                if let flightLine {
                    Text(flightLine)
                        .font(.frutiger(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(entry.bagReminder)
                    .font(.frutiger(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            } else {
                Image(systemName: "airplane")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WTheme.yellow)
                Text("Geen vlucht")
                    .font(.frutiger(size: 17, weight: .black))
                    .foregroundStyle(.white)
                Text(entry.bagReminder)
                    .font(.frutiger(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WTheme.navyGradient }
    }

    // — Home screen: medium —

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.greeting)
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                FlapTiles(text: entry.flapCountdown, size: 17)
                if let flightLine {
                    Text(flightLine)
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(WTheme.yellow)
                        .lineLimit(1)
                }
                if let route = entry.routeLabel {
                    Text(route + (entry.arrivalAirport.map { " · \($0)" } ?? ""))
                        .font(.frutiger(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(entry.bagReminder)
                        .font(.frutiger(size: 11, weight: .medium))
                        .lineLimit(2)
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if entry.hasUpcomingFlight, let days = entry.daysLeft {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progressToFlight)
                        .stroke(WTheme.yellow, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(days)")
                            .font(.frutiger(size: 22, weight: .black))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text(days == 1 ? "dag" : "dgn")
                            .font(.frutiger(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 64, height: 64)
            } else {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(WTheme.yellow.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WTheme.navyGradient }
    }

    /// Voortgang van 30 dagen vóór vertrek (0) naar vertrekdag (1).
    private var progressToFlight: CGFloat {
        guard let days = entry.daysLeft, days >= 0 else { return 0 }
        return max(0.04, min(1, 1 - CGFloat(days) / 30))
    }

    // — Lock screen —
    // Ook hier: containerBackground verplicht, anders geen rendering.

    private var inlineView: some View {
        Group {
            if entry.hasUpcomingFlight, let days = entry.daysLeft {
                Text("✈︎ \(entry.flightNumber ?? "Vlucht") · \(days == 0 ? "vandaag" : days == 1 ? "morgen" : "nog \(days) dgn")")
                    .monospacedDigit()
            } else {
                Text("✈︎ Geen vlucht gepland")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.hasUpcomingFlight, let days = entry.daysLeft {
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(.frutiger(size: 20, weight: .black))
                        .monospacedDigit()
                        .widgetAccentable()
                    Text(days == 1 ? "dag" : "dgn")
                        .font(.frutiger(size: 9, weight: .semibold))
                }
            } else {
                Image(systemName: "airplane")
                    .font(.system(size: 16, weight: .semibold))
                    .widgetAccentable()
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()
                Text(flightLine ?? entry.greeting)
                    .font(.frutiger(size: 12, weight: .bold))
                    .lineLimit(1)
            }
            Text(entry.countdownTitle)
                .font(.frutiger(size: 15, weight: .black))
                .monospacedDigit()
                .widgetAccentable()
            Text(entry.routeLabel ?? entry.bagReminder)
                .font(.frutiger(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct VluchtCountdownWidget: Widget {
    let kind = "VluchtCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VluchtProvider()) { entry in
            VluchtWidgetView(entry: entry)
        }
        .configurationDisplayName("Vluchtaftelling")
        .description("Telt af naar je opgeslagen vlucht en herinnert je op tijd aan je koffer.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Purser Pim: dagelijkse pak-tip

/// Zelfde pet-mascotte als in de app (géén sparkles/AI-iconografie) — eigen
/// kopie hier, want de widget-extensie deelt geen SwiftUI-bestanden met de
/// hoofdapp.
private struct PimCapIcon: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.08, green: 0.10, blue: 0.16))
                .frame(width: size * 0.78, height: size * 0.34)
                .offset(y: size * 0.22)
            Ellipse()
                .fill(.white)
                .frame(width: size, height: size * 0.62)
                .offset(y: -size * 0.10)
            Capsule()
                .fill(WTheme.navy)
                .frame(width: size * 0.94, height: size * 0.30)
                .offset(y: size * 0.10)
            Image(systemName: "airplane")
                .font(.system(size: size * 0.20, weight: .bold))
                .foregroundStyle(WTheme.yellow)
                .offset(y: size * 0.10)
        }
        .frame(width: size, height: size * 0.9)
    }
}

/// Statische pak-tips van Purser Pim, in vaste rotatie — getoond zolang er
/// geen recente, écht door Apple Intelligence gegenereerde tip in de cache
/// staat (zie `PimTipCache` hieronder, geschreven door de hoofdapp).
private enum PimStaticTips {
    static let all: [String] = [
        "Rol kleding op in plaats van vouwen: je wint zo al snel 30% ruimte in je handbagage.",
        "Zet je zwaarste spullen onderin, tegen de wielenkant — dat rolt het prettigst en is het stevigst.",
        "Draag je dikste jas of trui aan boord in plaats van in te pakken: dat scheelt letterlijk kilo's in je tas.",
        "Vloeistoffen boven 100 ml horen in de ruimbagage, niet in je handbagage.",
        "Powerbanks moeten juist wél in je handbagage — nooit in de ruimbagage.",
        "Weeg je tas thuis op de badkamerweegschaal voor je vertrekt: geen verrassingen bij de balie.",
        "Gebruik packing cubes: ze houden je tas overzichtelijk én persen kleding compacter.",
        "Print of download je instapkaart alvast: sommige maatschappijen rekenen extra aan de balie.",
        "Bewaar medicijnen in de originele verpakking mét etiket, voor het geval security ernaar vraagt.",
        "Check de bagageregels van je maatschappij vóór je een nieuwe koffer koopt: maten verschillen enorm.",
        "Een universele stekkeradapter weegt bijna niets en past in elk hoekje van je tas.",
        "Label je koffer aan de binnen- én buitenkant: dan vindt de luchthaven 'm altijd terug.",
        "Kom ruim op tijd bij de gate: bagagevakken raken snel vol bij het instappen.",
        "Check vlak voor vertrek nog eens de regels van je maatschappij: die wijzigen weleens."
    ]

    /// Rouleert per kalenderdag, zodat de tip een hele dag hetzelfde blijft.
    static func forDay(_ date: Date) -> String {
        let dayNumber = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return all[dayNumber % all.count]
    }
}

/// Écht door Pim (Apple Intelligence) gegenereerde tip, geschreven door de
/// hoofdapp zodra je daar pakadvies opvraagt — widgets kunnen zelf geen
/// taalmodel-sessie starten, dus dit is de brug tussen de twee.
private enum PimTipCache {
    static var tip: String? {
        guard let t = SharedFlight.suite?.string(forKey: "vt_shared_pim_tip"), !t.isEmpty else { return nil }
        return t
    }

    static var airlineName: String? {
        let name = SharedFlight.suite?.string(forKey: "vt_shared_pim_tip_airline")
        return (name?.isEmpty ?? true) ? nil : name
    }

    /// Ouder dan 7 dagen tonen we niet meer als "van Pim": dan is de
    /// statische rotatie actueler dan een oude AI-tip.
    static var isFresh: Bool {
        let stamp = SharedFlight.suite?.double(forKey: "vt_shared_pim_tip_stamp") ?? 0
        guard stamp > 0 else { return false }
        return Date().timeIntervalSince1970 - stamp < 7 * 24 * 3600
    }
}

struct PimTipEntry: TimelineEntry {
    let date: Date
    let tip: String
    let airlineName: String?
    /// Écht door Apple Intelligence gegenereerd, i.p.v. statisch geroteerd.
    let isFromPim: Bool
}

extension PimTipEntry {
    static let placeholder = PimTipEntry(
        date: .now,
        tip: "Rol kleding op in plaats van vouwen: je wint zo al snel 30% ruimte in je handbagage.",
        airlineName: nil,
        isFromPim: false
    )
}

struct PimTipProvider: TimelineProvider {
    func placeholder(in context: Context) -> PimTipEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (PimTipEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PimTipEntry>) -> Void) {
        // Eén entry per dag voor een week: de tip rouleert zonder netwerk
        // of achtergrondwerk. Verandert de AI-cache tussentijds (nieuw
        // pakadvies in de app), dan herlaadt de app de timeline zelf.
        let cal = Calendar.current
        var entries: [PimTipEntry] = []
        var day = cal.startOfDay(for: .now)
        for _ in 0..<7 {
            entries.append(entry(at: day))
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> PimTipEntry {
        if PimTipCache.isFresh, let cached = PimTipCache.tip {
            return PimTipEntry(date: date, tip: cached, airlineName: PimTipCache.airlineName, isFromPim: true)
        }
        return PimTipEntry(date: date, tip: PimStaticTips.forDay(date), airlineName: nil, isFromPim: false)
    }
}

struct PurserPimWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PimTipEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:      inlineView
            case .accessoryCircular:    circularView
            case .accessoryRectangular: rectangularView
            case .systemMedium:         mediumView
            default:                    smallView
            }
        }
        .widgetURL(URL(string: "vliegtuigtas://pim"))
    }

    private var kicker: String {
        if entry.isFromPim, let airline = entry.airlineName {
            return "PIM'S TIP VOOR \(airline.uppercased())"
        }
        return "PIM'S TIP VAN DE DAG"
    }

    // — Home screen: klein —

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                PimCapIcon(size: 22)
                Text("Purser Pim")
                    .font(.frutiger(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            Text(kicker)
                .font(.frutiger(size: 8, weight: .bold))
                .foregroundStyle(WTheme.yellow)
                .kerning(0.5)
            Text(entry.tip)
                .font(.frutiger(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(5)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WTheme.navyGradient }
    }

    // — Home screen: medium —

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            PimCapIcon(size: 34)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Purser Pim")
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    if entry.isFromPim {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(WTheme.yellow)
                    }
                }
                Text(kicker)
                    .font(.frutiger(size: 9, weight: .bold))
                    .foregroundStyle(WTheme.yellow)
                    .kerning(0.5)
                Text(entry.tip)
                    .font(.frutiger(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WTheme.navyGradient }
    }

    // — Lock screen —
    // Accessory-families renderen monochroom: geen custom mascotte-vormen
    // hier, gewoon een duidelijk SF Symbol zoals bij de andere widgets.

    private var inlineView: some View {
        Text("Pim: \(entry.tip)")
            .containerBackground(for: .widget) { Color.clear }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .widgetAccentable()
                Text("PIM")
                    .font(.frutiger(size: 9, weight: .heavy))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()
                Text("Purser Pim")
                    .font(.frutiger(size: 12, weight: .bold))
            }
            Text(entry.tip)
                .font(.frutiger(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct PurserPimWidget: Widget {
    let kind = "PurserPimWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PimTipProvider()) { entry in
            PurserPimWidgetView(entry: entry)
        }
        .configurationDisplayName("Purser Pim")
        .description("Elke dag een pak-tip van Purser Pim — persoonlijk zodra je pakadvies in de app hebt gevraagd.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Control Center-knop (iOS 18+)

/// Bedieningspaneel-knop: één veeg en tik en je staat in de bagagecheck —
/// ook vanaf het toegangsscherm. Vervangbaar via Instellingen > Bedieningspaneel.
@available(iOS 18.0, *)
struct OpenCheckerControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Open de bagagecheck"
    static var description = IntentDescription("Opent Vliegtuigtas op het checkscherm.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "vliegtuigtas://check")!))
    }
}

@available(iOS 18.0, *)
struct BagageCheckControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "BagageCheckControl") {
            ControlWidgetButton(action: OpenCheckerControlIntent()) {
                Label("Bagagecheck", systemImage: "suitcase.rolling.fill")
            }
        }
        .displayName("Bagagecheck")
        .description("Open de handbagagecheck direct vanuit het Bedieningspaneel.")
    }
}

// MARK: - Widget & bundle

struct BagageRegelsWidget: Widget {
    let kind = "BagageRegelsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectAirlineIntent.self,
            provider: BagageProvider()
        ) { entry in
            BagageWidgetView(entry: entry)
        }
        .configurationDisplayName("Bagageregels")
        .description("De handbagagematen van jouw maatschappij, altijd binnen handbereik, ook op je toegangsscherm.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

@main
struct VliegtuigtasWidgets: WidgetBundle {
    init() { AppFont.register() }

    var body: some Widget {
        VluchtCountdownWidget()
        BagageRegelsWidget()
        PurserPimWidget()
        #if !targetEnvironment(macCatalyst)
        FlightLiveActivity()
        #endif
        controlWidgets
    }

    /// Apart @WidgetBundleBuilder-blok: zo kan de Control Center-knop achter
    /// een availability-check zitten terwijl de extensie op iOS 17 blijft draaien.
    @WidgetBundleBuilder
    private var controlWidgets: some Widget {
        if #available(iOS 18.0, *) {
            BagageCheckControl()
        }
    }
}
