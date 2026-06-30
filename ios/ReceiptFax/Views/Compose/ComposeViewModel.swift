import UIKit

@MainActor
final class ComposeViewModel: ObservableObject {
    @Published var body = ""
    @Published var style = MessageStyle()
    @Published var selectedImage: UIImage?
    @Published var isSending = false
    @Published var error: String?

    var canSend: Bool {
        !body.trimmingCharacters(in: .whitespaces).isEmpty || selectedImage != nil
    }

    var previewLines: [String] {
        body.components(separatedBy: "\n").flatMap { line -> [String] in
            guard !line.isEmpty else { return [""] }
            var result: [String] = []
            var remaining = line
            while remaining.count > 42 {
                result.append(String(remaining.prefix(42)))
                remaining = String(remaining.dropFirst(42))
            }
            result.append(remaining)
            return result
        }
    }

    func toggleBold() { style.bold.toggle() }
    func setSize(_ size: String) { style.size = size }
    func setAlign(_ align: String) { style.align = align }

    func checkDevices(_ devices: [DeviceResponse]) -> Bool {
        guard !devices.isEmpty else {
            error = "Add a device in Settings first."
            return false
        }
        return true
    }

    func send(deviceId: UUID, apiClient: APIClient, store: MessageStore) async {
        guard canSend, !isSending else { return }
        isSending = true
        error = nil

        let tempId = UUID()
        let optimistic = MessageResponse(
            id: tempId,
            deviceId: deviceId,
            body: body.isEmpty ? nil : body,
            style: style,
            imagePath: nil,
            status: "pending",
            failureReason: nil,
            createdAt: Date(),
            printedAt: nil
        )
        store.addOptimistic(optimistic)

        do {
            let real = try await apiClient.sendMessage(
                deviceId: deviceId,
                body: body.isEmpty ? nil : body,
                style: style,
                image: selectedImage
            )
            store.replace(temporaryId: tempId, with: real)
            body = ""
            selectedImage = nil
            style = MessageStyle()
        } catch {
            store.remove(id: tempId)
            self.error = error.localizedDescription
        }
        isSending = false
    }
}
