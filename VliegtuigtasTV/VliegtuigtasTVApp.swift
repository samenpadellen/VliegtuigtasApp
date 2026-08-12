import SwiftUI

@main
struct VliegtuigtasTVApp: App {
    @StateObject private var airlineStore = AirlineStore()

    init() { AppFont.register() }

    var body: some Scene {
        WindowGroup {
            TVBoardView()
                .environmentObject(airlineStore)
        }
    }
}
