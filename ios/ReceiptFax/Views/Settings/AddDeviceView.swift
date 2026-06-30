import SwiftUI

struct AddDeviceView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Printer Name") {
                    TextField("e.g. Living Room Printer", text: $viewModel.newDeviceName)
                        .autocorrectionDisabled()
                }
                if let error = viewModel.error {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
                Section {
                    Button(viewModel.isLoading ? "Adding…" : "Add Printer") {
                        Task { await viewModel.addDevice(apiClient: appState.apiClient) }
                    }
                    .disabled(
                        viewModel.newDeviceName.trimmingCharacters(in: .whitespaces).isEmpty
                            || viewModel.isLoading
                    )
                }
            }
            .navigationTitle("Add Printer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: viewModel.createdDevice) { device in
            if device != nil { dismiss() }
        }
    }
}

struct APIKeyModal: View {
    let device: DeviceCreateResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "key.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 8) {
                    Text("Save Your API Key")
                        .font(.title2.bold())
                    Text("This key will only be shown once.\nCopy it to your Pi's config.ini.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Device: \(device.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(device.apiKey)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = device.apiKey
                    } label: {
                        Label("Copy API Key", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer()

                Button("Done — I've saved the key") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("New Printer Added")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }
}
