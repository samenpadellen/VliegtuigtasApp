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
    static let yellow   = Color(red: 0.99, green: 0.80, blue: 0.10)
    static let green    = Color(red: 0.18, green: 0.73, blue: 0.45)

    static let navyGradient = LinearGradient(
        colors: [navy, navyDark], startPoint: .topLeading, endPoint: .bottomTrailing
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

private struct LockScreenView: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LATheme.yellow)
                Text(context.attributes.flightNumber)
                    .font(.frutiger(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                if let route = context.attributes.routeLabel {
                    Text("· \(route)")
                        .font(.frutiger(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                } else if let airline = context.attributes.airlineName {
                    Text("· \(airline)")
                        .font(.frutiger(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(context.state.departure > .now ? "Vertrek over" : "")
                    .font(.frutiger(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                CountdownText(context: context)
                    .font(.frutiger(size: 28, weight: .black))
                    .foregroundStyle(.white)
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

            ReminderLine(context: context)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(14)
        .activityBackgroundTint(LATheme.navyDark)
        .activitySystemActionForegroundColor(.white)
        .background(LATheme.navyGradient)
    }
}
#endif
