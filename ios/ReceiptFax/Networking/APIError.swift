import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case httpError(Int, String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Invalid server URL."
        case .notAuthenticated:         return "Session expired. Please sign in again."
        case .httpError(let code, let msg): return "\(msg) (\(code))"
        case .networkError(let err):    return err.localizedDescription
        }
    }
}
