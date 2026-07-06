import SwiftUI

@main
struct VliegtuigtasVisionApp: App {
    @StateObject private var airlineStore = AirlineStore()
    @StateObject private var bagState = VisionBagState.shared

    init() { AppFont.register() }

    var body: some Scene {
        // Hoofdvenster: maatschappijen, regels en de check
        WindowGroup {
            VisionContentView()
                .environmentObject(airlineStore)
        }
        .defaultSize(width: 1100, height: 720)

        // Volumetrisch venster: de koffer op wáre grootte in je kamer,
        // met de limietkooi van de gekozen maatschappij eromheen.
        WindowGroup(id: "bag-volume") {
            BagVolumeView()
                .environmentObject(bagState)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.0, height: 1.1, depth: 0.8, in: .meters)
    }
}
