import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    func refresh(apiClient: APIClient, store: MessageStore) async {
        isLoading = true
        error = nil
        do {
            let messages = try await apiClient.getMessages()
            store.setAll(messages)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func resend(message: MessageResponse, apiClient: APIClient, store: MessageStore) async {
        error = nil
        let tempId = UUID()
        let optimistic = MessageResponse(
            id: tempId,
            deviceId: message.deviceId,
            body: message.body,
            style: message.style,
            imagePath: nil,
            richBody: message.richBody,
            font: message.font,
            status: "pending",
            failureReason: nil,
            createdAt: Date(),
            printedAt: nil
        )
        store.addOptimistic(optimistic)
        do {
            // Reconstruct richLines from richBody if available, else fall back to body/style
            let richLines: [RichLine]
            if let existing = message.richBody, !existing.isEmpty {
                richLines = existing
            } else {
                let text = message.body ?? ""
                richLines = text.components(separatedBy: "\n").map {
                    RichLine(
                        size: message.style.size,
                        align: message.style.align,
                        spans: [RichSpan(text: $0, bold: message.style.bold)]
                    )
                }
            }
            let real = try await apiClient.sendMessage(
                deviceId: message.deviceId,
                richLines: richLines,
                font: message.font ?? "monospace",
                image: nil  // images cannot be resent without re-uploading
            )
            store.replace(temporaryId: tempId, with: real)
        } catch {
            store.remove(id: tempId)
            self.error = error.localizedDescription
        }
    }
}
