import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverURL = ""
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 16)

                    // Hero card
                    VStack(spacing: 20) {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .frame(width: 84, height: 84)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 14, x: 0, y: 6)

                        VStack(spacing: 6) {
                            Text("Receipt Fax")
                                .font(.title.bold())
                            Text("Send messages that print themselves.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
                    .padding(.horizontal)

                    // Server URL field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERVER URL")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        TextField("https://your-server.example.com", text: $serverURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Connect button
                    Button("Connect") {
                        let trimmed = serverURL.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        appState.configure(serverURL: trimmed)
                        showAuth = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .disabled(serverURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
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
