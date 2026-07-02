import XCTest
@testable import ReceiptFax

@MainActor
final class HistoryViewModelTests: XCTestCase {
    var sut: HistoryViewModel!
    var mock: MockURLSession!
    var apiClient: APIClient!
    var store: MessageStore!

    override func setUp() async throws {
        sut = HistoryViewModel()
        mock = MockURLSession()
        apiClient = APIClient(baseURL: URL(string: "https://test")!, session: mock)
        apiClient.setTokens(access: "tok", refresh: "ref")
        store = MessageStore()
    }

    func testRefreshPopulatesStore() async throws {
        mock.data = oneMessageJSON()
        await sut.refresh(apiClient: apiClient, store: store)

        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].body, "Hello")
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func testRefreshSetsErrorOnFailure() async throws {
        mock.error = URLError(.notConnectedToInternet)
        await sut.refresh(apiClient: apiClient, store: store)

        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func testResendCreatesNewPendingMessage() async throws {
        let deviceId = UUID()
        let original = makeMessage(body: "Retry me", deviceId: deviceId, status: "failed")

        mock.responses = [MockURLSession.Response(
            data: makeMessageJSON(body: "Retry me", deviceId: deviceId, status: "pending"),
            statusCode: 201
        )]

        await sut.resend(message: original, apiClient: apiClient, store: store)

        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].status, "pending")
        XCTAssertEqual(store.messages[0].body, "Retry me")
    }

    func testResendRollsBackOnFailure() async throws {
        mock.error = URLError(.notConnectedToInternet)
        let original = makeMessage(body: "Retry me", deviceId: UUID(), status: "failed")

        await sut.resend(message: original, apiClient: apiClient, store: store)

        XCTAssertEqual(store.messages.count, 0)
        XCTAssertNotNil(sut.error)
    }

    // MARK: - Helpers

    private func oneMessageJSON() -> Data {
        makeMessagesJSON(body: "Hello", deviceId: UUID(), status: "pending")
    }

    /// Returns a JSON array `[{...}]` — for `getMessages` mock responses.
    private func makeMessagesJSON(body: String, deviceId: UUID, status: String) -> Data {
        """
        [{"id":"\(UUID())","device_id":"\(deviceId)","body":"\(body)",
          "style":{"bold":false,"size":"normal","align":"left"},
          "image_path":null,"status":"\(status)","failure_reason":null,
          "created_at":"2026-06-30T12:00:00.000000Z","printed_at":null}]
        """.data(using: .utf8)!
    }

    /// Returns a single JSON object `{...}` — for single-message mock responses (e.g. sendMessage).
    private func makeMessageJSON(body: String, deviceId: UUID, status: String) -> Data {
        """
        {"id":"\(UUID())","device_id":"\(deviceId)","body":"\(body)",
         "style":{"bold":false,"size":"normal","align":"left"},
         "image_path":null,"status":"\(status)","failure_reason":null,
         "created_at":"2026-06-30T12:00:00.000000Z","printed_at":null}
        """.data(using: .utf8)!
    }

    private func makeMessage(body: String, deviceId: UUID, status: String) -> MessageResponse {
        MessageResponse(
            id: UUID(), deviceId: deviceId, body: body,
            style: MessageStyle(), imagePath: nil, richBody: nil, status: status,
            failureReason: "Printer offline", createdAt: Date(), printedAt: nil
        )
    }
}
