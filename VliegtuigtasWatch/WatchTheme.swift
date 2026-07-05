import SwiftUI

/// Compacte variant van Theme voor watchOS. De iOS-Theme gebruikt
/// UIKit-systeemkleuren (systemBackground e.d.) die op watchOS niet bestaan,
/// daarom hier een eigen minimale set met dezelfde merk-kleuren.
enum WatchTheme {
    static let navy   = Color(red: 0.00, green: 0.19, blue: 0.53)
    static let sky    = Color(red: 0.00, green: 0.63, blue: 0.87)
    static let yellow = Color(red: 0.99, green: 0.80, blue: 0.10)
    static let green  = Color(red: 0.18, green: 0.73, blue: 0.45)
    static let orange = Color(red: 0.97, green: 0.59, blue: 0.15)
    static let red    = Color(red: 0.90, green: 0.25, blue: 0.25)

    static func verdictColor(_ v: Verdict) -> Color {
        switch v {
        case .ok:      return green
        case .warning: return orange
        case .fail:    return red
        }
    }
}
