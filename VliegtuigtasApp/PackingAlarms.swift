import SwiftUI
import UserNotifications
#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
import AlarmKit
#endif

// MARK: - Alarmsoorten

/// Belangrijke reismomenten rond je koffer. Standaardtijden zijn relatief
/// aan je opgeslagen vlucht (als die er is).
enum PackingAlarmKind: String, CaseIterable, Identifiable, Sendable {
    case checkBag, buyBag, pack, dropOff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checkBag: return "Koffer controleren"
        case .buyBag:   return "Nieuwe koffer aanschaffen"
        case .pack:     return "Inpakken"
        case .dropOff:  return "Koffer afgeven of ophalen"
        }
    }

    var subtitle: String {
        switch self {
        case .checkBag: return "Past hij nog bij je maatschappij?"
        case .buyBag:   return "Op tijd besteld is op tijd in huis"
        case .pack:     return "De avond ervoor, zonder stress"
        case .dropOff:  return "Bij vrienden, familie of de stomerij"
        }
    }

    var icon: String {
        switch self {
        case .checkBag: return "checkmark.shield.fill"
        case .buyBag:   return "bag.fill"
        case .pack:     return "suitcase.rolling.fill"
        case .dropOff:  return "person.2.fill"
        }
    }

    /// Standaardmoment: t.o.v. het vertrek als er een vlucht is opgeslagen,
    /// anders een redelijk moment vanaf nu. Altijd om 19:00.
    func defaultDate(departure: Date?) -> Date {
        let calendar = Calendar.current
        let base: Date
        if let departure {
            let offsetDays: Int
            switch self {
            case .buyBag:   offsetDays = -14
            case .checkBag: offsetDays = -3
            case .pack:     offsetDays = -1
            case .dropOff:  offsetDays = -1
            }
            base = calendar.date(byAdding: .day, value: offsetDays, to: departure) ?? .now
        } else {
            base = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        }
        var components = calendar.dateComponents([.year, .month, .day], from: max(base, .now))
        components.hour = 19
        return calendar.date(from: components) ?? .now.addingTimeInterval(3600)
    }
}

// MARK: - Plannen (AlarmKit met notificatie-fallback)

enum PackingAlarmScheduler {
    enum Result {
        case alarm          // écht alarm (AlarmKit, doorbreekt stille modus)
        case notification   // fallback: gewone melding
    }

    static func schedule(kind: PackingAlarmKind, at date: Date) async -> Result {
        #if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *) {
            if (try? await scheduleAlarmKit(title: kind.title, at: date)) != nil {
                return .alarm
            }
        }
        #endif
        scheduleNotification(kind: kind, at: date)
        return .notification
    }

    #if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
    /// AlarmKit: een volwaardig alarm zoals de Klok-app — volledig scherm,
    /// hoorbaar óók in stille modus. Precies goed voor "inpakken!".
    @available(iOS 26.0, *)
    private static func scheduleAlarmKit(title: String, at date: Date) async throws {
        struct Metadata: AlarmMetadata {}

        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            _ = try await manager.requestAuthorization()
        }
        guard manager.authorizationState == .authorized else {
            throw CancellationError()
        }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: AlarmButton(
                text: "Klaar",
                textColor: .white,
                systemImageName: "checkmark"
            )
        )
        let attributes = AlarmAttributes<Metadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Color(red: 0.99, green: 0.80, blue: 0.10)
        )
        let configuration = AlarmManager.AlarmConfiguration(
            schedule: .fixed(date),
            attributes: attributes
        )
        _ = try await manager.schedule(id: UUID(), configuration: configuration)
    }
    #endif

    /// Fallback (geen iOS 26 of geen alarm-toestemming): lokale melding.
    private static func scheduleNotification(kind: PackingAlarmKind, at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "\(kind.title) 🧳"
            content.body = kind.subtitle
            content.sound = .default
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
            center.add(UNNotificationRequest(
                identifier: "vt_packing_\(kind.rawValue)_\(Int(date.timeIntervalSince1970))",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
    }
}

// MARK: - Sheet

/// Inpak-alarmen: vier reismomenten met een voorgestelde tijd (relatief aan
/// je vlucht) die je per stuk aanpast en zet.
struct PackingAlarmsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var dates: [PackingAlarmKind: Date] = [:]
    @State private var setResults: [PackingAlarmKind: PackingAlarmScheduler.Result] = [:]
    private let departure = SharedFlightStore.loadFlight()?.departure

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(departure != nil
                         ? "Tijden zijn voorgesteld rond je vertrek. Pas aan en zet per moment een alarm."
                         : "Geen vlucht opgeslagen: kies zelf de momenten. Sla je een vlucht op, dan stellen we de tijden voor.")
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                    ForEach(PackingAlarmKind.allCases) { kind in
                        alarmRow(kind)
                    }

                    if #available(iOS 26.0, *) {
                        footnote("Alarmen gaan af als een echte wekker, ook in stille modus.")
                    } else {
                        footnote("Op dit toestel worden het meldingen; echte alarmen vereisen iOS 26.")
                    }
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Inpak-alarmen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }

    private func alarmRow(_ kind: PackingAlarmKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 38, height: 38)
                    .background(Theme.skyLight)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.title)
                        .font(.frutiger(size: 14, weight: .bold))
                    Text(kind.subtitle)
                        .font(.frutiger(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            HStack {
                DatePicker(
                    "",
                    selection: binding(for: kind),
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()

                Spacer()

                if let result = setResults[kind] {
                    Label(
                        result == .alarm ? "Alarm gezet" : "Herinnering gezet",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.green)
                } else {
                    Button {
                        let date = dates[kind] ?? kind.defaultDate(departure: departure)
                        Task {
                            let result = await PackingAlarmScheduler.schedule(kind: kind, at: date)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            withAnimation(.spring(response: 0.3)) {
                                setResults[kind] = result
                            }
                        }
                    } label: {
                        Label("Zet alarm", systemImage: "alarm.fill")
                            .font(.frutiger(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.navyGradient)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func binding(for kind: PackingAlarmKind) -> Binding<Date> {
        Binding(
            get: { dates[kind] ?? kind.defaultDate(departure: departure) },
            set: { dates[kind] = $0 }
        )
    }

    private func footnote(_ text: String) -> some View {
        Label {
            Text(text)
                .font(.frutiger(size: 11))
                .foregroundStyle(Theme.textSecondary)
        } icon: {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(Theme.sky)
        }
        .padding(.top, 4)
    }
}
