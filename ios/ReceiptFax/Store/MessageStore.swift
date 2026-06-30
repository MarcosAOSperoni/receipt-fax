import Foundation

@MainActor
final class MessageStore: ObservableObject {
    @Published var messages: [String] = []  // replaced in Task 4
}
