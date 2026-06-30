import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRegistering = false
    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if isRegistering {
                    TextField("Display Name", text: $displayName)
                        .autocorrectionDisabled()
                }
                SecureField("Password", text: $password)
            }

            if let error {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }

            Section {
                Button(isLoading ? "Please wait\u{2026}" : (isRegistering ? "Create Account" : "Sign In")) {
                    Task { await submit() }
                }
                .disabled(isLoading || !isFormValid)
            }
        }
        .navigationTitle(isRegistering ? "Create Account" : "Sign In")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isRegistering ? "Sign In Instead" : "Register") {
                    isRegistering.toggle()
                    error = nil
                }
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && (!isRegistering || !displayName.isEmpty)
    }

    private func submit() async {
        isLoading = true
        error = nil
        do {
            let tokens: TokenResponse
            if isRegistering {
                tokens = try await appState.apiClient.register(
                    email: email, displayName: displayName, password: password
                )
            } else {
                tokens = try await appState.apiClient.login(email: email, password: password)
            }
            appState.logIn(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, email: email)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
