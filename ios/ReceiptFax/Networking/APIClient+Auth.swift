import Foundation

extension APIClient {
    func register(email: String, displayName: String, password: String) async throws -> TokenResponse {
        let body = try Self.encoder.encode(RegisterBody(email: email, displayName: displayName, password: password))
        return try await request("/api/v1/auth/register", method: "POST", body: body)
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        let body = try Self.encoder.encode(LoginBody(email: email, password: password))
        return try await request("/api/v1/auth/login", method: "POST", body: body)
    }
}
