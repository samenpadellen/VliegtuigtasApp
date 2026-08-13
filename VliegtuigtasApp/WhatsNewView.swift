import SwiftUI

/// Verschijnt eenmalig na een update: een lichte kaart (geen dramatische
/// full-bleed foto zoals de onboarding — dit is een korte, vriendelijke
/// terugkoppeling in de bestaande app, geen eerste indruk) met de
/// releasehighlights van de zojuist geïnstalleerde versie.
struct WhatsNewView: View {
    let version: String
    let highlights: [WhatsNewContent.Highlight]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Theme.inkGradient)
                                .frame(width: 72, height: 72)
                            Image(systemName: "suitcase.rolling.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(Theme.yellow)
                        }
                        Text("Wat is er nieuw")
                            .font(.frutiger(size: 26, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Versie \(version)")
                            .font(.frutiger(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)

                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(highlights.indices, id: \.self) { i in
                            WhatsNewRow(highlight: highlights[i])
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            Button(action: onDismiss) {
                Text("Verdergaan")
                    .font(.frutiger(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Theme.inkGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.surface)
    }
}

private struct WhatsNewRow: View {
    let highlight: WhatsNewContent.Highlight

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(highlight.tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: highlight.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(highlight.tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(highlight.title)
                    .font(.frutiger(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(highlight.description)
                    .font(.frutiger(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Update beschikbaar

/// Zachte update-suggestie wanneer de App Store een nieuwere versie heeft
/// dan wat er hier draait — nooit blokkerend, altijd met een "niet nu".
struct UpdateAvailableView: View {
    let version: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Theme.inkGradient)
                    .frame(width: 84, height: 84)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.yellow)
            }

            VStack(spacing: 8) {
                Text("Er is een update beschikbaar")
                    .font(.frutiger(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Versie \(version) van Vliegtuigtas staat klaar in de App Store, met de laatste verbeteringen en bugfixes.")
                    .font(.frutiger(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onUpdate) {
                    Text("Update nu")
                        .font(.frutiger(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Theme.inkGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Niet nu")
                        .font(.frutiger(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.surface)
    }
}
