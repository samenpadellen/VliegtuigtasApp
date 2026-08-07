import Foundation

final class APIClient: ObservableObject {
    static let shared = APIClient()

    // Paste je iOS API key hier, of zet VT_API_KEY in een Config.xcconfig
    private let apiKey = "lFkEQW18oyMrdMsbfNK1DtnDnoCcqwNSBRfMCXmszUgbAoLf"
    /// Voor plekken buiten deze class die hetzelfde publieke client-token
    /// nodig hebben (bijv. `ImageLoader` in SharedViews.swift, alleen voor
    /// requests naar onze eigen API — nooit naar externe CDN's).
    var publicClientKey: String { apiKey }

    // Apex-host: www redirect (302) naar apex en URLSession laat de
    // Authorization-header vallen bij cross-host redirects.
    private let base = URL(string: "https://vliegtuigtas.com/api/public/v1")!

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        // HTTP-cache voor alle API-verkeer: herhaalde requests binnen de
        // server-cacheheaders komen van schijf i.p.v. het netwerk.
        cfg.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        return URLSession(configuration: cfg)
    }()

    // MARK: - Request coördinator (coalescing + korte responscache)

    /// Serialiseert de GET-cache en dedupliceert gelijktijdige, identieke
    /// requests: als twee schermen tegelijk dezelfde data opvragen (bijv. bij
    /// een koude start waar Home én een detailscherm allebei `airlines()`
    /// aanroepen vóórdat de eerste klaar is), gaat er tóch maar één request
    /// naar de server. Een actor houdt dit thread-safe zonder locks.
    private actor RequestCoordinator {
        private var cache: [String: (data: Data, at: Date)] = [:]
        private var inFlight: [String: Task<Data, Error>] = [:]

        /// `ttl == 0` betekent: wél dedupliceren, maar niet cachen (de
        /// catalogus-endpoints hebben hun eigen gedecodeerde cache, dus we
        /// bewaren de ruwe bytes daar niet nog een tweede keer bij).
        func data(
            for url: URL,
            ttl: TimeInterval,
            fetch: @Sendable @escaping (URL) async throws -> Data
        ) async throws -> Data {
            let key = url.absoluteString

            if ttl > 0, let cached = cache[key], Date().timeIntervalSince(cached.at) < ttl {
                return cached.data
            }
            if let existing = inFlight[key] {
                return try await existing.value
            }

            let task = Task { try await fetch(url) }
            inFlight[key] = task
            do {
                let data = try await task.value
                inFlight[key] = nil
                if ttl > 0 { cache[key] = (data, Date()) }
                return data
            } catch {
                inFlight[key] = nil
                throw error
            }
        }

        func invalidate() {
            cache.removeAll()
        }
    }

    private let coordinator = RequestCoordinator()

    // MARK: - Generic helpers

    private func buildURL(_ path: String, query: [String: String]) -> URL {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return comps.url!
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:], ttl: TimeInterval = 0) async throws -> T {
        let data = try await getRaw(path, query: query, ttl: ttl)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// GET via de coördinator: gededupliceerd, en (bij `ttl > 0`) kort gecachet.
    /// Geeft ook de ruwe bytes terug — die schrijven we voor de catalogi naar
    /// schijf zodat een koude start instant data heeft.
    private func getRaw(_ path: String, query: [String: String] = [:], ttl: TimeInterval = 0) async throws -> Data {
        let url = buildURL(path, query: query)
        // Alleen Sendable waarden (String + URLSession) invangen, niet `self`,
        // zodat de coalescing-closure geen data race op de class introduceert.
        let apiKey = self.apiKey
        let session = self.session
        return try await coordinator.data(for: url, ttl: ttl) { url in
            var req = URLRequest(url: url)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.http(http.statusCode)
            }
            return data
        }
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

    // MARK: - In-memory response cache (avoids refetching unchanged catalog data on every navigation)

    private var airlinesCache: (value: [Airline], at: Date)?
    private var bagsCache: [String: (value: [Bag], at: Date)] = [:]
    private let cacheTTL: TimeInterval = 5 * 60
    /// Kortere cache voor vluchtstatus — die is tijdgevoeliger dan de catalogus.
    private let flightLookupTTL: TimeInterval = 60

    // MARK: - Disk-catalogus (instant cold start & offline)

    private static let catalogDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VTCatalogCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func persistCatalog(_ data: Data, name: String) {
        try? data.write(to: Self.catalogDir.appendingPathComponent(name), options: .atomic)
    }

    private func catalog<T: Decodable>(_ type: T.Type, name: String) -> T? {
        guard let data = try? Data(contentsOf: Self.catalogDir.appendingPathComponent(name)),
              let res = try? JSONDecoder().decode(APIResponse<T>.self, from: data) else { return nil }
        return res.data
    }

    /// Laatste succesvol opgehaalde catalogus — voor een direct gevulde UI
    /// bij koude start of zonder verbinding, terwijl de refresh loopt.
    func airlinesFromDisk() -> [Airline]? { catalog([Airline].self, name: "airlines.json") }
    func bagsFromDisk() -> [Bag]? { catalog([Bag].self, name: "bags.json") }

    // MARK: - Endpoints

    /// GET /airlines. `forceRefresh` negeert de in-memory cache — nodig voor
    /// pull-to-refresh, waar een expliciete gebruikersactie altijd een echte
    /// netwerkcall hoort te doen, ook binnen de cache-TTL.
    func airlines(forceRefresh: Bool = false) async throws -> [Airline] {
        if !forceRefresh, let cached = airlinesCache, Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.value
        }
        let data = try await getRaw("airlines")
        let res = try JSONDecoder().decode(APIResponse<[Airline]>.self, from: data)
        let airlines = res.data ?? []
        airlinesCache = (airlines, Date())
        persistCatalog(data, name: "airlines.json")
        return airlines
    }

    /// GET /airlines/{slug} — kort gecachet, zodat herhaald openen van dezelfde
    /// maatschappij-detailpagina niet telkens de server raakt.
    func airline(slug: String) async throws -> Airline {
        let res: APIResponse<Airline> = try await get("airlines/\(slug)", ttl: cacheTTL)
        guard let airline = res.data else { throw APIError.noData }
        return airline
    }

    /// GET /bags?airline=ryanair&type=rugzak&max_price=120. `forceRefresh`
    /// negeert de in-memory cache — nodig voor pull-to-refresh.
    func bags(airline: String? = nil, type: String? = nil, maxPrice: Int? = nil, forceRefresh: Bool = false) async throws -> [Bag] {
        var query: [String: String] = [:]
        if let a = airline  { query["airline"]   = a }
        if let t = type     { query["type"]      = t }
        if let p = maxPrice { query["max_price"] = "\(p)" }
        let cacheKey = "\(airline ?? "")|\(type ?? "")|\(maxPrice.map(String.init) ?? "")"
        if !forceRefresh, let cached = bagsCache[cacheKey], Date().timeIntervalSince(cached.at) < cacheTTL {
            return cached.value
        }
        let data = try await getRaw("bags", query: query)
        let res = try JSONDecoder().decode(APIResponse<[Bag]>.self, from: data)
        let bags = res.data ?? []
        bagsCache[cacheKey] = (bags, Date())
        if airline == nil, type == nil, maxPrice == nil {
            // Alleen de ongefilterde catalogus bewaren (de basis van Home/Shop).
            persistCatalog(data, name: "bags.json")
        }
        return bags
    }

    /// GET /bags/{id} — kort gecachet, zodat heen-en-weer navigeren tussen een
    /// tas en vergelijkbare tassen niet steeds dezelfde detailrequest herhaalt.
    func bag(id: String) async throws -> BagDetail {
        let res: APIResponse<BagDetail> = try await get("bags/\(id)", ttl: cacheTTL)
        guard let data = res.data else { throw APIError.noData }
        return data
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

    /// GET /flight-lookup?flight=KL1234 — korte cache (60s): vluchtstatus
    /// verandert wel, maar niet van seconde tot seconde. Dit vangt het typen
    /// (auto-lookup) en herhaalde opzoekingen van dezelfde vlucht op zonder
    /// merkbaar oudere status te tonen.
    func flightLookup(number: String) async throws -> FlightLookupResponse {
        let res: APIResponse<FlightLookupResponse> = try await get(
            "flight-lookup", query: ["flight": number], ttl: flightLookupTTL
        )
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

    /// POST https://www.vliegtuigtas.com/leads/delete — verwijdert alle
    /// servergegevens (check_leads + bag_checks) van dit e-mailadres
    /// (App Review 5.1.1(v): accountverwijdering). Let op: dit endpoint
    /// leeft op de site-root, niet onder /api/public/v1.
    func requestAccountDeletion(email: String) {
        struct DeleteRequest: Encodable {
            let email: String
        }
        Task {
            guard let url = URL(string: "https://vliegtuigtas.com/leads/delete") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(DeleteRequest(email: email))
            _ = try? await session.data(for: req)
        }
    }

    /// Laatst verzonden tijdstip per (type|path) — om dubbele events te dempen.
    /// Op de main actor geïsoleerd zodat de bookkeeping thread-safe blijft,
    /// terwijl `sendEvent` zelf vanaf elke context aanroepbaar blijft.
    @MainActor private var lastEventSent: [String: Date] = [:]
    /// Binnen dit venster tellen identieke events als één (voorkomt dubbele
    /// `page_view`/CTA-POSTs bij het opnieuw verschijnen van een scherm of
    /// snel heen-en-weer tikken).
    private let eventDedupeWindow: TimeInterval = 2

    /// POST /events — fire-and-forget, met de-duplicatie van snel herhaalde
    /// identieke events zodat de analytics-endpoint niet onnodig belast wordt.
    nonisolated func sendEvent(_ type: String, path: String? = nil) {
        Task { @MainActor in
            let key = "\(type)|\(path ?? "")"
            let now = Date()
            if let last = lastEventSent[key], now.timeIntervalSince(last) < eventDedupeWindow {
                return
            }
            lastEventSent[key] = now

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
