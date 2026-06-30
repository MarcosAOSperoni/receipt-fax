import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverURL = ""
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)
                    Text("Receipt Fax")
                        .font(.largeTitle.bold())
                    Text("Enter your server URL to get started.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("https://your-server.example.com", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal)

                Button("Connect") {
                    let trimmed = serverURL.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    appState.configure(serverURL: trimmed)
                    showAuth = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverURL.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .navigationDestination(isPresented: $showAuth) {
                AuthView()
            }
        }
        .onAppear {
            serverURL = appState.serverURL
        }
    }
}
