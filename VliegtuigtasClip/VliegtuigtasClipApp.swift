import SwiftUI

/// App Clip: de kern van Vliegtuigtas — checken of je tas past — zonder
/// installatie, gestart via QR-code, NFC of link op vliegtuigtas.com.
@main
struct VliegtuigtasClipApp: App {
    @StateObject private var airlineStore = AirlineStore()
    @State private var invokedAirlineSlug: String?

    init() { AppFont.register() }

    var body: some Scene {
        WindowGroup {
            ClipCheckView(invokedAirlineSlug: $invokedAirlineSlug)
                .environmentObject(airlineStore)
                // Invocatie-URL, bijv. https://www.vliegtuigtas.com/check?airline=ryanair
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    invokedAirlineSlug = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "airline" })?.value
                }
        }
    }
}
