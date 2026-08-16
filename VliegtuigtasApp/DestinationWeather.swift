import SwiftUI
import WeatherKit
import CoreLocation

// MARK: - Weer op de bestemming (WeatherKit)
//
// Zodra een vlucht een bekende aankomstluchthaven heeft (uit de
// vluchtnummer-lookup), geocoden we die naam naar coördinaten en vragen we
// een korte dagvoorspelling op — puur om te laten zien wát je moet inpakken,
// niet als volwaardige weer-app.

struct DestinationForecastDay: Identifiable {
    let id = UUID()
    let date: Date
    let symbolName: String
    let highCelsius: Int
    let lowCelsius: Int
    let precipitationChance: Double // 0...1
}

struct DestinationForecast {
    let placeName: String
    let days: [DestinationForecastDay]

    /// Eén korte, Nederlandse pakadvies-zin op basis van de eerste dag —
    /// geeft direct richting zonder dat je de hele week hoeft te lezen.
    var packingHint: String? {
        guard let first = days.first else { return nil }
        var tips: [String] = []
        if first.highCelsius >= 25 { tips.append("lichte kleding en zonnebrand") }
        else if first.highCelsius <= 10 { tips.append("een warme jas") }
        else { tips.append("een laagje voor onderweg") }
        if first.precipitationChance >= 0.4 { tips.append("een paraplu of regenjas") }
        return "Op je bestemming is het rond de \(first.highCelsius)°C — pak \(tips.joined(separator: " en "))."
    }
}

@MainActor
final class DestinationWeatherStore: ObservableObject {
    @Published private(set) var forecast: DestinationForecast?
    @Published private(set) var isLoading = false
    @Published private(set) var unavailable = false

    /// Gedeeld tussen instanties: dezelfde luchthaven hoeft niet steeds
    /// opnieuw gegeocodeerd te worden (Home + vluchtdetail tonen 'm allebei).
    private static var geocodeCache: [String: CLLocation] = [:]

    func load(airportName: String?, iata: String?) async {
        guard let query = Self.query(airportName: airportName, iata: iata) else {
            unavailable = true
            return
        }
        isLoading = true
        unavailable = false
        do {
            let location = try await Self.location(for: query)
            let weather = try await WeatherService.shared.weather(for: location, including: .daily)
            let days = weather.forecast.prefix(6).map { day in
                DestinationForecastDay(
                    date: day.date,
                    symbolName: day.symbolName,
                    highCelsius: Int(day.highTemperature.converted(to: .celsius).value.rounded()),
                    lowCelsius: Int(day.lowTemperature.converted(to: .celsius).value.rounded()),
                    precipitationChance: day.precipitationChance
                )
            }
            forecast = DestinationForecast(placeName: airportName ?? iata ?? query, days: Array(days))
        } catch {
            // Geen foutmelding tonen: dit is een leuke bonus-kaart, geen
            // kernfunctie — bij een mislukte geocode/WeatherKit-call
            // verbergen we de kaart gewoon stil.
            unavailable = true
        }
        isLoading = false
    }

    private static func query(airportName: String?, iata: String?) -> String? {
        if let name = airportName, !name.isEmpty { return name }
        if let iata, !iata.isEmpty { return iata }
        return nil
    }

    private static func location(for query: String) async throws -> CLLocation {
        if let cached = geocodeCache[query] { return cached }
        let placemarks = try await CLGeocoder().geocodeAddressString(query)
        guard let location = placemarks.first?.location else { throw URLError(.badURL) }
        geocodeCache[query] = location
        return location
    }
}

/// Compacte kaart met het pakadvies + een paar dagen vooruit, in dezelfde
/// kaartstijl als de rest van de vluchtdetailpagina.
struct DestinationWeatherCard: View {
    let airportName: String?
    let iata: String?
    /// Aankomstdatum (uit de vlucht) — als die binnen de voorspelling valt,
    /// lichten we precies díe dag uit als "Bij aankomst".
    var arrivalDate: Date? = nil

    @StateObject private var store = DestinationWeatherStore()

    private var loadKey: String { "\(airportName ?? "")|\(iata ?? "")" }

    /// De voorspellingsdag die samenvalt met de aankomstdatum, indien bekend
    /// én binnen bereik van WeatherKit (± tien dagen).
    private func arrivalDay(_ forecast: DestinationForecast) -> DestinationForecastDay? {
        guard let arrivalDate else { return nil }
        let cal = Calendar.current
        return forecast.days.first { cal.isDate($0.date, inSameDayAs: arrivalDate) }
    }

    var body: some View {
        Group {
            if let forecast = store.forecast {
                content(forecast)
            } else if store.isLoading {
                loadingState
            }
            // `unavailable`: kaart blijft gewoon weg, geen foutmelding.
        }
        .task(id: loadKey) {
            await store.load(airportName: airportName, iata: iata)
        }
    }

    private func content(_ forecast: DestinationForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cloud.sun.fill")
                    .foregroundStyle(Theme.sky)
                Text("Weer op je bestemming")
                    .font(.frutiger(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(forecast.placeName)
                    .font(.frutiger(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            if let arrival = arrivalDay(forecast) {
                arrivalHighlight(arrival)
            } else if let hint = forecast.packingHint {
                Text(hint)
                    .font(.frutiger(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(forecast.days) { day in
                        dayColumn(day, isArrival: arrivalDay(forecast)?.id == day.id)
                    }
                }
            }

            Text("Voorspelling, kan nog wijzigen.")
                .font(.frutiger(size: 10))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
        }
        .padding(Theme.Spacing.base)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    /// Uitgelichte regel voor de aankomstdag: precies het weer dat je bij
    /// landing kunt verwachten, met een pakadvies toegespitst op díe dag.
    private func arrivalHighlight(_ day: DestinationForecastDay) -> some View {
        HStack(spacing: 12) {
            Image(systemName: day.symbolName)
                .font(.system(size: 26))
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bij aankomst (\(fullDateLabel(day.date)))")
                    .font(.frutiger(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(day.highCelsius)° / \(day.lowCelsius)°" + (day.precipitationChance >= 0.4 ? " · kans op regen" : ""))
                    .font(.frutiger(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.sky.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func dayColumn(_ day: DestinationForecastDay, isArrival: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(weekdayLabel(day.date))
                .font(.frutiger(size: 10, weight: .semibold))
                .foregroundStyle(isArrival ? Theme.navy : Theme.textSecondary)
            Image(systemName: day.symbolName)
                .font(.system(size: 18))
                .foregroundStyle(Theme.sky)
                .symbolRenderingMode(.multicolor)
            Text("\(day.highCelsius)°")
                .font(.frutiger(size: 13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("\(day.lowCelsius)°")
                .font(.frutiger(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(width: 44)
        .padding(.vertical, Theme.Spacing.xs)
        .background(isArrival ? Theme.navy.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private func fullDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EEEE d MMM"
        return f.string(from: date)
    }

    private func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Theme.sky)
            Text("Weer op je bestemming ophalen…")
                .font(.frutiger(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}
