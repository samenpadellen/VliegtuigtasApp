// ActivityKit bestaat niet op Mac Catalyst; hele Live Activity alleen op iOS.
#if !targetEnvironment(macCatalyst)
import WidgetKit
import SwiftUI
import ActivityKit

/// Live Activity: aftelling naar vertrek + tas-reminder, op het
/// toegangsscherm en in het Dynamic Island.
struct FlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            LockScreenView(context: context)
                .widgetURL(context.attributes.deepLink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LATheme.yellow)
                        Text(context.attributes.flightNumber)
                            .font(.frutiger(size: 15, weight: .bold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(context: context)
                        .font(.frutiger(size: 15, weight: .black))
                        .foregroundStyle(LATheme.yellow)
                        .frame(maxWidth: 70)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    if let route = context.attributes.routeLabel {
                        Text(route)
                            .font(.frutiger(size: 13, weight: .bold))
                            .monospacedDigit()
                            .lineLimit(1)
                    } else if let airline = context.attributes.airlineName {
                        Text(airline)
                            .font(.frutiger(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if context.state.departure > .now {
                            ProgressView(timerInterval: departureWindow(for: context), countsDown: true) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .progressViewStyle(.linear)
                            .tint(LATheme.yellow)
                        }
                        ReminderLine(context: context)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.bagChecked ? "checkmark.circle.fill" : "airplane.departure")
                    .foregroundStyle(context.state.bagChecked ? LATheme.green : LATheme.yellow)
            } compactTrailing: {
                CountdownText(context: context)
                    .font(.frutiger(size: 12, weight: .heavy))
                    .foregroundStyle(LATheme.yellow)
                    .frame(maxWidth: 52)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                // Minimal is één cirkel: voortgangsring naar vertrek.
                ProgressView(
                    timerInterval: departureWindow(for: context),
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(LATheme.yellow)
                    }
                )
                .progressViewStyle(.circular)
                .tint(LATheme.yellow)
            }
            .widgetURL(context.attributes.deepLink)
        }
    }
}

/// Venster voor de voortgangsring: de laatste 8 uur vóór vertrek (zelfde
/// window als waarin de activity mag starten).
private func departureWindow(for context: ActivityViewContext<FlightActivityAttributes>) -> ClosedRange<Date> {
    let departure = max(context.state.departure, .now.addingTimeInterval(60))
    return departure.addingTimeInterval(-8 * 3600)...departure
}

// MARK: - Kleuren (extensie is zelfstandig)

private enum LATheme {
    static let navy     = Color(red: 0.00, green: 0.19, blue: 0.53)
    static let navyDark = Color(red: 0.00, green: 0.12, blue: 0.38)
    static let ink      = Color(red: 0.13, green: 0.15, blue: 0.19)
    static let inkDark  = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let yellow   = Color(red: 1.00, green: 0.76, blue: 0.03)
    static let green    = Color(red: 0.18, green: 0.73, blue: 0.45)

    static let navyGradient = LinearGradient(
        colors: [navy, navyDark], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let inkGradient = LinearGradient(
        colors: [ink, inkDark], startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Bouwstenen

/// Live aftellende timer tot vertrek; na vertrek een vaste tekst.
private struct CountdownText: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    var body: some View {
        if context.state.departure > .now {
            Text(timerInterval: Date.now...context.state.departure, countsDown: true)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        } else {
            Text("Vertrokken")
        }
    }
}

private struct ReminderLine: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    private var departed: Bool { context.state.departure <= .now }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: departed ? "airplane" : (context.state.bagChecked ? "checkmark.circle.fill" : "bag.fill"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(context.state.bagChecked || departed ? LATheme.green : LATheme.yellow)
            Text(reminderText)
                .font(.frutiger(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var reminderText: String {
        if departed { return "Goede reis! ✈️" }
        if context.state.bagChecked { return "Tas gecheckt, je bent er klaar voor" }
        return "Nog even je handbagage checken"
    }
}

// MARK: - Lock screen

/// Opzet geïnspireerd op vluchttrackers zoals Flighty: grote route-code +
/// vertrektijd bovenaan, een volle-breedte gekleurde statusbalk onderaan.
/// Toont uitsluitend data die we écht hebben (geen verzonnen gate/terminal —
/// die tracken we niet) — alleen de presentatie is overgenomen.
private struct LockScreenView: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    private var departed: Bool { context.state.departure <= .now }
    private var bagChecked: Bool { context.state.bagChecked }

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LATheme.yellow)
                    Text(context.attributes.flightNumber)
                        .font(.frutiger(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    if let airline = context.attributes.airlineName {
                        Text("· \(airline)")
                            .font(.frutiger(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer()
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let dep = context.attributes.departureIata, let arr = context.attributes.arrivalIata {
                        Text(dep)
                            .font(.frutiger(size: 26, weight: .black))
                            .foregroundStyle(.white)
                        Image(systemName: "airplane")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .rotationEffect(.degrees(90))
                        Text(arr)
                            .font(.frutiger(size: 26, weight: .black))
                            .foregroundStyle(.white)
                    } else {
                        Text(context.attributes.airlineName ?? "Jouw vlucht")
                            .font(.frutiger(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(departed ? "vertrokken" : "vertrek")
                            .font(.frutiger(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(Self.clockFormatter.string(from: context.state.departure))
                            .font(.frutiger(size: 15, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }

                if context.state.departure > .now {
                    // Lineaire voortgang door de laatste 8 uur vóór vertrek.
                    ProgressView(timerInterval: departureWindow(for: context), countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.linear)
                    .tint(LATheme.yellow)
                }
            }
            .padding(14)
            .padding(.bottom, 12)

            statusBar
        }
        .activityBackgroundTint(LATheme.navyDark)
        .activitySystemActionForegroundColor(.white)
        .background(LATheme.inkGradient)
    }

    /// Volle-breedte statusbalk, kleur volgt de bagagestatus — zelfde
    /// visuele taal als de statusbalk in vluchttracker-apps.
    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: departed ? "airplane" : (bagChecked ? "checkmark.circle.fill" : "bag.fill"))
                .font(.system(size: 13, weight: .semibold))
            Text(statusText)
                .font(.frutiger(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if !departed {
                Text(countdownBadge)
                    .font(.frutiger(size: 12, weight: .black))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusForeground.opacity(0.16), in: Capsule())
            }
        }
        .foregroundStyle(statusForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(statusColor)
    }

    /// Geel is te licht voor witte tekst — donkere tekst erop, wit op het
    /// groene "klaar"-vlak.
    private var statusForeground: Color {
        (departed || bagChecked) ? .white : LATheme.inkDark
    }

    private var statusColor: Color {
        (departed || bagChecked) ? LATheme.green : LATheme.yellow
    }

    private var statusText: String {
        if departed { return "Goede reis! ✈️" }
        if bagChecked { return "Tas gecheckt, klaar voor vertrek" }
        return "Nog even je handbagage checken"
    }

    private var countdownBadge: String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: context.state.departure)
        ).day ?? 0
        switch days {
        case 0:  return "VANDAAG"
        case 1:  return "MORGEN"
        default: return "\(days)D"
        }
    }
}
#endif
