import Foundation
import UserNotifications

/// Slimme lokale notificaties: inactiviteit, naderende trip en Nederlandse
/// schoolvakanties. Gebruikt `provisional`-toestemming: meldingen komen stil
/// binnen in het Berichtencentrum zonder permissie-popup; pas als de
/// gebruiker er iets mee doet vraagt iOS of ze prominent mogen worden.
enum NotificationPlanner {

    // MARK: - Opstart

    /// Bij elke app-start aanroepen: ververst de inactiviteits-nudge en de
    /// vakantieplanning (idempotent, vaste identifiers).
    static func refresh() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .provisional]) { granted, _ in
            guard granted else { return }
            scheduleInactivityNudge()
            scheduleVacationNudges()
        }
    }

    // MARK: - Inactiviteit

    /// Eén reminder, 21 dagen na het laatste app-gebruik om 19:00. Elke start
    /// verschuift hem — hij vuurt dus alleen als je écht wegblijft.
    private static func scheduleInactivityNudge() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["vt_inactivity"])

        guard let fireDate = Calendar.current.date(byAdding: .day, value: 21, to: .now) else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 19

        let content = UNMutableNotificationContent()
        content.title = "Al reisplannen? ✈️"
        content.body = "Bagageregels veranderen regelmatig. Check even of jouw tas nog past voordat je boekt."
        content.sound = .default

        center.add(UNNotificationRequest(
            identifier: "vt_inactivity",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }

    // MARK: - Schoolvakanties (NL, 2026)

    private struct Vacation {
        let slug: String
        let name: String
        /// Startdata per regio (noord/midden/zuid); we melden vóór de eerste.
        let regionStarts: [DateComponents]
    }

    private static let vacations2026: [Vacation] = [
        Vacation(slug: "voorjaar", name: "voorjaarsvakantie", regionStarts: [
            .init(year: 2026, month: 2, day: 14), .init(year: 2026, month: 2, day: 21)
        ]),
        Vacation(slug: "mei", name: "meivakantie", regionStarts: [
            .init(year: 2026, month: 4, day: 25)
        ]),
        Vacation(slug: "zomer", name: "zomervakantie", regionStarts: [
            .init(year: 2026, month: 7, day: 4), .init(year: 2026, month: 7, day: 11),
            .init(year: 2026, month: 7, day: 18)
        ]),
        Vacation(slug: "bouwvak", name: "bouwvak", regionStarts: [
            .init(year: 2026, month: 7, day: 18), .init(year: 2026, month: 7, day: 25),
            .init(year: 2026, month: 8, day: 1)
        ]),
        Vacation(slug: "herfst", name: "herfstvakantie", regionStarts: [
            .init(year: 2026, month: 10, day: 10), .init(year: 2026, month: 10, day: 17)
        ]),
        Vacation(slug: "kerst", name: "kerstvakantie", regionStarts: [
            .init(year: 2026, month: 12, day: 19)
        ])
    ]

    /// Tien dagen vóór de eerste (toekomstige) regiostart van elke vakantie,
    /// om 18:00: hét moment waarop mensen gaan pakken en boeken.
    private static func scheduleVacationNudges() {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        center.removePendingNotificationRequests(
            withIdentifiers: vacations2026.map { "vt_vacation_\($0.slug)" }
        )

        for vacation in vacations2026 {
            // Eerste regiostart waarvan het meldmoment (start − 10 dagen)
            // nog in de toekomst ligt.
            guard let fireDate = vacation.regionStarts
                .compactMap({ calendar.date(from: $0) })
                .compactMap({ calendar.date(byAdding: .day, value: -10, to: $0) })
                .filter({ $0 > .now })
                .min()
            else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: fireDate)
            components.hour = 18

            let content = UNMutableNotificationContent()
            content.title = "De \(vacation.name) komt eraan 🧳"
            content.body = "Vlieg je binnenkort? Check nu alvast of je handbagage past, dan sta je nooit voor verrassingen bij de gate."
            content.sound = .default

            center.add(UNNotificationRequest(
                identifier: "vt_vacation_\(vacation.slug)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
    }

    // MARK: - Naderende trip

    /// Reminders rond een opgeslagen vertrek: 1 week, 24 uur en 3 uur vooraf.
    /// Vaste identifiers, dus een nieuwe vlucht vervangt de oude planning.
    static func scheduleFlightReminders(departure: Date, label: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(
                withIdentifiers: ["vt_flight_7d", "vt_flight_24h", "vt_flight_3h"]
            )

            let name = label.isEmpty ? "je vlucht" : label

            func add(id: String, offset: TimeInterval, title: String, body: String) {
                let fireDate = departure.addingTimeInterval(offset)
                guard fireDate > .now else { return }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                center.add(UNNotificationRequest(
                    identifier: id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }

            add(
                id: "vt_flight_7d", offset: -7 * 24 * 3600,
                title: "Nog een week tot vertrek 🧳",
                body: "Over 7 dagen vertrekt \(name). Tijd om je tas te checken en te pakken."
            )
            add(
                id: "vt_flight_24h", offset: -24 * 3600,
                title: "Morgen vertrek ✈️",
                body: "Nog 24 uur tot \(name). Check vandaag of je handbagage past."
            )
            add(
                id: "vt_flight_3h", offset: -3 * 3600,
                title: "Bijna vertrek!",
                body: "Over 3 uur vertrekt \(name). Laatste check van je tas?"
            )
        }
    }
}
