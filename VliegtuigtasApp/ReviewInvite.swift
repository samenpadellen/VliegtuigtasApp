import SwiftUI
import StoreKit

// MARK: - App Store-koppeling

enum AppStoreInfo {
    static let appID = "6785971912"

    /// Directe link naar het review-formulier in de App Store — de juiste weg
    /// voor een expliciete "Schrijf een review"-knop (i.t.t. de systeem-popup,
    /// die je volgens Apple alleen op een natuurlijk moment mag tonen).
    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")
    }
}

// MARK: - Natuurlijk-moment prompt (StoreKit requestReview)

/// Beslist of we — op een logisch moment, zoals Apple aanraadt — de
/// systeem-beoordelingspopup mogen tonen. De popup verschijnt na een geslaagde
/// check (de tas past), maar **hoogstens één keer per 3 maanden per gebruiker**.
/// Het systeem beperkt het daarna zelf verder (max. 3×/jaar).
enum ReviewPrompter {
    private static let countKey = "vt_successful_checks"
    private static let lastPromptTimeKey = "vt_last_review_prompt_time"

    /// Minimale tussenpoos tussen twee beoordelingsverzoeken: 3 maanden.
    private static let minInterval: TimeInterval = 90 * 24 * 60 * 60

    /// Telt een geslaagde check (voor mijlpalen/journey). Losgekoppeld van de
    /// prompt-beslissing zodat de eerste-check-viering het review-venster niet
    /// opsoupeert.
    static func recordSuccess() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: countKey) + 1, forKey: countKey)
    }

    /// Mag de systeem-beoordelingspopup nu getoond worden? `true` als er nog
    /// nooit is gevraagd of het ≥ 3 maanden geleden is; zet dan meteen het
    /// tijdstempel zodat het venster gesloten wordt.
    static func shouldPrompt() -> Bool {
        let d = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let last = d.double(forKey: lastPromptTimeKey)   // 0 = nog nooit gevraagd
        guard last == 0 || now - last >= minInterval else { return false }
        d.set(now, forKey: lastPromptTimeKey)
        return true
    }
}

// MARK: - Review-knop (Profiel)

/// Uitnodiging om de app te beoordelen. Stond eerder als een uitgebreid
/// instapkaart-illustratie — leuk, maar las bij het scrollen niet meteen
/// als knop. Nu dezelfde rij-opbouw als de andere tegels in de app (geel
/// rond icoon, titel + uitleg, chevron): in één oogopslag duidelijk dat dit
/// iets is om op te tikken. Tikken opent het review-formulier in de App Store.
struct ReviewInviteCard: View {
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let url = AppStoreInfo.writeReviewURL {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.yellow)
                    Image(systemName: "star.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Beoordeel Vliegtuigtas")
                        .font(.frutiger(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Laat 5 sterren achter in de App Store")
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .cardElevation()
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("Schrijf een review in de App Store")
    }
}
