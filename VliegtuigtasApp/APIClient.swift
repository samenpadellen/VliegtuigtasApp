import Foundation

final class APIClient: ObservableObject {
    static let shared = APIClient()

    // Paste je iOS API key hier, of zet VT_API_KEY in een Config.xcconfig
    private let apiKey = "lFkEQW18oyMrdMsbfNK1DtnDnoCcqwNSBRfMCXmszUgbAoLf"

    private let base = URL(string: "https://handbagage-held.lovable.app/api/public/v1")!

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    // MARK: - Generic helpers

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(req)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Endpoints

    /// GET /airlines
    func airlines() async throws -> [Airline] {
        let res: APIResponse<[Airline]> = try await get("airlines")
        return res.data ?? []
    }

    /// GET /airlines/{slug}
    func airline(slug: String) async throws -> Airline {
        let res: APIResponse<Airline> = try await get("airlines/\(slug)")
        guard let airline = res.data else { throw APIError.noData }
        return airline
    }

    /// GET /bags?airline=ryanair&type=rugzak&max_price=120
    func bags(airline: String? = nil, type: String? = nil, maxPrice: Int? = nil) async throws -> [Bag] {
        var query: [String: String] = [:]
        if let a = airline  { query["airline"]   = a }
        if let t = type     { query["type"]      = t }
        if let p = maxPrice { query["max_price"] = "\(p)" }
        let res: APIResponse<[Bag]> = try await get("bags", query: query)
        return res.data ?? []
    }

    /// POST /check
    func check(
        airlineSlug: String,
        length: Double, width: Double, depth: Double, weight: Double,
        email: String? = nil, firstName: String? = nil
    ) async throws -> CheckResponse {
        let body = CheckRequest(
            airlineSlug: airlineSlug,
            lengthCm: length, widthCm: width, depthCm: depth, weightKg: weight,
            email: email, firstName: firstName
        )
        let res: APIResponse<CheckResponse> = try await post("check", body: body)
        guard let data = res.data else { throw APIError.noData }
        return data
    }

    /// GET /flight-lookup?flight=KL1234
    func flightLookup(number: String) async throws -> FlightLookupResponse {
        let res: APIResponse<FlightLookupResponse> = try await get("flight-lookup", query: ["flight": number])
        guard let data = res.data else { throw APIError.noData }
        return data
    }

    /// POST /leads
    func saveLead(firstName: String, email: String, airlineSlug: String? = nil) {
        Task {
            let body = LeadRequest(firstName: firstName, email: email, airlineSlug: airlineSlug)
            let _: APIResponse<String?> = (try? await post("leads", body: body)) ?? .init(data: nil, error: nil)
        }
    }

    /// POST /events
    func sendEvent(_ type: String, path: String? = nil) {
        Task {
            let body = EventRequest(
                eventType: type,
                path: path,
                sessionId: SessionID.value
            )
            let _: APIResponse<String?> = (try? await post("events", body: body)) ?? .init(data: nil, error: nil)
        }
    }
}

// MARK: - Stable session ID (lives for app lifetime)

private enum SessionID {
    static let value: String = {
        let key = "vt_session_id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = "ios-\(UUID().uuidString.prefix(8).lowercased())"
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()
}

// MARK: - Errors

enum APIError: LocalizedError {
    case http(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .http(let code): return "Server fout (\(code))"
        case .noData:         return "Geen data ontvangen"
        }
    }
}
