import XCTest
@testable import ReceiptFax

@MainActor
final class ComposeViewModelTests: XCTestCase {
    var sut: ComposeViewModel!

    override func setUp() async throws {
        sut = ComposeViewModel()
    }

    func testInitialState() {
        XCTAssertEqual(sut.body, "")
        XCTAssertFalse(sut.style.bold)
        XCTAssertEqual(sut.style.size, "normal")
        XCTAssertEqual(sut.style.align, "left")
        XCTAssertNil(sut.selectedImage)
        XCTAssertFalse(sut.isSending)
        XCTAssertFalse(sut.canSend)
    }

    func testCanSendWithBody() {
        sut.body = "Hello"
        XCTAssertTrue(sut.canSend)
    }

    func testCanSendWithImage() {
        sut.selectedImage = UIImage()
        XCTAssertTrue(sut.canSend)
    }

    func testWhitespaceBodyCannotSend() {
        sut.body = "   "
        XCTAssertFalse(sut.canSend)
    }

    func testToggleBold() {
        XCTAssertFalse(sut.style.bold)
        sut.toggleBold()
        XCTAssertTrue(sut.style.bold)
        sut.toggleBold()
        XCTAssertFalse(sut.style.bold)
    }

    func testSetSize() {
        sut.setSize("large")
        XCTAssertEqual(sut.style.size, "large")
        sut.setSize("header")
        XCTAssertEqual(sut.style.size, "header")
        sut.setSize("normal")
        XCTAssertEqual(sut.style.size, "normal")
    }

    func testSetAlign() {
        sut.setAlign("center")
        XCTAssertEqual(sut.style.align, "center")
        sut.setAlign("left")
        XCTAssertEqual(sut.style.align, "left")
    }

    func testPreviewLinesWrapsAt42Chars() {
        sut.body = String(repeating: "A", count: 50)
        XCTAssertEqual(sut.previewLines[0], String(repeating: "A", count: 42))
        XCTAssertEqual(sut.previewLines[1], String(repeating: "A", count: 8))
    }

    func testPreviewLinesPreservesNewlines() {
        sut.body = "Line 1\nLine 2"
        XCTAssertEqual(sut.previewLines.count, 2)
        XCTAssertEqual(sut.previewLines[0], "Line 1")
        XCTAssertEqual(sut.previewLines[1], "Line 2")
    }

    func testSendSuccessClearsComposerAndUpdatesStore() async throws {
        let mock = MockURLSession()
        let apiClient = APIClient(baseURL: URL(string: "https://test")!, session: mock)
        apiClient.setTokens(access: "tok", refresh: "ref")
        let store = MessageStore()
        let deviceId = UUID()

        mock.responses = [MockURLSession.Response(
            data: makeMessageJSON(body: "Hello", deviceId: deviceId),
            statusCode: 201
        )]

        sut.body = "Hello"
        await sut.send(deviceId: deviceId, apiClient: apiClient, store: store)

        XCTAssertEqual(sut.body, "")
        XCTAssertNil(sut.selectedImage)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isSending)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].status, "pending")
    }

    func testSendNetworkFailureSetsErrorAndRollsBack() async throws {
        let mock = MockURLSession()
        mock.error = URLError(.notConnectedToInternet)
        let apiClient = APIClient(baseURL: URL(string: "https://test")!, session: mock)
        apiClient.setTokens(access: "tok", refresh: "ref")
        let store = MessageStore()

        sut.body = "Hello"
        await sut.send(deviceId: UUID(), apiClient: apiClient, store: store)

        XCTAssertNotNil(sut.error)
        XCTAssertEqual(store.messages.count, 0)
        XCTAssertFalse(sut.isSending)
    }

    // MARK: - Helpers

    private func makeMessageJSON(body: String, deviceId: UUID) -> Data {
        """
        {"id":"\(UUID())","device_id":"\(deviceId)","body":"\(body)",
         "style":{"bold":false,"size":"normal","align":"left"},
         "image_path":null,"status":"pending","failure_reason":null,
         "created_at":"2026-06-30T12:00:00.000000Z","printed_at":null}
        """.data(using: .utf8)!
    }
}
