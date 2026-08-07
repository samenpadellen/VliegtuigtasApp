import Foundation

/// Haalt één representatieve foto op via de Pexels Search API — gebruikt om
/// landen in de bucket list een echte foto te geven i.p.v. alleen een
/// vlagemoji. Zelfde opzet als UnsplashClient.swift, ander response-schema.
enum PexelsClient {
    private static let apiKey = "5yV4wM8Rwpg80rL5w0DRNOuH9oRNQp0bna5O7NWrNm3Rf37KGfW8qr1h"

    struct Photo {
        let regularUrl: String
        let authorName: String
        let authorProfileUrl: String
    }

    private struct SearchResponse: Decodable {
        struct PexelsPhoto: Decodable {
            struct Src: Decodable { let large: String }
            let src: Src
            let photographer: String
            let photographerUrl: String
        }
        let photos: [PexelsPhoto]
    }

    /// Geeft nil terug bij geen resultaat, geen sleutel of een netwerkfout —
    /// de UI valt dan terug op het vlagemoji.
    static func searchPhoto(query: String) async -> Photo? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !apiKey.isEmpty else { return nil }

        var components = URLComponents(string: "https://api.pexels.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "per_page", value: "1"),
            URLQueryItem(name: "orientation", value: "landscape"),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        // Pexels gebruikt de kale key als Authorization-waarde — geen
        // "Bearer"/"Client-ID"-prefix zoals bij andere API's.
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? decoder.decode(SearchResponse.self, from: data),
              let first = decoded.photos.first
        else { return nil }

        return Photo(
            regularUrl: first.src.large,
            authorName: first.photographer,
            authorProfileUrl: first.photographerUrl
        )
    }
}
