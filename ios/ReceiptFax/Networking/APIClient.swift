import Foundation

final class APIClient {
    let baseURL: URL
    private let session: URLSessionProtocol
    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: str) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    init(baseURL: URL, session: URLSessionProtocol = URLSession.shared) {
        var urlStr = baseURL.absoluteString
        if urlStr.hasSuffix("/") { urlStr = String(urlStr.dropLast()) }
        self.baseURL = URL(string: urlStr) ?? baseURL
        self.session = session
    }

    func setTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }

    // MARK: - Core request

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        contentType: String = "application/json"
    ) async throws -> T {
        let (data, response) = try await performWithRefresh(
            path: path, method: method, body: body, contentType: contentType
        )
        try checkStatus(response, data: data)
        return try Self.decoder.decode(T.self, from: data)
    }

    func requestVoid(_ path: String, method: String = "DELETE", body: Data? = nil) async throws {
        let (data, response) = try await performWithRefresh(
            path: path, method: method, body: body, contentType: "application/json"
        )
        try checkStatus(response, data: data)
    }

    // MARK: - Helpers

    private func performWithRefresh(
        path: String,
        method: String,
        body: Data?,
        contentType: String
    ) async throws -> (Data, URLResponse) {
        let urlRequest = try makeRequest(path: path, method: method, body: body, contentType: contentType)
        let (data, response) = try await perform(urlRequest)
        let http = response as? HTTPURLResponse

        guard http?.statusCode == 401 else { return (data, response) }
        guard let current = refreshToken else { throw APIError.notAuthenticated }
        do {
            let tokens = try await performRefresh(refreshToken: current)
            setTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
        } catch {
            NotificationCenter.default.post(name: .authRefreshFailed, object: nil)
            throw APIError.notAuthenticated
        }
        let retry = try makeRequest(path: path, method: method, body: body, contentType: contentType)
        return try await perform(retry)
    }

    private func makeRequest(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String = "application/json"
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let accessToken {
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.httpError(http.statusCode, detail)
        }
    }

    private func performRefresh(refreshToken: String) async throws -> TokenResponse {
        guard let url = URL(string: baseURL.absoluteString + "/api/v1/auth/refresh") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try Self.encoder.encode(RefreshBody(refreshToken: refreshToken))
        let (data, response) = try await session.data(for: req)
        try checkStatus(response, data: data)
        return try Self.decoder.decode(TokenResponse.self, from: data)
    }
}
