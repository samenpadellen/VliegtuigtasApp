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
            scheduleTripReminders()
            scheduleFirstWeekNudges()
            scheduleBucketListNudge()
        }
    }

    /// Vraagt éénmalig om échte (niet-provisional) toestemming, op het moment
    /// dat de app zich net bewezen heeft: direct na de eerste geslaagde
    /// tas-check.
    ///
    /// Waarom dit nodig is: `refresh()` vraagt bewust `provisional`
    /// toestemming, en die meldingen komen stil in het Berichtencentrum —
    /// geen banner, geen geluid, geen badge. Wie nooit een vlucht opslaat
    /// (en dat is het gros van de nieuwe gebruikers) kreeg dus letterlijk
    /// nooit een zichtbare melding van de app. Dat is dodelijk voor de
    /// retentie in de eerste week.
    static func promoteToVisibleNotifications() {
        let defaults = UserDefaults.standard
        let key = "vt_asked_full_notifications"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Eerste week

    /// De eerste week is precies het venster waarin de app niets van zich liet
    /// horen: de inactiviteits-nudge stond op 21 dagen, en vlucht- en
    /// reisherinneringen bestaan alleen als je iets hebt opgeslagen. Wie de app
    /// gebruikte zoals bedoeld — één tas checken — hoorde dus nooit meer iets.
    ///
    /// Deze reeks loopt alleen zolang er niets is om op af te tellen, en wordt
    /// bij elke app-start opnieuw opgebouwd. Zodra er een vlucht of reis in
    /// staat, verdwijnt hij: dan nemen de echte herinneringen het over.
    private static func scheduleFirstWeekNudges() {
        let ids = ["vt_week1_d1", "vt_week1_d3", "vt_week1_d6"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)

        Task { @MainActor in
            // Center hier aanmaken in plaats van vangen: UNUserNotificationCenter
            // is niet Sendable, en vangen levert een concurrency-waarschuwing op
            // die onder Swift 6 een fout wordt.
            let center = UNUserNotificationCenter.current()
            let hasSomethingPlanned =
                !FlightsStore.shared.flights.isEmpty || !TripsStore.shared.trips.isEmpty
            guard !hasSomethingPlanned else { return }

            func add(id: String, afterDays: Int, hour: Int, title: String, body: String) {
                guard let day = Calendar.current.date(byAdding: .day, value: afterDays, to: .now)
                else { return }
                var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
                components.hour = hour
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                center.add(UNNotificationRequest(
                    identifier: id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }

            add(id: ids[0], afterDays: 1, hour: 18,
                title: "Wanneer vlieg je? ✈️",
                body: "Zet je vlucht in de app: je krijgt een aftelling en een seintje bij een gatewijziging of vertraging.")

            add(id: ids[1], afterDays: 3, hour: 19,
                title: "Bewaar je koffermaten 🧳",
                body: "Eén keer opmeten en je checkt hem daarna bij elke maatschappij in één tik.")

            add(id: ids[2], afterDays: 6, hour: 11,
                title: "Al iets in gedachten? 🌍",
                body: "Plan je reis en je paklijst staat binnen een minuut klaar, afgestemd op je bestemming.")
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

    // MARK: - Bucket list als jaarrond-haakje

    /// Bagage checken is eenmalig per reis; "waar wil ik nog heen" is
    /// altijd relevant, het hele jaar door. Dit is dan ook geen op-de-reis
    /// gerichte melding zoals de rest van dit bestand, maar een persoonlijke
    /// nudge die — net als `scheduleInactivityNudge` — bij elke app-start
    /// meeschuift en dus alleen afgaat als je écht wegblijft.
    ///
    /// Verschijnt niet als er al een vlucht of reis gepland staat: dan is er
    /// al genoeg aandacht via de trip/vlucht-herinneringen hierboven. Wie wél
    /// landen op de bucket list heeft krijgt een melding met een concreet
    /// land erin (persoonlijker dan een generieke "kom terug"-tekst); wie nog
    /// geen enkel land heeft aangevinkt krijgt een duwtje om daar juist mee
    /// te beginnen — dát is de laagdrempelige vervolgstap na de eerste
    /// tas-check, niet nóg een bagagecheck.
    private static func scheduleBucketListNudge() {
        let center = UNUserNotificationCenter.current()
        let ids = ["vt_bucketlist_nudge", "vt_bucketlist_empty_nudge"]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            guard FlightsStore.shared.flights.isEmpty, TripsStore.shared.trips.isEmpty else { return }

            let store = BucketListStore.shared
            let wantToVisit = allCountries.filter { store.status(for: $0) == .wantToVisit }

            func add(id: String, title: String, body: String) {
                guard let day = Calendar.current.date(byAdding: .day, value: 9, to: .now) else { return }
                var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
                components.hour = 18
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                center.add(UNNotificationRequest(
                    identifier: id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }

            if let country = wantToVisit.randomElement() {
                add(
                    id: ids[0],
                    title: "Nog steeds naar \(country.name)? \(country.flagEmoji)",
                    body: "Die staat al op je bucket list. Kijk of er binnenkort een goede periode voor is."
                )
            } else if store.visitedCount == 0 {
                add(
                    id: ids[1],
                    title: "Waar wil je nog heen? 🌍",
                    body: "Vink landen af op je bucket list — in twee tikken zie je hoeveel van de wereld je al hebt gezien."
                )
            }
        }
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

    // MARK: - Trip-aware pak-herinneringen

    /// Automatische, idempotente herinneringen per aankomende reis (i.p.v.
    /// het handmatige, one-shot alarm in PackingAlarmsSheet): 3 dagen en 1
    /// dag vóór vertrek, met de actuele paklijst-voortgang in de tekst.
    /// Reizen worden aangemaakt/verwijderd, dus — anders dan de vaste
    /// vakantie-slugs — moeten eerst alle oude "vt_trip_*"-ids opgezocht en
    /// verwijderd worden vóór opnieuw plannen.
    private static func scheduleTripReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let staleIds = requests.map(\.identifier).filter { $0.hasPrefix("vt_trip_") }

            Task { @MainActor in
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: staleIds)
                for trip in TripsStore.shared.upcoming.prefix(5) {
                    scheduleReminders(for: trip, in: center)
                }
                // Verborgen reizen kregen tot nu toe géén herinnering, omdat
                // `upcoming` ze wegfiltert. Voor een verrassingsreis wil je wél
                // op tijd gaan pakken — alleen mag de melding niets verraden
                // aan wie over je schouder meekijkt.
                for trip in TripsStore.shared.hidden.filter({ !$0.isPast }).prefix(5) {
                    scheduleDiscreetReminders(for: trip, in: center)
                }
            }
        }
    }

    /// Herinnering voor een verborgen reis: zelfde momenten, maar zonder naam,
    /// bestemming of aantal items op het scherm van een vergrendelde telefoon.
    @MainActor
    private static func scheduleDiscreetReminders(for trip: Trip, in center: UNUserNotificationCenter) {
        func add(id: String, offset: TimeInterval, body: String) {
            let fireDate = trip.startDate.addingTimeInterval(offset)
            guard fireDate > .now else { return }
            let content = UNMutableNotificationContent()
            content.title = "Vliegtuigtas"
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

        add(id: "vt_trip_\(trip.id.uuidString)_3d", offset: -3 * 24 * 3600,
            body: "Je hebt over 3 dagen iets staan. Open de app om verder te pakken.")
        add(id: "vt_trip_\(trip.id.uuidString)_1d", offset: -24 * 3600,
            body: "Morgen is het zover. Open de app voor je paklijst.")
    }

    @MainActor
    private static func scheduleReminders(for trip: Trip, in center: UNUserNotificationCenter) {
        let progress = trip.progress
        let remaining = progress.total - progress.checked

        func add(id: String, offset: TimeInterval, title: String, body: String) {
            let fireDate = trip.startDate.addingTimeInterval(offset)
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

        let packedBody = "Alles ingepakt voor \(trip.name). Goede reis!"
        let openBody = remaining > 0
            ? "Nog \(remaining) van de \(progress.total) items niet ingepakt voor \(trip.name)."
            : packedBody

        add(
            id: "vt_trip_\(trip.id.uuidString)_3d", offset: -3 * 24 * 3600,
            title: "Nog 3 dagen tot \(trip.name) 🧳",
            body: remaining > 0 ? openBody + " Tijd om verder te pakken!" : packedBody
        )
        add(
            id: "vt_trip_\(trip.id.uuidString)_1d", offset: -24 * 3600,
            title: "Morgen vertrek: \(trip.name) ✈️",
            body: remaining > 0 ? openBody + " Check je paklijst voor je vertrekt." : packedBody
        )
    }
}
