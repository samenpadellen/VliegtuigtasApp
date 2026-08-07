import Foundation
import UIKit
import WidgetKit

/// iCloud-sync via NSUbiquitousKeyValueStore: jouw ingevoerde gegevens
/// (naam, e-mail, tasmaten, opgeslagen vlucht) reizen automatisch mee naar
/// je andere Apple-apparaten — zonder apart account of login.
///
/// Ontwerp:
/// - Per domein (profiel / tasmaten / vlucht) reist een tijdstempel mee.
///   Bij een externe wijziging wordt alleen overgenomen als de cloud-versie
///   nieuwer is dan wat dit toestel voor het laatst zag — de nieuwste
///   wijziging wint, ongeacht welk apparaat hem deed.
/// - Uitloggen en "vlucht verwijderen" zijn expliciete states (lege waarde
///   + nieuw stempel), zodat ze óók naar andere apparaten propageren.
/// - Adopt-schrijfacties raken alleen lokale opslag; alleen echte
///   gebruikersacties schrijven naar iCloud. Zo ontstaat er nooit een
///   schrijf-pingpong tussen apparaten.
final class CloudSync {
    static let shared = CloudSync()

    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard

    private enum Key {
        static let firstName  = "vt_first_name"
        static let email      = "vt_email"
        static let onboarded  = "vt_onboarded"

        static let passportExpiry = "vt_passport_expiry"

        static let bagLength  = "vt_bag_length"
        static let bagWidth   = "vt_bag_width"
        static let bagDepth   = "vt_bag_depth"
        static let bagWeight  = "vt_bag_weight"

        static let flightNumber    = "vt_shared_flight_number"
        static let flightAirline   = "vt_shared_flight_airline"
        static let flightSlug      = "vt_shared_flight_slug"
        static let flightDeparture = "vt_shared_flight_departure"
        static let flightDepIata   = "vt_shared_flight_dep_iata"
        static let flightDepName   = "vt_shared_flight_dep_name"
        static let flightArrIata   = "vt_shared_flight_arr_iata"
        static let flightArrName   = "vt_shared_flight_arr_name"
    }

    /// Sync-domein met eigen tijdstempel in de cloud én lokaal
    /// ("welke cloud-versie heeft dit toestel al verwerkt?").
    private enum Domain: String, CaseIterable {
        case user, bag, flight, bagList, flightList, tripList, bucketList, passport

        var cloudStampKey: String { "vt_stamp_\(rawValue)" }
        var localStampKey: String { "vt_seen_stamp_\(rawValue)" }
    }

    private var started = false

    private init() {}

    // MARK: - Levenscyclus

    /// Idempotent: onAppear kan meermaals vuren (scene sluit/heropent op
    /// iPad/Mac) — zonder guard stapelen de observers zich op en draait
    /// elke adoptie dubbel.
    func start() {
        guard !started else {
            cloud.synchronize()
            DispatchQueue.main.async { self.adoptFromCloud() }
            return
        }
        started = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudChangedExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        // Bij terugkeren naar de voorgrond expliciet syncen: het systeem
        // synct KVS zelf, maar dit verkort de wachttijd merkbaar.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        cloud.synchronize()
        DispatchQueue.main.async { self.adoptFromCloud() }
    }

    @objc private func appWillEnterForeground() {
        cloud.synchronize()
        DispatchQueue.main.async { self.adoptFromCloud() }
    }

    @objc private func cloudChangedExternally(_ note: Notification) {
        let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int

        DispatchQueue.main.async {
            if reason == NSUbiquitousKeyValueStoreAccountChange {
                // Ander iCloud-account: alles van dit account is leidend.
                // Lokale "al gezien"-stempels resetten zodat de nieuwe
                // clouddata gegarandeerd wordt overgenomen.
                for domain in Domain.allCases {
                    self.defaults.removeObject(forKey: domain.localStampKey)
                }
            }
            self.adoptFromCloud()
        }
    }

    // MARK: - Tijdstempels

    private func stamp(_ domain: Domain) {
        let now = Date().timeIntervalSince1970
        cloud.set(now, forKey: domain.cloudStampKey)
        defaults.set(now, forKey: domain.localStampKey)
        // Direct naar schijf flushen: zonder synchronize kan een write
        // verloren gaan als de app kort daarna wordt beëindigd (bijv.
        // reminder zetten en meteen wegvegen).
        cloud.synchronize()
    }

    private func cloudIsNewer(_ domain: Domain) -> Bool {
        let cloudStamp = cloud.double(forKey: domain.cloudStampKey)
        guard cloudStamp > 0 else { return false }
        return cloudStamp > defaults.double(forKey: domain.localStampKey) + 0.5
    }

    private func markSeen(_ domain: Domain) {
        defaults.set(cloud.double(forKey: domain.cloudStampKey), forKey: domain.localStampKey)
    }

    // MARK: - Schrijven (gebruikersactie → iCloud)

    /// Profiel bijwerken. Uitloggen = lege waarden + onboarded false;
    /// dat propageert dan ook netjes naar andere apparaten.
    func pushUser(firstName: String, email: String, onboarded: Bool) {
        cloud.set(firstName, forKey: Key.firstName)
        cloud.set(email, forKey: Key.email)
        cloud.set(onboarded, forKey: Key.onboarded)
        stamp(.user)
    }

    /// Laatst gebruikte tasmaten uit de checker.
    func pushBagDims(length: Double, width: Double, depth: Double, weight: Double) {
        defaults.set(length, forKey: Key.bagLength)
        defaults.set(width,  forKey: Key.bagWidth)
        defaults.set(depth,  forKey: Key.bagDepth)
        defaults.set(weight, forKey: Key.bagWeight)
        cloud.set(length, forKey: Key.bagLength)
        cloud.set(width,  forKey: Key.bagWidth)
        cloud.set(depth,  forKey: Key.bagDepth)
        cloud.set(weight, forKey: Key.bagWeight)
        stamp(.bag)
    }

    /// Lokaal bewaarde tasmaten (na adoptie ook de iCloud-versie).
    func savedBagDims() -> (length: Double, width: Double, depth: Double, weight: Double)? {
        guard defaults.object(forKey: Key.bagLength) != nil else { return nil }
        return (
            defaults.double(forKey: Key.bagLength),
            defaults.double(forKey: Key.bagWidth),
            defaults.double(forKey: Key.bagDepth),
            defaults.double(forKey: Key.bagWeight)
        )
    }

    func pushFlight(
        number: String, airlineName: String?, airlineSlug: String?,
        departure: Date, route: SharedFlightStore.Route = .init()
    ) {
        cloud.set(number, forKey: Key.flightNumber)
        cloud.set(airlineName, forKey: Key.flightAirline)
        cloud.set(airlineSlug, forKey: Key.flightSlug)
        cloud.set(departure.timeIntervalSince1970, forKey: Key.flightDeparture)
        cloud.set(route.departureIata, forKey: Key.flightDepIata)
        cloud.set(route.departureAirport, forKey: Key.flightDepName)
        cloud.set(route.arrivalIata, forKey: Key.flightArrIata)
        cloud.set(route.arrivalAirport, forKey: Key.flightArrName)
        stamp(.flight)
    }

    /// "Vlucht verwijderen": expliciet lege state, zodat de verwijdering
    /// ook op andere apparaten aankomt.
    func pushClearedFlight() {
        cloud.set("", forKey: Key.flightNumber)
        for key in [Key.flightAirline, Key.flightSlug, Key.flightDepIata,
                    Key.flightDepName, Key.flightArrIata, Key.flightArrName] {
            cloud.set(nil as String?, forKey: key)
        }
        cloud.set(0.0, forKey: Key.flightDeparture)
        stamp(.flight)
    }

    /// Volledige tassenverzameling (JSON) — gesynct als één blob.
    func pushBagList(_ data: Data) {
        cloud.set(data, forKey: "vt_saved_bags")
        stamp(.bagList)
    }

    func clearBagList() {
        cloud.removeObject(forKey: "vt_saved_bags")
        stamp(.bagList)
    }

    /// Volledige vluchtenlijst (JSON) — gesynct als één blob.
    func pushFlightList(_ data: Data) {
        cloud.set(data, forKey: "vt_saved_flights")
        stamp(.flightList)
    }

    func clearFlightList() {
        cloud.removeObject(forKey: "vt_saved_flights")
        stamp(.flightList)
    }

    /// Volledige reizenlijst (JSON) — gesynct als één blob.
    func pushTripList(_ data: Data) {
        cloud.set(data, forKey: "vt_saved_trips")
        stamp(.tripList)
    }

    func clearTripList() {
        cloud.removeObject(forKey: "vt_saved_trips")
        stamp(.tripList)
    }

    /// Volledige bucket list (JSON, iso2 → status) — gesynct als één blob.
    func pushBucketList(_ data: Data) {
        cloud.set(data, forKey: "vt_bucket_list")
        stamp(.bucketList)
    }

    func clearBucketList() {
        cloud.removeObject(forKey: "vt_bucket_list")
        stamp(.bucketList)
    }

    /// Paspoort-vervaldatum — puur voor de "nog 6 maanden geldig"-check.
    func pushPassportExpiry(_ date: Date?) {
        if let date {
            cloud.set(date.timeIntervalSince1970, forKey: Key.passportExpiry)
        } else {
            cloud.removeObject(forKey: Key.passportExpiry)
        }
        stamp(.passport)
    }

    func clearPassportExpiry() {
        cloud.removeObject(forKey: Key.passportExpiry)
        stamp(.passport)
    }

    /// Uitloggen (zie pushUser): apart benoemd voor leesbaarheid op call sites.
    func clearUser() {
        pushUser(firstName: "", email: "", onboarded: false)
    }

    /// Accountverwijdering: ook de tasmaten lokaal + in iCloud wissen.
    func clearBagDims() {
        for key in [Key.bagLength, Key.bagWidth, Key.bagDepth, Key.bagWeight] {
            defaults.removeObject(forKey: key)
            cloud.removeObject(forKey: key)
        }
        stamp(.bag)
    }

    // MARK: - Overnemen (iCloud → dit toestel, alleen lokaal schrijven)

    private func adoptFromCloud() {
        adoptUser()
        adoptBagDims()
        adoptBagList()
        adoptFlightList()
        adoptTripList()
        adoptBucketList()
        adoptPassportExpiry()
        adoptFlight()
    }

    private func adoptBagList() {
        guard cloudIsNewer(.bagList) else { return }
        if let data = cloud.data(forKey: "vt_saved_bags") {
            Task { @MainActor in
                BagCollectionStore.shared.adopt(data: data)
            }
        }
        markSeen(.bagList)
    }

    private func adoptFlightList() {
        guard cloudIsNewer(.flightList) else { return }
        if let data = cloud.data(forKey: "vt_saved_flights") {
            Task { @MainActor in
                FlightsStore.shared.adopt(data: data)
            }
        }
        markSeen(.flightList)
    }

    private func adoptTripList() {
        guard cloudIsNewer(.tripList) else { return }
        if let data = cloud.data(forKey: "vt_saved_trips") {
            Task { @MainActor in
                TripsStore.shared.adopt(data: data)
            }
        }
        markSeen(.tripList)
    }

    private func adoptBucketList() {
        guard cloudIsNewer(.bucketList) else { return }
        if let data = cloud.data(forKey: "vt_bucket_list") {
            Task { @MainActor in
                BucketListStore.shared.adopt(data: data)
            }
        }
        markSeen(.bucketList)
    }

    private func adoptPassportExpiry() {
        guard cloudIsNewer(.passport) else { return }
        if cloud.object(forKey: Key.passportExpiry) != nil {
            let date = Date(timeIntervalSince1970: cloud.double(forKey: Key.passportExpiry))
            Task { @MainActor in UserSession.shared.adoptPassportExpiry(date) }
        } else {
            Task { @MainActor in UserSession.shared.adoptPassportExpiry(nil) }
        }
        markSeen(.passport)
    }

    private func adoptUser() {
        guard cloudIsNewer(.user) else { return }
        if cloud.bool(forKey: Key.onboarded) {
            UserSession.shared.adoptFromCloud(
                firstName: cloud.string(forKey: Key.firstName) ?? "",
                email: cloud.string(forKey: Key.email) ?? ""
            )
        } else {
            // Op een ander apparaat uitgelogd → hier ook (alleen lokaal).
            UserSession.shared.adoptLogout()
        }
        markSeen(.user)
    }

    private func adoptBagDims() {
        guard cloudIsNewer(.bag), cloud.object(forKey: Key.bagLength) != nil else { return }
        for key in [Key.bagLength, Key.bagWidth, Key.bagDepth, Key.bagWeight] {
            defaults.set(cloud.double(forKey: key), forKey: key)
        }
        markSeen(.bag)
    }

    private func adoptFlight() {
        guard cloudIsNewer(.flight) else { return }
        let number = cloud.string(forKey: Key.flightNumber) ?? ""
        let departureStamp = cloud.double(forKey: Key.flightDeparture)

        if !number.isEmpty, departureStamp > 0 {
            SharedFlightStore.adoptFlight(
                number: number,
                airlineName: cloud.string(forKey: Key.flightAirline),
                airlineSlug: cloud.string(forKey: Key.flightSlug),
                departure: Date(timeIntervalSince1970: departureStamp),
                route: SharedFlightStore.Route(
                    departureIata: cloud.string(forKey: Key.flightDepIata),
                    departureAirport: cloud.string(forKey: Key.flightDepName),
                    arrivalIata: cloud.string(forKey: Key.flightArrIata),
                    arrivalAirport: cloud.string(forKey: Key.flightArrName)
                )
            )
        } else {
            SharedFlightStore.adoptClearedFlight()
        }
        markSeen(.flight)
        Task { @MainActor in
            FlightLiveActivityManager.shared.sync()
        }
    }
}
