import SwiftUI

/// tvOS is bewust een tweede scherm, geen tweede app: één ambient
/// "vertrekbord" met wat voor jóu relevant is (je eerstvolgende reis/vlucht,
/// en de bagageregel van die maatschappij), zonder menu's of navigatie om
/// doorheen te klikken met een Siri Remote. Puur kijken, niets te bedienen.
struct TVBoardView: View {
    @EnvironmentObject private var airlineStore: AirlineStore
    @ObservedObject private var savedData = TVSavedData.shared

    private var matchedAirline: Airline? {
        guard let slug = savedData.nextFlight?.airlineSlug else { return nil }
        return airlineStore.airlines.first { $0.slug == slug }
    }

    var body: some View {
        ZStack {
            TVTheme.inkGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Rectangle()
                        .fill(TVTheme.yellow)
                        .frame(height: 3)
                        .padding(.top, 24)

                    Spacer(minLength: 0)

                    if savedData.nextTrip != nil || savedData.nextFlight != nil {
                        boardPanel
                    } else {
                        emptyState
                    }

                    Spacer(minLength: 0)
                    footer
                }
                .padding(60)
                .frame(maxHeight: .infinity)

                // Bewust vol-breed, buiten de safe-area-padding hierboven —
                // net als op een echt vertrekbord/nieuwszender loopt dit lint
                // helemaal van rand tot rand.
                PimTickerView(trip: savedData.nextTrip, flight: savedData.nextFlight)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            savedData.start()
            await airlineStore.load()
        }
    }

    // MARK: - Kop

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 14) {
                Image(systemName: "suitcase.rolling.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(TVTheme.yellow)
                Text("VLIEGTUIGTAS")
                    .font(.frutiger(size: 34, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(.white)
            }
            Spacer()
            TVFlapClock()
        }
    }

    // MARK: - Hoofdpaneel: jouw eerstvolgende reis/vlucht

    private var boardPanel: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text(destinationTitle)
                    .font(.frutiger(size: 72, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(countdownLabel.uppercased())
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(TVTheme.yellow)
            }

            if let flight = savedData.nextFlight {
                routeRow(flight)
            }

            if let airline = matchedAirline {
                baggageRule(for: airline)
            }
        }
    }

    private var destinationTitle: String {
        if let trip = savedData.nextTrip, let destination = trip.destination, !destination.isEmpty {
            return destination
        }
        if let trip = savedData.nextTrip { return trip.name }
        if let flight = savedData.nextFlight {
            return flight.arrivalAirport ?? "Vlucht \(flight.number)"
        }
        return ""
    }

    private var countdownLabel: String {
        // Reis (dagen) weegt zwaarder dan een losse vlucht — die staat er
        // vaak toch al bij als onderdeel van dezelfde reis.
        if let trip = savedData.nextTrip {
            switch trip.daysUntilStart {
            case ..<0: return "Onderweg"
            case 0:    return "Vandaag"
            case 1:    return "Morgen"
            default:   return "Nog \(trip.daysUntilStart) dagen"
            }
        }
        if let flight = savedData.nextFlight {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: .now),
                to: Calendar.current.startOfDay(for: flight.departure)
            ).day ?? 0
            switch days {
            case ..<0: return "Onderweg"
            case 0:    return "Vandaag"
            case 1:    return "Morgen"
            default:   return "Nog \(days) dagen"
            }
        }
        return ""
    }

    private func routeRow(_ flight: TVFlight) -> some View {
        HStack(spacing: 20) {
            routeStop(iata: flight.departureIata, name: flight.departureAirport)
            Image(systemName: "airplane")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
            routeStop(iata: flight.arrivalIata, name: flight.arrivalAirport)

            Text("VLUCHT \(flight.number.uppercased())")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(TVTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TVTheme.yellow, in: Capsule())
                .padding(.leading, 12)
        }
    }

    private func routeStop(iata: String?, name: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(iata ?? "—")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            if let name {
                Text(name)
                    .font(.frutiger(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
    }

    /// De gepersonaliseerde kern: niet alle maatschappijen om doorheen te
    /// klikken, maar precies die van jouw opgeslagen vlucht.
    private func baggageRule(for airline: Airline) -> some View {
        let variant = airline.variants?.first { $0.includesLargeBag == true } ?? airline.variants?.first
        return HStack(spacing: 16) {
            Text(airline.flagEmoji ?? "✈️")
                .font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text("Handbagage bij \(airline.name)")
                    .font(.frutiger(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    if let dims = variant?.smallDimString {
                        Text(dims)
                    }
                    if let kg = variant?.maxWeightKg {
                        Text("max. \(Int(kg)) kg")
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(20)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Lege staat

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TVTheme.yellow)
            Text("Nog geen reis gepland")
                .font(.frutiger(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text("Open Vliegtuigtas op je iPhone om een vlucht of reis te bewaren — die verschijnt dan hier.")
                .font(.frutiger(size: 16))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Voet

    private var footer: some View {
        Text("Bijgewerkt om \(Self.timeFormatter.string(from: savedData.lastUpdated))")
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "HH:mm"
        return f
    }()
}

/// Eigen, kleine kleurenset i.p.v. Theme.swift: die leunt op iOS-only
/// systeemkleuren (Color(.systemBackground) e.d.) die op tvOS niet bestaan.
/// Zelfde merkkleuren (ink/geel), gewoon vast in plaats van adaptief.
enum TVTheme {
    static let ink = Color(red: 0.04, green: 0.06, blue: 0.12)
    static let yellow = Color(red: 0.99, green: 0.80, blue: 0.10)
    static let inkGradient = LinearGradient(
        colors: [Color(red: 0.07, green: 0.10, blue: 0.19), ink],
        startPoint: .top, endPoint: .bottom
    )
}
