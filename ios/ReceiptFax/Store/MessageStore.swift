import Foundation

@MainActor
final class MessageStore: ObservableObject {
    @Published var messages: [MessageResponse] = []

    func reload(apiClient: APIClient) async {
        guard let fetched = try? await apiClient.getMessages() else { return }
        messages = fetched
    }

    func setAll(_ messages: [MessageResponse]) {
        self.messages = messages
    }

    func addOptimistic(_ message: MessageResponse) {
        messages.insert(message, at: 0)
    }

    func replace(temporaryId: UUID, with real: MessageResponse) {
        guard let idx = messages.firstIndex(where: { $0.id == temporaryId }) else { return }
        messages[idx] = real
    }

    func remove(id: UUID) {
        messages.removeAll { $0.id == id }
    }
}
