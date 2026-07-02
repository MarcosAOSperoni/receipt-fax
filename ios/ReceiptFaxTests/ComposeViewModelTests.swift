import XCTest
import UIKit
@testable import ReceiptFax

@MainActor
final class ComposeViewModelTests: XCTestCase {
    var sut: ComposeViewModel!

    override func setUp() async throws {
        sut = ComposeViewModel()
    }

    func testInitialState() {
        XCTAssertEqual(sut.richLines.count, 1)
        XCTAssertEqual(sut.richLines[0].size, "normal")
        XCTAssertEqual(sut.richLines[0].align, "left")
        XCTAssertEqual(sut.richLines[0].spans[0].text, "")
        XCTAssertFalse(sut.richLines[0].spans[0].bold)
        XCTAssertNil(sut.selectedImage)
        XCTAssertFalse(sut.isSending)
        XCTAssertFalse(sut.canSend)
        XCTAssertFalse(sut.isBoldActive)
        XCTAssertEqual(sut.currentLineIndex, 0)
    }

    func testCanSendWithNonEmptySpan() {
        sut.richLines = [RichLine(size: "normal", align: "left", spans: [RichSpan(text: "Hello", bold: false)])]
        XCTAssertTrue(sut.canSend)
    }

    func testCanSendWithImage() {
        sut.selectedImage = UIImage()
        XCTAssertTrue(sut.canSend)
    }

    func testWhitespaceOnlyCannotSend() {
        sut.richLines = [RichLine(size: "normal", align: "left", spans: [RichSpan(text: "   ", bold: false)])]
        XCTAssertFalse(sut.canSend)
    }

    func testToggleBoldChangesTrigger() {
        let initial = sut.boldTrigger
        sut.toggleBold()
        XCTAssertNotEqual(sut.boldTrigger, initial)
    }

    func testSetSizeUpdatesCurrentLine() {
        sut.currentLineIndex = 0
        sut.setSize("large")
        XCTAssertEqual(sut.richLines[0].size, "large")
        sut.setSize("header")
        XCTAssertEqual(sut.richLines[0].size, "header")
        sut.setSize("normal")
        XCTAssertEqual(sut.richLines[0].size, "normal")
    }

    func testSetAlignUpdatesCurrentLine() {
        sut.currentLineIndex = 0
        sut.setAlign("center")
        XCTAssertEqual(sut.richLines[0].align, "center")
        sut.setAlign("left")
        XCTAssertEqual(sut.richLines[0].align, "left")
    }

    func testSetSizeOutOfBoundsIsNoOp() {
        sut.currentLineIndex = 99
        sut.setSize("large")  // must not crash
    }

    func testPlainBodyJoinsSpans() {
        sut.richLines = [
            RichLine(size: "normal", align: "left", spans: [
                RichSpan(text: "Hello ", bold: false),
                RichSpan(text: "world", bold: true)
            ]),
            RichLine(size: "normal", align: "left", spans: [RichSpan(text: "Line 2", bold: false)])
        ]
        XCTAssertEqual(sut.plainBody, "Hello world\nLine 2")
    }

    func testPlainBodyEmptyWhenOnlyEmptySpans() {
        // initial state
        XCTAssertEqual(sut.plainBody, "")
    }

    func testCheckDevicesReturnsFalseAndSetsErrorWhenEmpty() {
        let result = sut.checkDevices([])
        XCTAssertFalse(result)
        XCTAssertEqual(sut.error, "Add a device in Settings first.")
    }

    func testCheckDevicesReturnsTrueWhenDevicesAvailable() {
        let device = DeviceResponse(id: UUID(), name: "Printer 1", lastSeenAt: Date(), createdAt: Date())
        let result = sut.checkDevices([device])
        XCTAssertTrue(result)
        XCTAssertNil(sut.error)
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

        sut.richLines = [RichLine(size: "normal", align: "left", spans: [RichSpan(text: "Hello", bold: false)])]
        await sut.send(deviceId: deviceId, apiClient: apiClient, store: store)

        XCTAssertEqual(sut.richLines.count, 1)
        XCTAssertEqual(sut.richLines[0].spans[0].text, "")
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

        sut.richLines = [RichLine(size: "normal", align: "left", spans: [RichSpan(text: "Hello", bold: false)])]
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
         "created_at":"2026-06-30T12:00:00.000000Z","printed_at":null,
         "rich_body":null}
        """.data(using: .utf8)!
    }
}
