import Foundation
import EventKit

/// Bewaart reistips en checklist-items uit de app in de Herinneringen-app.
/// Alle EventKit-toegang loopt via deze ene service, zodat de views niets
/// van EKEventStore hoeven te weten.
@MainActor
final class RemindersService: ObservableObject {
    static let shared = RemindersService()

    private let store = EKEventStore()

    /// Naam van de eigen Herinneringen-lijst waarin alles uit de app terechtkomt,
    /// zodat reistips niet verdwijnen tussen de boodschappenlijstjes.
    private let listTitle = "Vliegtuigtas"

    private init() {}

    /// Vraagt (indien nodig) toegang tot Herinneringen. Gebruikt op iOS 17+ de
    /// nieuwe full-access-API en valt daaronder terug op de oude API.
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await store.requestFullAccessToReminders()) ?? false
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Huidige autorisatiestatus voor Herinneringen.
    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    /// Slaat één herinnering op. Vraagt automatisch toegang als dat nog niet
    /// gebeurd is. `dueDate` is optioneel — zonder datum verschijnt het item
    /// gewoon in de standaardlijst zonder alarm.
    /// - Returns: `true` bij succes, `false` als toegang geweigerd is of het
    ///   opslaan mislukt.
    @discardableResult
    func saveReminder(title: String, notes: String? = nil, dueDate: Date? = nil) async -> Bool {
        guard await ensureAccess() else { return false }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = targetCalendar()

        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: dueDate
            )
            let alarm = EKAlarm(absoluteDate: dueDate)
            reminder.addAlarm(alarm)
        }

        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }

    /// Slaat meerdere items in één keer op onder een gedeelde context (bijv.
    /// alle tips van een luchthaven). Elke tip wordt een aparte herinnering.
    /// - Returns: aantal succesvol opgeslagen items.
    @discardableResult
    func saveReminders(titles: [String], notes: String? = nil) async -> Int {
        guard await ensureAccess() else { return 0 }

        let calendar = targetCalendar()
        var saved = 0
        for title in titles {
            let reminder = EKReminder(eventStore: store)
            reminder.title = title
            reminder.notes = notes
            reminder.calendar = calendar
            // Per item committen zou traag zijn; we committen één keer na de lus.
            if (try? store.save(reminder, commit: false)) != nil {
                saved += 1
            }
        }
        try? store.commit()
        return saved
    }

    // MARK: - Eigen "Vliegtuigtas"-lijst

    /// De lijst waarin nieuwe herinneringen komen: de eigen "Vliegtuigtas"-lijst
    /// als die te maken/vinden is, anders de standaardlijst van de gebruiker.
    private func targetCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == listTitle }) {
            return existing
        }
        // Nog niet aanwezig: aanmaken in een geschikte bron.
        guard let source = preferredSource() else {
            return store.defaultCalendarForNewReminders()
        }
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = listTitle
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            // Sommige accounts staan geen nieuwe lijsten toe — val netjes terug.
            return store.defaultCalendarForNewReminders()
        }
    }

    /// Beste bron voor een nieuwe lijst: dezelfde als de standaardlijst (meestal
    /// iCloud), anders een iCloud/CalDAV-bron, anders lokaal.
    private func preferredSource() -> EKSource? {
        if let defaultSource = store.defaultCalendarForNewReminders()?.source {
            return defaultSource
        }
        let sources = store.sources
        if let cloud = sources.first(where: {
            $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud")
        }) {
            return cloud
        }
        return sources.first(where: { $0.sourceType == .local }) ?? sources.first
    }

    /// Accountverwijdering: wist de eigen "Vliegtuigtas"-lijst mét alle
    /// herinneringen erin, echt uit de Herinneringen-app (en dus ook uit
    /// iCloud als dat de bron van die lijst is). Vraagt bewust geen toegang
    /// aan als die nooit gegeven is — er is dan simpelweg niets om te wissen.
    func deleteAllAppReminders() {
        // Zonder toegang geeft calendars(for:) gewoon een lege lijst terug —
        // geen aparte statuscheck nodig en geen ongevraagde toegangsprompt.
        guard let calendar = store.calendars(for: .reminder).first(where: { $0.title == listTitle }) else { return }
        try? store.removeCalendar(calendar, commit: true)
    }

    /// Vraagt toegang op als die nog niet bepaald is; geeft terug of we
    /// uiteindelijk mogen schrijven.
    private func ensureAccess() async -> Bool {
        switch authorizationStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            return await requestAccess()
        default:
            // Op iOS 16 bestaat alleen .authorized; behandel die als toegang.
            if #available(iOS 17.0, *) {
                return false
            } else {
                return authorizationStatus == .authorized
            }
        }
    }
}
