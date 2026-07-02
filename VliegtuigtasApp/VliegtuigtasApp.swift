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
            RootView()
                .environmentObject(session)
                .onAppear { soundPlayer.play() }
        }
    }
}

private struct RootView: View {
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
                SplashView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: session.isOnboarded)
    }
}

// MARK: - Startup sound

private final class StartupSoundPlayer {
    private var player: AVAudioPlayer?

    func play() {
        guard let url = Bundle.main.url(forResource: "airplane_beep", withExtension: "mp3") else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let p = try AVAudioPlayer(contentsOf: url)
                p.volume = 0.7
                p.play()
                DispatchQueue.main.async { self.player = p }
            } catch {
                // Geluid is optioneel — app werkt gewoon door als het niet lukt
            }
        }
    }
}
