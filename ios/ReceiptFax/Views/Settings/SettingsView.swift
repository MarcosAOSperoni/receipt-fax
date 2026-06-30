import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAddDevice = false
    @State private var draftURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Email", value: appState.userEmail)
                    Button("Sign Out", role: .destructive) {
                        appState.logOut()
                    }
                }

                Section("Server") {
                    HStack {
                        TextField("https://…", text: $draftURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if draftURL.trimmingCharacters(in: .whitespaces) != appState.serverURL {
                            Button("Save") {
                                appState.configure(serverURL: draftURL.trimmingCharacters(in: .whitespaces))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Printers") {
                    ForEach(viewModel.devices) { device in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                            if let seen = device.lastSeenAt {
                                Text("Last seen \(seen, style: .relative)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Never connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            let id = viewModel.devices[idx].id
                            Task { await viewModel.deleteDevice(id: id, apiClient: appState.apiClient) }
                        }
                    }

                    Button("Add Printer") { showAddDevice = true }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear { draftURL = appState.serverURL }
        .task { await viewModel.loadDevices(apiClient: appState.apiClient) }
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.createdDevice) { device in
            APIKeyModal(device: device)
        }
    }
}
