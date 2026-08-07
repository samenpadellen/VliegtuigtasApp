import Foundation

/// Haalt één representatieve foto op voor een bestemming via de Unsplash
/// Search API, zodat een reis een echte foto krijgt i.p.v. een generiek
/// icoontje. Alleen de Access Key is nodig (publiek, client-side, zelfde
/// aanpak als APIClient.swift's eigen sleutel) — de Secret Key hoort bij
/// OAuth-gebruikersflows die deze app niet gebruikt en staat daarom bewust
/// niet in de app.
enum UnsplashClient {
    private static let accessKey = "yT1eCmy78m27W4nmLbiCshfpzvW3q6O1Kvs7SjA3Mdg"

    struct Photo {
        let regularUrl: String
        let authorName: String
        let authorProfileUrl: String
    }

    private struct SearchResponse: Decodable {
        struct Result: Decodable {
            struct Urls: Decodable { let regular: String }
            struct UserLinks: Decodable { let html: String }
            struct User: Decodable { let name: String; let links: UserLinks }
            struct Links: Decodable { let downloadLocation: String }
            let urls: Urls
            let user: User
            let links: Links
        }
        let results: [Result]
    }

    /// Zoekt één foto op trefwoord (meestal de bestemming van een reis).
    /// Geeft nil terug bij geen resultaat, geen sleutel of een netwerkfout —
    /// de UI valt dan gewoon terug op het generieke icoontje.
    static func searchPhoto(query: String) async -> Photo? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !accessKey.isEmpty else { return nil }

        var components = URLComponents(string: "https://api.unsplash.com/search/photos")
        components?.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "per_page", value: "1"),
            URLQueryItem(name: "orientation", value: "landscape"),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? decoder.decode(SearchResponse.self, from: data),
              let first = decoded.results.first
        else { return nil }

        // Unsplash API-richtlijnen: bij daadwerkelijk gebruik van een foto
        // moet de download-locatie aangeroepen worden (telt mee voor de
        // fotograaf-statistieken). We doen dit één keer, op het moment dat
        // de foto aan een reis gekoppeld wordt.
        pingDownload(first.links.downloadLocation)

        return Photo(
            regularUrl: first.urls.regular,
            authorName: first.user.name,
            authorProfileUrl: first.user.links.html
        )
    }

    private static func pingDownload(_ downloadLocation: String) {
        guard let url = URL(string: downloadLocation) else { return }
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        Task { _ = try? await URLSession.shared.data(for: request) }
    }
}
