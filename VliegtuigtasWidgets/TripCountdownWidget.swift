import WidgetKit
import SwiftUI

// MARK: - Gedeelde data uit de App Group (eerstvolgende reis)

private enum SharedTrip {
    static let suite = UserDefaults(suiteName: "group.com.vliegtuigtas.app")

    static var name: String? { nonEmpty(suite?.string(forKey: "vt_shared_trip_name")) }
    static var destination: String? { nonEmpty(suite?.string(forKey: "vt_shared_trip_destination")) }

    static var startDate: Date? {
        guard let t = suite?.double(forKey: "vt_shared_trip_start"), t > 0 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}

// MARK: - Timeline

struct TripEntry: TimelineEntry {
    let date: Date
    let name: String?
    let destination: String?
    let startDate: Date?

    var daysLeft: Int? {
        guard let startDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: date),
            to: cal.startOfDay(for: startDate)
        ).day
    }

    var hasUpcomingTrip: Bool {
        guard let daysLeft else { return false }
        return daysLeft >= 0
    }

    var countdownTitle: String {
        guard let days = daysLeft, days >= 0 else { return "Geen reis gepland" }
        switch days {
        case 0:  return "Vandaag vertrek!"
        case 1:  return "Morgen vertrek!"
        default: return "Nog \(days) dagen"
        }
    }

    static let placeholder = TripEntry(
        date: .now, name: "Rome citytrip", destination: "Rome, Italië",
        startDate: Calendar.current.date(byAdding: .day, value: 12, to: .now)
    )
}

struct TripProvider: TimelineProvider {
    func placeholder(in context: Context) -> TripEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TripEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripEntry>) -> Void) {
        // Eén entry voor nu + één per komende middernacht, zodat de aftelling
        // elke dag verspringt zonder netwerk of achtergrondwerk — zelfde
        // aanpak als VluchtProvider.
        var entries = [entry(at: .now)]
        let cal = Calendar.current
        if let start = SharedTrip.startDate, start > .now {
            var day = cal.startOfDay(for: .now)
            for _ in 0..<30 {
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                entries.append(entry(at: next))
                if next > start { break }
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> TripEntry {
        TripEntry(date: date, name: SharedTrip.name, destination: SharedTrip.destination, startDate: SharedTrip.startDate)
    }
}

// MARK: - Views

private enum TWTheme {
    static let navy = Color(red: 0.00, green: 0.19, blue: 0.53)
    static let sky  = Color(red: 0.00, green: 0.63, blue: 0.87)
    static let yellow = Color(red: 0.99, green: 0.80, blue: 0.10)

    static let skyGradient = LinearGradient(
        colors: [sky, navy], startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

struct TripWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TripEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium: mediumView
            default:            smallView
            }
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TWTheme.yellow)
            Spacer(minLength: 0)
            if entry.hasUpcomingTrip {
                Text(entry.countdownTitle)
                    .font(.frutiger(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if let name = entry.name {
                    Text(name)
                        .font(.frutiger(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            } else {
                Text("Geen reis gepland")
                    .font(.frutiger(size: 14, weight: .black))
                    .foregroundStyle(.white)
                Text("Plan een reis in Vliegtuigtas.")
                    .font(.frutiger(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { TWTheme.skyGradient }
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name ?? "Mijn reizen")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text(entry.countdownTitle)
                    .font(.frutiger(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let destination = entry.destination {
                    Text(destination)
                        .font(.frutiger(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: entry.hasUpcomingTrip ? "suitcase.rolling.fill" : "suitcase.rolling")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(TWTheme.yellow.opacity(entry.hasUpcomingTrip ? 1 : 0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { TWTheme.skyGradient }
    }
}

struct TripCountdownWidget: Widget {
    let kind = "TripCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripProvider()) { entry in
            TripWidgetView(entry: entry)
        }
        .configurationDisplayName("Reis-aftelling")
        .description("Telt af naar je eerstvolgende geplande reis.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
