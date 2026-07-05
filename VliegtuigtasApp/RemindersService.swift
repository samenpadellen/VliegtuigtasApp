import Foundation
import EventKit

/// Bewaart reistips en checklist-items uit de app in de Herinneringen-app.
/// Alle EventKit-toegang loopt via deze ene service, zodat de views niets
/// van EKEventStore hoeven te weten.
@MainActor
final class RemindersService: ObservableObject {
    static let shared = RemindersService()

    private let store = EKEventStore()

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
        reminder.calendar = store.defaultCalendarForNewReminders()

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

        var saved = 0
        for title in titles {
            let reminder = EKReminder(eventStore: store)
            reminder.title = title
            reminder.notes = notes
            reminder.calendar = store.defaultCalendarForNewReminders()
            // Per item committen zou traag zijn; we committen één keer na de lus.
            if (try? store.save(reminder, commit: false)) != nil {
                saved += 1
            }
        }
        try? store.commit()
        return saved
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
