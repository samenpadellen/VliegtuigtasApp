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
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.Radius.lg)
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
                        .padding(.top, Theme.Spacing.xl)

                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(highlights.indices, id: \.self) { i in
                                WhatsNewRow(highlight: highlights[i])
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        // Alleen tonen als er ook echt eerdere versies zijn om
                        // op terug te kijken — bij een verse install met maar
                        // één versie in de catalogus heeft de link geen doel.
                        if WhatsNewContent.notes.count > 1 {
                            NavigationLink {
                                WhatsNewHistoryView(currentVersion: version)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("Bekijk eerdere updates")
                                }
                                .font(.frutiger(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xs)
                        }
                    }
                }

                Button(action: onDismiss) {
                    Text("Verdergaan")
                        .font(.frutiger(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.base)
                        .background(Theme.inkGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .background(Theme.surface)
        }
    }
}

// MARK: - Update-geschiedenis

/// Lijst van alle versies uit `WhatsNewContent.notes`, nieuwste eerst — zodat
/// je per updatenummer kan terugkijken wat er toen is toegevoegd.
struct WhatsNewHistoryView: View {
    let currentVersion: String

    private var sortedVersions: [String] {
        WhatsNewContent.notes.keys.sorted { a, b in
            let pa = Self.components(a), pb = Self.components(b)
            for i in 0..<max(pa.count, pb.count) {
                let x = i < pa.count ? pa[i] : 0
                let y = i < pb.count ? pb[i] : 0
                if x != y { return x > y }
            }
            return false
        }
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    var body: some View {
        List(sortedVersions, id: \.self) { version in
            NavigationLink {
                WhatsNewVersionDetailView(
                    version: version,
                    highlights: WhatsNewContent.notes[version] ?? []
                )
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Versie \(version)")
                                .font(.frutiger(size: 16, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            if version == currentVersion {
                                Text("HUIDIG")
                                    .font(.frutiger(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.navy)
                                    .padding(.horizontal, Theme.Spacing.xs)
                                    .padding(.vertical, Theme.Spacing.xxs)
                                    .background(Theme.skyLight, in: Capsule())
                            }
                        }
                        Text("\(WhatsNewContent.notes[version]?.count ?? 0) wijzigingen")
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, Theme.Spacing.xxs)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Update-geschiedenis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Eén historische versie, los bekeken — dezelfde rijstijl als het
/// hoofdscherm, zonder de "Verdergaan"-call-to-action die daar hoort bij het
/// net-bijgewerkt-moment.
struct WhatsNewVersionDetailView: View {
    let version: String
    let highlights: [WhatsNewContent.Highlight]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(highlights.indices, id: \.self) { i in
                    WhatsNewRow(highlight: highlights[i])
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.surface)
        .navigationTitle("Versie \(version)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WhatsNewRow: View {
    let highlight: WhatsNewContent.Highlight

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
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
                RoundedRectangle(cornerRadius: Theme.Radius.xl)
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
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onUpdate) {
                    Text("Update nu")
                        .font(.frutiger(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.base)
                        .background(Theme.inkGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Niet nu")
                        .font(.frutiger(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.surface)
    }
}
