import WidgetKit
import SwiftUI

// MARK: - Gedeelde vluchtdata (App Group, gevuld door de watch-app via iCloud)

private enum WatchSharedFlight {
    static let suite = UserDefaults(suiteName: "group.com.vliegtuigtas.app")

    static var flightNumber: String? {
        guard let s = suite?.string(forKey: "vt_shared_flight_number"), !s.isEmpty else { return nil }
        return s
    }

    static var airlineName: String? {
        guard let s = suite?.string(forKey: "vt_shared_flight_airline"), !s.isEmpty else { return nil }
        return s
    }

    static var departure: Date? {
        guard let t = suite?.double(forKey: "vt_shared_flight_departure"), t > 0 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    static var routeLabel: String? {
        guard let dep = suite?.string(forKey: "vt_shared_flight_dep_iata"), !dep.isEmpty,
              let arr = suite?.string(forKey: "vt_shared_flight_arr_iata"), !arr.isEmpty else { return nil }
        return "\(dep) → \(arr)"
    }
}

// MARK: - Timeline

struct WatchVluchtEntry: TimelineEntry {
    let date: Date
    let flightNumber: String?
    let airlineName: String?
    let departure: Date?
    var routeLabel: String? = nil

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

    var countdownLabel: String {
        guard let days = daysLeft, days >= 0 else { return "Geen vlucht" }
        switch days {
        case 0:  return "Vandaag!"
        case 1:  return "Morgen"
        default: return "Nog \(days) dagen"
        }
    }

    static let placeholder = WatchVluchtEntry(
        date: .now, flightNumber: "KL1234", airlineName: "KLM",
        departure: Calendar.current.date(byAdding: .day, value: 3, to: .now)
    )
}

struct WatchVluchtProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchVluchtEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (WatchVluchtEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchVluchtEntry>) -> Void) {
        // Eén entry voor nu + één per komende middernacht: de aftelling
        // verspringt elke dag zonder netwerk.
        var entries = [entry(at: .now)]
        let cal = Calendar.current
        if let departure = WatchSharedFlight.departure, departure > .now {
            var day = cal.startOfDay(for: .now)
            for _ in 0..<14 {
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                entries.append(entry(at: next))
                if next > departure { break }
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> WatchVluchtEntry {
        WatchVluchtEntry(
            date: date,
            flightNumber: WatchSharedFlight.flightNumber,
            airlineName: WatchSharedFlight.airlineName,
            departure: WatchSharedFlight.departure,
            routeLabel: WatchSharedFlight.routeLabel
        )
    }
}

// MARK: - Views per wijzerplaat-familie

struct WatchVluchtWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchVluchtEntry

    var body: some View {
        switch family {
        case .accessoryCorner:    corner
        case .accessoryInline:    inline
        case .accessoryRectangular: rectangular
        default:                  circular
        }
    }

    // Cirkel: dagen groot in het midden
    private var circular: some View {
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

    // Hoek: vliegtuigje met gebogen tekstlabel eromheen
    private var corner: some View {
        Image(systemName: entry.hasUpcomingFlight ? "airplane.departure" : "airplane")
            .font(.system(size: 20, weight: .semibold))
            .widgetAccentable()
            .widgetLabel {
                if entry.hasUpcomingFlight {
                    Text("\(entry.flightNumber ?? "Vlucht") · \(entry.countdownLabel)")
                        .monospacedDigit()
                } else {
                    Text("Vliegtuigtas")
                }
            }
            .containerBackground(for: .widget) { Color.clear }
    }

    private var inline: some View {
        Group {
            if entry.hasUpcomingFlight {
                Text("✈︎ \(entry.flightNumber ?? "Vlucht") · \(entry.countdownLabel)")
                    .monospacedDigit()
            } else {
                Text("✈︎ Geen vlucht gepland")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()
                Text(entry.flightNumber ?? "Vliegtuigtas")
                    .font(.frutiger(size: 12, weight: .bold))
                    .lineLimit(1)
            }
            Text(entry.countdownLabel)
                .font(.frutiger(size: 15, weight: .black))
                .monospacedDigit()
                .widgetAccentable()
            if let detail = entry.routeLabel ?? entry.airlineName {
                Text(detail)
                    .font(.frutiger(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget & bundle

struct WatchVluchtWidget: Widget {
    let kind = "WatchVluchtWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchVluchtProvider()) { entry in
            WatchVluchtWidgetView(entry: entry)
        }
        .configurationDisplayName("Vluchtaftelling")
        .description("Telt op je wijzerplaat af naar je opgeslagen vlucht.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

@main
struct VliegtuigtasWatchWidgets: WidgetBundle {
    init() { AppFont.register() }

    var body: some Widget {
        WatchVluchtWidget()
    }
}
