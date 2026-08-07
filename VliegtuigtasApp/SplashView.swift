import SwiftUI
import UIKit

/// Startscherm: bewust minimaal. Eén icoon dat rustig in beeld komt op de
/// merkkleur, en meteen weer weg. Geen animatie om naar te kijken — een splash
/// hoort de app te openen, niet te vertragen.
///
/// Het launchscreen heeft dezelfde achtergrondkleur (zie UILaunchScreen in
/// Info.plist), zodat de opstart één doorlopend beeld is zonder witte flits.
struct SplashView: View {
    /// Vuurt zodra het app-icoon volledig in beeld staat (na de fade-in) —
    /// hét moment voor het vliegtuiggeluid, samen met de haptic.
    var onIconVisible: () -> Void = {}
    let onFinished: () -> Void

    /// Respecteert "Verminder bewegingen": dan alleen een fade, geen schaal.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var iconScale:   CGFloat = 0.94
    @State private var iconOpacity: Double  = 0
    @State private var exitOpacity: Double  = 1

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 10)
                .scaleEffect(reduceMotion ? 1 : iconScale)
                .opacity(iconOpacity)
        }
        .opacity(exitOpacity)
        .onAppear { startAnimatie() }
    }

    private func startAnimatie() {
        withAnimation(.easeOut(duration: reduceMotion ? 0.3 : 0.45)) {
            iconOpacity = 1
            iconScale   = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
            // Geluid exact op het moment dat het icoon staat.
            onIconVisible()
        }

        withAnimation(.easeInOut(duration: 0.3).delay(0.8)) {
            exitOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            onFinished()
        }
    }
}
