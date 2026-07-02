import SwiftUI
import PhotosUI

struct ComposeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var messageStore: MessageStore
    @StateObject private var viewModel = ComposeViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var devices: [DeviceResponse] = []
    @State private var selectedDeviceId: UUID?
    @State private var showDevicePicker = false

    private var currentLine: RichLine {
        let lines = viewModel.richLines
        guard !lines.isEmpty else {
            return RichLine(size: "normal", align: "left", spans: [RichSpan(text: "", bold: false)])
        }
        let idx = min(viewModel.currentLineIndex, lines.count - 1)
        return lines[max(0, idx)]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FormattingToolbar(
                    isBoldActive: viewModel.isBoldActive,
                    currentSize: currentLine.size,
                    currentAlign: currentLine.align,
                    onToggleBold: viewModel.toggleBold,
                    onSetSize: viewModel.setSize,
                    onSetAlign: viewModel.setAlign
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        RichTextEditor(
                            richLines: $viewModel.richLines,
                            isBoldActive: $viewModel.isBoldActive,
                            currentLineIndex: $viewModel.currentLineIndex,
                            boldTrigger: viewModel.boldTrigger
                        )
                        .frame(minHeight: 120)
                        .padding(4)

                        if let image = viewModel.selectedImage {
                            imageAttachmentView(image: image)
                        }

                        ReceiptPreview(
                            richLines: viewModel.richLines,
                            selectedImage: viewModel.selectedImage
                        )
                    }
                    .padding()
                }

                Divider()

                bottomBar
            }
            .navigationTitle("Compose")
        }
        .onChange(of: selectedItem) { item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                viewModel.selectedImage = image
            }
        }
        .sheet(isPresented: $showDevicePicker) {
            DevicePickerSheet(
                devices: devices,
                selectedDeviceId: $selectedDeviceId
            ) { id in
                showDevicePicker = false
                Task { await viewModel.send(deviceId: id, apiClient: appState.apiClient, store: messageStore) }
            }
        }
        .task {
            devices = (try? await appState.apiClient.getDevices()) ?? []
            selectedDeviceId = devices.first?.id
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Image(systemName: "photo.badge.plus").font(.title2)
            }

            if let error = viewModel.error {
                Text(error).font(.caption).foregroundStyle(.red).lineLimit(1)
            }

            Spacer()

            Button { handleSend() } label: {
                if viewModel.isSending {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Send")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSend || viewModel.isSending)
        }
        .padding()
    }

    private func imageAttachmentView(image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 160)
                .cornerRadius(8)
            Button {
                viewModel.selectedImage = nil
                selectedItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .padding(4)
        }
    }

    private func handleSend() {
        guard viewModel.checkDevices(devices) else { return }
        if devices.count == 1, let id = devices.first?.id {
            Task { await viewModel.send(deviceId: id, apiClient: appState.apiClient, store: messageStore) }
        } else {
            showDevicePicker = true
        }
    }
}

struct DevicePickerSheet: View {
    let devices: [DeviceResponse]
    @Binding var selectedDeviceId: UUID?
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(devices) { device in
                Button {
                    selectedDeviceId = device.id
                    onSelect(device.id)
                } label: {
                    HStack {
                        Text(device.name)
                        Spacer()
                        if selectedDeviceId == device.id {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Send To")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
