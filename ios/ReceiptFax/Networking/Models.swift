import Foundation

// MARK: - Auth
struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - Formatting
struct MessageStyle: Codable, Equatable {
    var bold: Bool = false
    var size: String = "normal"   // "normal" | "large" | "header"
    var align: String = "left"    // "left" | "center"
}

// MARK: - Rich Text

struct RichSpan: Codable, Equatable {
    var text: String
    var bold: Bool
}

struct RichLine: Codable, Equatable {
    var size: String   // "normal" | "large" | "header"
    var align: String  // "left" | "center"
    var spans: [RichSpan]
}

// MARK: - Messages
struct MessageResponse: Decodable, Identifiable {
    let id: UUID
    let deviceId: UUID
    let body: String?
    let style: MessageStyle
    let imagePath: String?
    let richBody: [RichLine]?
    let status: String            // "pending" | "printed" | "failed"
    let failureReason: String?
    let createdAt: Date
    let printedAt: Date?
}

// MARK: - Devices
struct DeviceResponse: Decodable, Identifiable {
    let id: UUID
    let name: String
    let lastSeenAt: Date?
    let createdAt: Date
}

struct DeviceCreateResponse: Decodable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let lastSeenAt: Date?
    let createdAt: Date
    let apiKey: String
}

// MARK: - Request bodies (encoded with convertToSnakeCase)
struct RegisterBody: Encodable {
    let email: String
    let displayName: String
    let password: String
}

struct LoginBody: Encodable {
    let email: String
    let password: String
}

struct RefreshBody: Encodable {
    let refreshToken: String
}

struct DeviceCreateBody: Encodable {
    let name: String
}
