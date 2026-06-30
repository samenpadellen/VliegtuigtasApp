import SwiftUI

@main
struct VliegtuigtasApp: App {
    @StateObject private var session = UserSession.shared

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(session)
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
