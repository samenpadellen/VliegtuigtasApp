import SwiftUI
import AVFoundation
import UIKit

// Herstel swipe-back gebaar ook als navigatiebalk verborgen is
extension UINavigationController {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }
}

@main
struct VliegtuigtasApp: App {
    @StateObject private var session = UserSession.shared
    @Environment(\.scenePhase) private var scenePhase

    // Gehouden als property zodat ARC de player niet meteen dealloct
    private let soundPlayer = StartupSoundPlayer()

    init() {
        // Frutiger als hoofdlettertype registreren vóór de eerste render.
        AppFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView(soundPlayer: soundPlayer)
                .environmentObject(session)
                .onAppear {
                    // TEMP TEST-ONLY: forceer onboarding om te verifiëren — wordt hierna direct teruggedraaid.
                    session.reset()
                    // Alleen voorbereiden: het geluid start pas in SplashView,
                    // op het moment dat het icoon écht in beeld staat.
                    soundPlayer.prepare()
                    // Houd de vertrek-Live Activity in sync met de opgeslagen vlucht.
                    FlightLiveActivityManager.shared.sync()
                    // iCloud key-value sync: profiel, tasmaten en vlucht
                    // reizen mee tussen apparaten, zonder account.
                    CloudSync.shared.start()
                    // Check of een eventuele Sign in with Apple-koppeling nog
                    // geldig is (kan zijn ingetrokken via Instellingen).
                    session.refreshAppleCredentialState()
                    // Slimme notificaties: inactiviteit + schoolvakanties
                    // (stille provisional-toestemming, geen popup).
                    NotificationPlanner.refresh()
                    // Vluchtgegevens actueel houden zonder dat de gebruiker
                    // hoeft te verversen — de wacht bepaalt zelf wat eraan toe
                    // is, dus dit is goedkoop om bij elke start aan te roepen.
                    Task { await FlightWatcher.refreshDueFlights() }
                    #if DEBUG
                    seedDummyDataForTesting()
                    #endif
                }
                // Ook bij terugkeren uit de achtergrond: je opent de app juist
                // op het vliegveld, en dán wil je de actuele gate zien.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await FlightWatcher.refreshDueFlights() }
                }
        }
    }
}

private struct RootView: View {
    let soundPlayer: StartupSoundPlayer
    @EnvironmentObject private var session: UserSession
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // App content
            if session.isOnboarded {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            // Splash bovenop, verdwijnt na animatie
            if showSplash {
                SplashView(
                    onIconVisible: { soundPlayer.play() },
                    onFinished: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: session.isOnboarded)
    }
}

#if DEBUG
/// Tijdelijke testhulp om de tvOS-sync te verifiëren: vult Reizen/
/// Vluchten via het echte opslag- en iCloud-pushpad, precies zoals een
/// gebruiker dat via de wizard zou doen. Alleen actief in Debug-builds.
/// Elk paar wordt onafhankelijk toegevoegd (op vluchtnummer), zodat
/// eerder toegevoegde testdata gewoon blijft staan en dit alleen aanvult.
@MainActor
private func seedDummyDataForTesting() {
    let cal = Calendar.current
    func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: .now) ?? .now }
    func at(_ date: Date, _ hour: Int, _ minute: Int) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    let seeds: [(trip: Trip, flight: SavedFlightRecord)] = [
        (
            Trip(name: "Rome", destination: "Rome, Italië",
                 startDate: days(5), endDate: days(9), luggageType: .both),
            SavedFlightRecord(number: "KL1595", airlineName: "KLM", airlineSlug: "klm",
                               departure: at(days(5), 9, 15),
                               departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                               arrivalIata: "FCO", arrivalAirport: "Rome Fiumicino")
        ),
        (
            Trip(name: "Barcelona", destination: "Barcelona, Spanje",
                 startDate: days(15), endDate: days(19), luggageType: .carryOnOnly),
            SavedFlightRecord(number: "VY8438", airlineName: "Vueling", airlineSlug: "vueling",
                               departure: at(days(15), 7, 40),
                               departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                               arrivalIata: "BCN", arrivalAirport: "Barcelona El Prat")
        ),
        (
            Trip(name: "Lissabon", destination: "Lissabon, Portugal",
                 startDate: days(30), endDate: days(35), luggageType: .both),
            SavedFlightRecord(number: "TP653", airlineName: "TAP Air Portugal", airlineSlug: "tap-air-portugal",
                               departure: at(days(30), 11, 5),
                               departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                               arrivalIata: "LIS", arrivalAirport: "Lissabon Humberto Delgado")
        ),
        (
            Trip(name: "Londen", destination: "Londen, Verenigd Koninkrijk",
                 startDate: days(-20), endDate: days(-16), luggageType: .checkedOnly),
            SavedFlightRecord(number: "BA430", airlineName: "British Airways", airlineSlug: "british-airways",
                               departure: at(days(-20), 8, 30),
                               departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                               arrivalIata: "LHR", arrivalAirport: "Londen Heathrow")
        ),
        (
            Trip(name: "New York", destination: "New York, Verenigde Staten",
                 startDate: days(60), endDate: days(70), luggageType: .both),
            SavedFlightRecord(number: "KL643", airlineName: "KLM", airlineSlug: "klm",
                               departure: at(days(60), 13, 20),
                               departureIata: "AMS", departureAirport: "Amsterdam Schiphol",
                               arrivalIata: "JFK", arrivalAirport: "New York JFK")
        )
    ]

    for seed in seeds {
        if !TripsStore.shared.trips.contains(where: { $0.name == seed.trip.name }) {
            TripsStore.shared.upsert(seed.trip)
        }
        if !FlightsStore.shared.flights.contains(where: { $0.number == seed.flight.number }) {
            FlightsStore.shared.upsert(seed.flight)
        }
    }
}
#endif

// MARK: - Startup sound

final class StartupSoundPlayer {
    private var player: AVAudioPlayer?
    private var prepared = false

    /// Laadt de audio alvast (off-main), zodat `play()` later zonder
    /// vertraging kan starten — precies op het beeldmoment.
    func prepare() {
        guard !prepared else { return }
        prepared = true
        guard let url = Bundle.main.url(forResource: "airplane_beep", withExtension: "mp3") else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let p = try AVAudioPlayer(contentsOf: url)
                p.volume = 0.525   // 25% zachter dan de oude 0.7
                p.prepareToPlay()
                DispatchQueue.main.async { self.player = p }
            } catch {
                // Geluid is optioneel — app werkt gewoon door als het niet lukt
            }
        }
    }

    func play() {
        player?.play()
    }
}
