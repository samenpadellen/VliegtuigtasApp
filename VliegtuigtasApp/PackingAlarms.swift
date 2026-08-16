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

// MARK: - Pims alarmschema

/// Laat Pim een voorbereidingsschema voorstellen op basis van de reis, en geeft
/// dat terug als dagen-voor-vertrek. De gebruiker beslist: pas na "Neem over"
/// verschuiven de datums, en daarna is elk moment nog los aan te passen.
@available(iOS 26.0, *)
private struct PimAlarmAdviesSheet: View {
    let trip: Trip
    let onApply: (AlarmAdvies) -> Void

    @StateObject private var model = AlarmAdviesModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isLoading {
                        VStack(spacing: 12) {
                            ProgressView().tint(Theme.sky)
                            Text("Pim bekijkt je reis…")
                                .font(.frutiger(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xl)
                    } else if let advies = model.advies {
                        Text(advies.toelichting)
                            .font(.frutiger(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 0) {
                            adviceRow("Nieuwe koffer kopen", days: advies.dagenVoorKoffer)
                            Divider()
                            adviceRow("Koffer controleren", days: advies.dagenVoorCheck)
                            Divider()
                            adviceRow("Inpakken", days: advies.dagenVoorInpakken)
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                        Button {
                            onApply(advies)
                            dismiss()
                        } label: {
                            Text("Neem dit schema over")
                                .font(.frutiger(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.inkGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        }
                        .buttonStyle(.plain)

                        Text("Voorgesteld op je toestel met Apple Intelligence. Je kunt elk moment daarna nog aanpassen.")
                            .font(.frutiger(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    } else if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.red)
                            .padding(.top, Theme.Spacing.xl)
                    }
                }
                .padding(Theme.Spacing.base)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pims schema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
            .task {
                await model.generate(
                    days: trip.days,
                    destination: trip.destination ?? trip.name,
                    style: trip.style?.label,
                    luggage: trip.luggageType.label
                )
            }
        }
    }

    private func adviceRow(_ title: String, days: Int) -> some View {
        HStack {
            Text(title)
                .font(.frutiger(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(days == 1 ? "1 dag vooraf" : "\(days) dagen vooraf")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.yellow, in: Capsule())
        }
        .padding(Theme.Spacing.md)
    }
}

// MARK: - Sheet

/// Inpak-alarmen: vier reismomenten met een voorgestelde tijd (relatief aan
/// je vlucht of, zonder vluchtnummer, aan je geplande reis) die je per stuk
/// aanpast en zet.
struct PackingAlarmsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var dates: [PackingAlarmKind: Date] = [:]
    @State private var setResults: [PackingAlarmKind: PackingAlarmScheduler.Result] = [:]
    @State private var showPimAdvies = false

    /// Waar de voorgestelde tijden vandaan komen. Een opgeslagen vlucht is het
    /// nauwkeurigst, maar heb je alleen een reis gepland (zonder vluchtnummer),
    /// dan is de vertrekdatum van die reis veel bruikbaarder dan "morgen" —
    /// tot 3.0.0 viel de sheet in dat geval terug op vandaag + 1 dag, waardoor
    /// alle alarmen op de verkeerde week stonden.
    private var referenceTrip: Trip? { TripsStore.shared.next }
    private var departure: Date? {
        SharedFlightStore.loadFlight()?.departure ?? referenceTrip?.startDate
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(introText)
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    pimAdviceButton

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
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.lg)
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

    /// Legt uit waar de voorgestelde tijden op gebaseerd zijn — vlucht, reis,
    /// of niets van beide.
    private var introText: String {
        if SharedFlightStore.loadFlight()?.departure != nil {
            return "Tijden zijn voorgesteld rond je opgeslagen vlucht. Pas aan en zet per moment een alarm."
        }
        if let trip = referenceTrip {
            return "Geen vluchtnummer, dus we rekenen vanaf het vertrek van je reis \(trip.name). Pas aan en zet per moment een alarm."
        }
        return "Nog geen reis of vlucht opgeslagen: kies zelf de momenten. Plan je een reis, dan stellen we de tijden voor."
    }

    /// Pim stelt een schema voor dat past bij het soort reis: wintersport en
    /// lange reizen vragen meer voorbereiding dan een weekendje weg. Alleen
    /// zinvol als er een reis is om over te redeneren.
    @ViewBuilder
    private var pimAdviceButton: some View {
        if #available(iOS 26.0, *), AIAvailability.isAvailable, let trip = referenceTrip {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPimAdvies = true
            } label: {
                HStack(spacing: 8) {
                    PurserPimCap(size: 20)
                    Text("Laat Pim een schema voorstellen")
                        .font(.frutiger(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.navy)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.md)
                .background(Theme.skyLight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPimAdvies) {
                PimAlarmAdviesSheet(trip: trip) { advies in
                    applyPimAdvies(advies, trip: trip)
                }
                .presentationDetents([.medium])
            }
        }
    }

    /// Zet Pims dagen-voor-vertrek om naar concrete datums op 19:00.
    @available(iOS 26.0, *)
    private func applyPimAdvies(_ advies: AlarmAdvies, trip: Trip) {
        let calendar = Calendar.current
        func date(daysBefore days: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: -days, to: trip.startDate) ?? .now
            var comps = calendar.dateComponents([.year, .month, .day], from: max(base, .now))
            comps.hour = 19
            return calendar.date(from: comps) ?? .now.addingTimeInterval(3600)
        }
        dates[.buyBag]   = date(daysBefore: advies.dagenVoorKoffer)
        dates[.checkBag] = date(daysBefore: advies.dagenVoorCheck)
        dates[.pack]     = date(daysBefore: advies.dagenVoorInpakken)
        dates[.dropOff]  = date(daysBefore: advies.dagenVoorInpakken)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Rustige, zin-gedreven opzet ("Herinner me op ...") met veel lucht per
    /// kaart, i.p.v. een compacte rij — elk moment krijgt zijn eigen adem.
    private func alarmRow(_ kind: PackingAlarmKind) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Theme.yellow.opacity(0.18))
                        Image(systemName: kind.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(.frutiger(size: 16, weight: .bold))
                        Text(kind.subtitle)
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }

                if let result = setResults[kind] {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.green)
                        Text(result == .alarm ? "Alarm gezet" : "Herinnering gezet")
                            .font(.frutiger(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Spacing.md)
                    .padding(.horizontal, Theme.Spacing.md)
                    .background(Theme.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                } else {
                    HStack(spacing: 8) {
                        Text("Herinner me op")
                            .font(.frutiger(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                        DatePicker(
                            "",
                            selection: binding(for: kind),
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Theme.navy)
                        Spacer()
                    }

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
                            .font(.frutiger(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(Theme.inkGradient)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.base)
        }
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
        .padding(.top, Theme.Spacing.xs)
    }
}
