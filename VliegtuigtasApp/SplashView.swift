import SwiftUI
import UIKit

struct SplashView: View {
    let onFinished: () -> Void

    // Achtergrond
    @State private var glowOpacity: Double = 0

    // App-icoon
    @State private var iconScale:   CGFloat = 0.82
    @State private var iconOpacity: Double  = 0
    @State private var ringScale:   CGFloat = 0.7
    @State private var ringOpacity: Double  = 0

    // Exit
    @State private var exitOpacity: Double = 1
    @State private var exitScale:   CGFloat = 1

    var body: some View {
        ZStack {
            background
            icon
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .onAppear { startAnimatie() }
    }

    // MARK: - Achtergrond

    private var background: some View {
        ZStack {
            Theme.navyGradient.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.sky.opacity(0.35), .clear],
                center: .center, startRadius: 10, endRadius: 260
            )
            .opacity(glowOpacity)
            .ignoresSafeArea()
        }
    }

    // MARK: - Icoon

    private var icon: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1.5)
                .frame(width: 148, height: 148)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 12)
        }
        .scaleEffect(iconScale)
        .opacity(iconOpacity)
    }

    // MARK: - Animatie

    private func startAnimatie() {
        withAnimation(.easeOut(duration: 0.9)) {
            glowOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.55)) {
            iconOpacity = 1
            iconScale   = 1.0
        }

        withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
            ringOpacity = 1
            ringScale   = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        }

        withAnimation(.easeInOut(duration: 0.4).delay(1.55)) {
            exitOpacity = 0
            exitScale   = 1.02
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
            onFinished()
        }
    }
}
