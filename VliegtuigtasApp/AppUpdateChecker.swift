import SwiftUI

/// Twee losse dingen die allebei met "welke versie draait hier" te maken
/// hebben:
/// 1. Wat is er nieuw — de vorige keer gezien versienummer wijkt af van nu,
///    dus deze installatie is net bijgewerkt. Toont de releasenotities.
/// 2. Update beschikbaar — vraagt de App Store zelf welke versie daar
///    live staat; als die nieuwer is dan wat hier draait, een zachte
///    suggestie om te updaten. Geen eigen server nodig.
@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published private(set) var showWhatsNew = false
    @Published private(set) var updateAvailableVersion: String?
    private var appStoreURL: URL?

    private let defaults = UserDefaults.standard
    private let lastSeenVersionKey = "vt_last_seen_version"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private init() {}

    /// Bij een verse installatie (geen eerder gezien versienummer) wordt er
    /// niets getoond — dat hoort al bij de onboarding. Pas bij een ándere
    /// versie dan de vorige keer verschijnt het releasenotities-scherm.
    func checkForUpdateNotes() {
        guard let lastSeen = defaults.string(forKey: lastSeenVersionKey) else {
            defaults.set(currentVersion, forKey: lastSeenVersionKey)
            return
        }
        if lastSeen != currentVersion, WhatsNewContent.notes[currentVersion] != nil {
            showWhatsNew = true
        }
        defaults.set(currentVersion, forKey: lastSeenVersionKey)
    }

    func dismissWhatsNew() {
        showWhatsNew = false
    }

    /// Stil op de achtergrond; bij een netwerkfout, een niet-gevonden App
    /// Store-listing, of als je al up-to-date bent, gebeurt er gewoon niets.
    func checkForAvailableUpdate() async {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=nl") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let result = response.results.first,
                  Self.isVersion(result.version, newerThan: currentVersion) else { return }
            updateAvailableVersion = result.version
            appStoreURL = URL(string: result.trackViewUrl)
        } catch {
            // Geen internet of nog geen App Store-listing is geen fout die
            // de gebruiker hoeft te zien.
        }
    }

    func dismissUpdateAvailable() {
        updateAvailableVersion = nil
    }

    func openAppStore() {
        guard let appStoreURL else { return }
        UIApplication.shared.open(appStoreURL)
    }

    /// Simpele punt-gescheiden versievergelijking ("3.10.0" > "3.9.0").
    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private struct LookupResponse: Decodable {
        let results: [LookupResult]
    }
    private struct LookupResult: Decodable {
        let version: String
        let trackViewUrl: String
    }
}

// MARK: - Releasenotities

/// Puur data, per versie — makkelijk uit te breiden bij een volgende release.
enum WhatsNewContent {
    struct Highlight {
        let icon: String
        let tint: Color
        let title: String
        let description: String
    }

    static let notes: [String: [Highlight]] = [
        "3.1.0": [
            Highlight(icon: "tv.fill", tint: Theme.sky,
                      title: "Vliegtuigtas op je Apple TV",
                      description: "Een eigen vertrekbord thuis op de bank: je eerstvolgende reis en vlucht, met tips van Purser Pim die voorbij scrollen."),
            Highlight(icon: "square.grid.2x2.fill", tint: Theme.yellow,
                      title: "Nieuwe stickers voor iMessage",
                      description: "Purser Pim en klapperbord-stickers als BOARDING en GOEDE REIS, rechtstreeks vanuit je berichten-app."),
            Highlight(icon: "star.fill", tint: Theme.orange,
                      title: "Reisverslag",
                      description: "Beoordeel je reis achteraf en bewaar je herinneringen bij je reispaspoort."),
            Highlight(icon: "camera.viewfinder", tint: Theme.green,
                      title: "Nauwkeuriger 3D-scannen",
                      description: "LiDAR-scans van je tas zijn sneller en preciezer dan ooit."),
            Highlight(icon: "paintbrush.fill", tint: Theme.sky,
                      title: "Frisse, strakkere look",
                      description: "Een nieuw kleurenpalet en opgeruimde schermen door de hele app heen.")
        ]
    ]
}
