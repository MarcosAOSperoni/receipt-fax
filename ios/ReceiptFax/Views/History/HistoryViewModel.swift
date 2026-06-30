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
            status: "pending",
            failureReason: nil,
            createdAt: Date(),
            printedAt: nil
        )
        store.addOptimistic(optimistic)
        do {
            let real = try await apiClient.sendMessage(
                deviceId: message.deviceId,
                body: message.body,
                style: message.style,
                image: nil  // images cannot be resent without re-uploading
            )
            store.replace(temporaryId: tempId, with: real)
        } catch {
            store.remove(id: tempId)
            self.error = error.localizedDescription
        }
    }
}
