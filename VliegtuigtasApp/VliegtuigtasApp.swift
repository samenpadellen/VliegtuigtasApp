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
/// gebruiker dat via de wizard zou doen. Alleen actief in Debug-builds en
/// alleen als de voorbeeldreis er nog niet al staat — bestaande (test)reizen
/// blijven dus gewoon staan, dit voegt alleen toe.
@MainActor
private func seedDummyDataForTesting() {
    let marker = "KL1595"
    guard !FlightsStore.shared.flights.contains(where: { $0.number == marker }) else { return }

    let cal = Calendar.current
    let start = cal.date(byAdding: .day, value: 5, to: .now) ?? .now
    let end = cal.date(byAdding: .day, value: 9, to: .now) ?? .now
    let departure = cal.date(bySettingHour: 9, minute: 15, second: 0, of: start) ?? start

    TripsStore.shared.upsert(Trip(
        name: "Rome",
        destination: "Rome, Italië",
        startDate: start,
        endDate: end,
        luggageType: .both
    ))

    FlightsStore.shared.upsert(SavedFlightRecord(
        number: "KL1595",
        airlineName: "KLM",
        airlineSlug: "klm",
        departure: departure,
        departureIata: "AMS",
        departureAirport: "Amsterdam Schiphol",
        arrivalIata: "FCO",
        arrivalAirport: "Rome Fiumicino"
    ))
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
