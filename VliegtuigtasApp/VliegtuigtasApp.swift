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

    // Gehouden als property zodat ARC de player niet meteen dealloct
    private let soundPlayer = StartupSoundPlayer()

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
                    // Slimme notificaties: inactiviteit + schoolvakanties
                    // (stille provisional-toestemming, geen popup).
                    NotificationPlanner.refresh()
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
