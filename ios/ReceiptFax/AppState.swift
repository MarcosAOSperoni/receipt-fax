import Foundation
import Combine

extension Notification.Name {
    static let authRefreshFailed = Notification.Name("ReceiptFax.authRefreshFailed")
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
        let baseURL = (!stored.isEmpty ? URL(string: stored) : nil)
            ?? URL(string: "http://localhost:8000")!
        apiClient = APIClient(baseURL: baseURL)

        if let access = KeychainStore.load("accessToken"),
           let refresh = KeychainStore.load("refreshToken"),
           let email = KeychainStore.load("userEmail"),
           !stored.isEmpty {
            apiClient.setTokens(access: access, refresh: refresh)
            userEmail = email
            isAuthenticated = true
        }

        apiClient.onTokensRefreshed = { access, refresh in
            try? KeychainStore.save(access, for: "accessToken")
            try? KeychainStore.save(refresh, for: "refreshToken")
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
        guard let url = URL(string: serverURL) else { return }
        self.serverURL = serverURL
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        let newClient = APIClient(baseURL: url)
        if let access = KeychainStore.load("accessToken"),
           let refresh = KeychainStore.load("refreshToken") {
            newClient.setTokens(access: access, refresh: refresh)
        }
        newClient.onTokensRefreshed = { access, refresh in
            try? KeychainStore.save(access, for: "accessToken")
            try? KeychainStore.save(refresh, for: "refreshToken")
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
