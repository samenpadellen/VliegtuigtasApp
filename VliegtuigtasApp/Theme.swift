import SwiftUI

enum Theme {
    // Brand colours
    static let navy      = Color(red: 0.00, green: 0.19, blue: 0.53)   // deep KLM-blue
    static let navyDark  = Color(red: 0.00, green: 0.12, blue: 0.38)
    static let sky       = Color(red: 0.00, green: 0.63, blue: 0.87)   // bright accent blue
    static let skyLight  = Color(red: 0.88, green: 0.94, blue: 0.99)
    static let yellow    = Color(red: 0.99, green: 0.80, blue: 0.10)
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
        colors: [navyDark.opacity(0.15), navyDark.opacity(0.85)],
        startPoint: .top, endPoint: .bottom
    )
    static let navyGradient = LinearGradient(
        colors: [navy, navyDark],
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
    static let headline1 = Font.system(size: 30, weight: .bold,     design: .rounded)
    static let headline2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let body1     = Font.system(size: 16, weight: .regular,  design: .rounded)
    static let caption1  = Font.system(size: 13, weight: .regular,  design: .rounded)
}
