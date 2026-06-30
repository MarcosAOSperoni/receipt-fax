import XCTest
@testable import ReceiptFax

final class APIClientTests: XCTestCase {
    var sut: APIClient!
    var mock: MockURLSession!
    let base = URL(string: "https://test.example.com")!

    override func setUp() {
        mock = MockURLSession()
        sut = APIClient(baseURL: base, session: mock)
    }

    // MARK: - URL building

    func testBuildsCorrectURL() async throws {
        mock.data = "[]".data(using: .utf8)!
        let _: [MessageResponse] = try await sut.request("/api/v1/messages")
        XCTAssertEqual(mock.lastRequest?.url?.absoluteString,
                       "https://test.example.com/api/v1/messages")
    }

    func testStripsTrailingSlashFromBaseURL() throws {
        let client = APIClient(baseURL: URL(string: "https://example.com/")!, session: mock)
        XCTAssertEqual(client.baseURL.absoluteString, "https://example.com")
    }

    // MARK: - Auth header

    func testInjectsAuthorizationHeader() async throws {
        sut.setTokens(access: "my-token", refresh: "ref")
        mock.data = "[]".data(using: .utf8)!
        let _: [MessageResponse] = try await sut.request("/api/v1/messages")
        XCTAssertEqual(mock.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                       "Bearer my-token")
    }

    func testNoAuthHeaderWhenUnauthenticated() async throws {
        mock.data = "[]".data(using: .utf8)!
        let _: [MessageResponse] = try await sut.request("/api/v1/messages")
        XCTAssertNil(mock.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Error handling

    func testHTTPErrorThrows() async throws {
        mock.responses = [MockURLSession.Response(
            data: #"{"detail":"Not found"}"#.data(using: .utf8)!,
            statusCode: 404
        )]
        do {
            let _: [MessageResponse] = try await sut.request("/api/v1/messages")
            XCTFail("Expected APIError.httpError")
        } catch APIError.httpError(let code, let msg) {
            XCTAssertEqual(code, 404)
            XCTAssertEqual(msg, "Not found")
        }
    }

    func testNetworkErrorThrows() async throws {
        mock.error = URLError(.notConnectedToInternet)
        do {
            let _: [MessageResponse] = try await sut.request("/api/v1/messages")
            XCTFail("Expected error")
        } catch APIError.networkError {
            // expected
        }
    }

    // MARK: - 401 refresh + retry

    func test401RefreshesTokenAndRetries() async throws {
        sut.setTokens(access: "expired", refresh: "valid-refresh")

        let refreshJSON = #"{"access_token":"new-access","refresh_token":"new-refresh","token_type":"bearer"}"#
        let messagesJSON = "[]"
        mock.responses = [
            MockURLSession.Response(
                data: #"{"detail":"Unauthorized"}"#.data(using: .utf8)!,
                statusCode: 401
            ),
            MockURLSession.Response(
                data: refreshJSON.data(using: .utf8)!,
                statusCode: 200
            ),
            MockURLSession.Response(
                data: messagesJSON.data(using: .utf8)!,
                statusCode: 200
            ),
        ]

        let result: [MessageResponse] = try await sut.request("/api/v1/messages")

        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(sut.accessToken, "new-access")
        XCTAssertEqual(sut.refreshToken, "new-refresh")
        XCTAssertEqual(mock.allRequests.count, 3)
    }

    func test401WithNoRefreshTokenThrowsNotAuthenticated() async throws {
        mock.responses = [MockURLSession.Response(
            data: Data(), statusCode: 401
        )]
        do {
            let _: [MessageResponse] = try await sut.request("/api/v1/messages")
            XCTFail("Expected APIError.notAuthenticated")
        } catch APIError.notAuthenticated {
            // expected
        }
    }

    func test401WithFailedRefreshPostsNotification() async throws {
        sut.setTokens(access: "expired", refresh: "bad-refresh")

        let expectation = XCTestExpectation(description: "authRefreshFailed notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .authRefreshFailed, object: nil, queue: nil
        ) { _ in expectation.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer) }

        mock.responses = [
            MockURLSession.Response(data: Data(), statusCode: 401),
            MockURLSession.Response(data: #"{"detail":"Invalid refresh"}"#.data(using: .utf8)!, statusCode: 401),
        ]

        do {
            let _: [MessageResponse] = try await sut.request("/api/v1/messages")
        } catch {}

        await fulfillment(of: [expectation], timeout: 2)
    }

    // MARK: - requestVoid

    func testRequestVoidSucceedsOn204() async throws {
        mock.responses = [MockURLSession.Response(data: Data(), statusCode: 204)]
        try await sut.requestVoid("/api/v1/messages/\(UUID())")
    }
}
