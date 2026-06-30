import Foundation
import Combine

extension Notification.Name {
    static let authRefreshFailed = Notification.Name("ReceiptFax.authRefreshFailed")
}

// Stub replaced in Task 2
class APIClient {
    let baseURL: URL
    init(baseURL: URL) { self.baseURL = baseURL }
    func setTokens(access: String, refresh: String) {}
    func clearTokens() {}
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userEmail = ""
    @Published private(set) var serverURL = ""
    private(set) var apiClient: APIClient

    init() {
        let stored = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        serverURL = stored
        apiClient = APIClient(baseURL: URL(string: stored.isEmpty ? "http://localhost:8000" : stored)!)

        if let access = KeychainStore.load("accessToken"),
           let refresh = KeychainStore.load("refreshToken"),
           let email = KeychainStore.load("userEmail"),
           !stored.isEmpty {
            apiClient.setTokens(access: access, refresh: refresh)
            userEmail = email
            isAuthenticated = true
        }

        NotificationCenter.default.addObserver(
            forName: .authRefreshFailed,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.logOut() }
        }
    }

    func configure(serverURL: String) {
        self.serverURL = serverURL
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        let newClient = APIClient(baseURL: URL(string: serverURL)!)
        if let access = KeychainStore.load("accessToken"),
           let refresh = KeychainStore.load("refreshToken") {
            newClient.setTokens(access: access, refresh: refresh)
        }
        apiClient = newClient
    }

    func logIn(accessToken: String, refreshToken: String, email: String) {
        try? KeychainStore.save(accessToken, for: "accessToken")
        try? KeychainStore.save(refreshToken, for: "refreshToken")
        try? KeychainStore.save(email, for: "userEmail")
        apiClient.setTokens(access: accessToken, refresh: refreshToken)
        userEmail = email
        isAuthenticated = true
    }

    func logOut() {
        KeychainStore.delete("accessToken")
        KeychainStore.delete("refreshToken")
        KeychainStore.delete("userEmail")
        apiClient.clearTokens()
        userEmail = ""
        isAuthenticated = false
    }
}
