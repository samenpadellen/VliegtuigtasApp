import SwiftUI
import AVFoundation

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

    var body: some View {
        ZStack {
            if session.isOnboarded {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
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
        do {
            // Gebruik ambient categorie zodat het geluid niet de muziek van de gebruiker onderbreekt
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.7
            player?.play()
        } catch {
            // Geluid is optioneel — app werkt gewoon door als het niet lukt
        }
    }
}
