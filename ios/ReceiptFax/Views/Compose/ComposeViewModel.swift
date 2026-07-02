import UIKit

@MainActor
final class ComposeViewModel: ObservableObject {
    @Published var richLines: [RichLine] = [
        RichLine(size: "normal", align: "left", spans: [RichSpan(text: "", bold: false)])
    ]
    @Published var selectedImage: UIImage?
    @Published var isSending = false
    @Published var error: String?
    @Published var isBoldActive = false
    @Published var currentLineIndex = 0
    @Published var boldTrigger = UUID()

    var canSend: Bool {
        richLines.contains { $0.spans.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
        || selectedImage != nil
    }

    var plainBody: String {
        richLines.map { $0.spans.map(\.text).joined() }.joined(separator: "\n")
    }

    func toggleBold() { boldTrigger = UUID() }

    func setSize(_ size: String) {
        guard currentLineIndex < richLines.count else { return }
        richLines[currentLineIndex].size = size
    }

    func setAlign(_ align: String) {
        guard currentLineIndex < richLines.count else { return }
        richLines[currentLineIndex].align = align
    }

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
        let body = plainBody.isEmpty ? nil : plainBody
        let optimistic = MessageResponse(
            id: tempId,
            deviceId: deviceId,
            body: body,
            style: MessageStyle(),
            imagePath: nil,
            richBody: richLines,
            status: "pending",
            failureReason: nil,
            createdAt: Date(),
            printedAt: nil
        )
        store.addOptimistic(optimistic)

        do {
            let real = try await apiClient.sendMessage(
                deviceId: deviceId,
                richLines: richLines,
                image: selectedImage
            )
            store.replace(temporaryId: tempId, with: real)
            richLines = [RichLine(size: "normal", align: "left", spans: [RichSpan(text: "", bold: false)])]
            selectedImage = nil
            isBoldActive = false
            currentLineIndex = 0
        } catch {
            store.remove(id: tempId)
            self.error = error.localizedDescription
        }
        isSending = false
    }
}
