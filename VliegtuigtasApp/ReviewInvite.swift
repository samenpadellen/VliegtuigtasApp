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

/// Houdt bij hoe vaak een check is gelukt en beslist of we — op een logisch
/// moment, zoals Apple aanraadt — de systeem-beoordelingspopup mogen tonen.
/// Niet vaker dan bij een paar mijlpalen; het systeem beperkt het daarna zelf.
enum ReviewPrompter {
    private static let countKey = "vt_successful_checks"
    private static let lastPromptVersionKey = "vt_last_review_prompt_version"

    /// Registreert een geslaagde check en geeft terug of dit een goed moment
    /// is om (één keer per app-versie) om een beoordeling te vragen.
    @discardableResult
    static func registerSuccessAndShouldPrompt() -> Bool {
        let d = UserDefaults.standard
        let count = d.integer(forKey: countKey) + 1
        d.set(count, forKey: countKey)

        // Pas ná een paar succesvolle checks vragen — dan heeft iemand de app
        // echt nuttig gevonden.
        guard count == 3 || count == 12 else { return false }

        // Hoogstens één keer per app-versie vragen.
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        guard d.string(forKey: lastPromptVersionKey) != version else { return false }
        d.set(version, forKey: lastPromptVersionKey)
        return true
    }
}

// MARK: - Boarding pass-review-kaart (op zijn vliegvelds)

/// Uitnodiging om de app te beoordelen, vormgegeven als een instapkaart.
/// Tikken opent het review-formulier in de App Store.
struct ReviewInviteCard: View {
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let url = AppStoreInfo.writeReviewURL {
                UIApplication.shared.open(url)
            }
        } label: {
            boardingPass
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("Schrijf een review in de App Store")
    }

    private var boardingPass: some View {
        HStack(spacing: 0) {
            // — Hoofdstrook —
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 10, weight: .bold))
                    Text("BOARDING PASS · REVIEW")
                        .font(.frutiger(size: 10, weight: .bold))
                        .kerning(1.4)
                }
                .foregroundStyle(.white.opacity(0.7))

                Text("Fijne reis gehad?")
                    .font(.frutiger(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Laat 5 sterren achter en help andere reizigers ons te vinden.")
                    .font(.frutiger(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.yellow)
                    }
                    Text("Beoordeel in de App Store")
                        .font(.frutiger(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.leading, 6)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)

            // — Perforatie —
            perforation

            // — Afscheurstrook (gate) —
            VStack(spacing: 6) {
                Text("GATE")
                    .font(.frutiger(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .kerning(1.5)
                Text("5★")
                    .font(.frutiger(size: 22, weight: .black))
                    .foregroundStyle(Theme.yellow)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }
            .frame(width: 74)
            .frame(maxHeight: .infinity)
        }
        .background(
            LinearGradient(
                colors: [Theme.navy, Color(red: 0.03, green: 0.14, blue: 0.34)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Theme.navy.opacity(0.28), radius: 14, x: 0, y: 6)
    }

    /// Verticale gestippelde perforatie met een "uitgeknipte" ronding boven en
    /// onder — de klassieke instapkaart-look.
    private var perforation: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 1)
                .overlay(
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(.white.opacity(0.45))
                )
        }
        .overlay(alignment: .top) {
            Circle().fill(Color(.systemGroupedBackground)).frame(width: 14, height: 14).offset(y: -7)
        }
        .overlay(alignment: .bottom) {
            Circle().fill(Color(.systemGroupedBackground)).frame(width: 14, height: 14).offset(y: 7)
        }
    }
}

/// Een enkele verticale lijn (voor de perforatie-stippellijn).
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}
