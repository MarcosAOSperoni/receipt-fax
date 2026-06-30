import Foundation

struct MultipartBuilder {
    let boundary = "Boundary-\(UUID().uuidString.prefix(8))"
    private var body = Data()

    mutating func addField(name: String, value: String) {
        body += "--\(boundary)\r\n".utf8Data
        body += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8Data
        body += "\(value)\r\n".utf8Data
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data fileData: Data) {
        body += "--\(boundary)\r\n".utf8Data
        body += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8Data
        body += "Content-Type: \(mimeType)\r\n\r\n".utf8Data
        body += fileData
        body += "\r\n".utf8Data
    }

    func build() -> (data: Data, boundary: String) {
        var result = body
        result += "--\(boundary)--\r\n".utf8Data
        return (result, boundary)
    }
}

private extension String {
    var utf8Data: Data { Data(utf8) }
}

private func += (lhs: inout Data, rhs: Data) { lhs.append(rhs) }
