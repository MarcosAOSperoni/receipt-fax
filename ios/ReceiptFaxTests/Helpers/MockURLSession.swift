import Foundation
@testable import ReceiptFax

final class MockURLSession: URLSessionProtocol {
    struct Response {
        let data: Data
        let statusCode: Int
    }

    var responses: [Response] = []
    var error: Error?
    var allRequests: [URLRequest] = []
    var lastRequest: URLRequest? { allRequests.last }

    var data: Data {
        get { responses.first?.data ?? Data() }
        set { responses = [Response(data: newValue, statusCode: statusCode)] }
    }
    var statusCode: Int = 200

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        allRequests.append(request)
        if let error { throw error }
        let response = responses.isEmpty
            ? Response(data: Data(), statusCode: statusCode)
            : responses.removeFirst()
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response.data, http)
    }
}
