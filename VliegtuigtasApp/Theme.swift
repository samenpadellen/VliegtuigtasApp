import SwiftUI

enum Theme {
    /// Maximale kolombreedte voor content op grote schermen (Mac Catalyst,
    /// iPad). iPhone-schermen zijn smaller, dus daar heeft dit geen effect.
    static let contentMaxWidth: CGFloat = 760

    // Brand colours — zwart, geel, blauw, wit: de eigen luchtvaartidentiteit.
    // "ink" (bijna-zwart) is het premium tegenwicht van navy — samen met een
    // zuiver signaalgeel (denk wayfinding op het platform) onderscheidt dit
    // de app van een generieke maatschappij-huisstijl die alleen blauw/wit is.
    static let ink       = Color(red: 0.05, green: 0.06, blue: 0.09)   // bijna zwart
    static let inkLight  = Color(red: 0.13, green: 0.15, blue: 0.19)

    /// Ink als accentkleur op systeemchrome (tabbalk, schakelaars). Puur `ink`
    /// gebruiken werkt niet: in donkere modus is bijna-zwart onleesbaar op een
    /// donkere tabbalk — het actieve item verdween dan volledig. Daarom licht
    /// deze in donkere modus op naar wit.
    static let inkAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1)
    })
    static let navy      = Color(red: 0.00, green: 0.19, blue: 0.53)   // deep KLM-blue
    static let navyDark  = Color(red: 0.00, green: 0.12, blue: 0.38)
    static let sky       = Color(red: 0.00, green: 0.63, blue: 0.87)   // bright accent blue
    static let skyLight  = Color(red: 0.88, green: 0.94, blue: 0.99)
    static let yellow    = Color(red: 1.00, green: 0.76, blue: 0.03)   // signaalgeel accent
    static let yellowSoft = Color(red: 1.00, green: 0.93, blue: 0.60)
    static let green     = Color(red: 0.18, green: 0.73, blue: 0.45)
    static let orange    = Color(red: 0.97, green: 0.59, blue: 0.15)
    static let red       = Color(red: 0.90, green: 0.25, blue: 0.25)
    static let surface   = Color(.systemBackground)
    static let card      = Color(.secondarySystemBackground)
    static let textPrimary   = Color(.label)
    static let textSecondary = Color(.secondaryLabel)

    // Gradients
    static let heroGradient = LinearGradient(
        colors: [ink.opacity(0.15), ink.opacity(0.90)],
        startPoint: .top, endPoint: .bottom
    )
    static let navyGradient = LinearGradient(
        colors: [navy, navyDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let inkGradient = LinearGradient(
        colors: [inkLight, ink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let skyGradient = LinearGradient(
        colors: [sky, navy],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Verdict
    static func verdictColor(_ v: Verdict) -> Color {
        switch v {
        case .ok:      return green
        case .warning: return orange
        case .fail:    return red
        }
    }
}

extension Font {
    static let headline1 = Font.frutiger(size: 30, weight: .bold,     relativeTo: .largeTitle)
    static let headline2 = Font.frutiger(size: 20, weight: .semibold, relativeTo: .title3)
    static let body1     = Font.frutiger(size: 16, weight: .regular,  relativeTo: .body)
    static let caption1  = Font.frutiger(size: 13, weight: .regular,  relativeTo: .footnote)
}
