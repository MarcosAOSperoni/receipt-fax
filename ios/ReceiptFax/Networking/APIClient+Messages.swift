import UIKit

extension APIClient {
    func getMessages() async throws -> [MessageResponse] {
        try await request("/api/v1/messages")
    }

    func sendMessage(
        deviceId: UUID,
        richLines: [RichLine],
        image: UIImage?
    ) async throws -> MessageResponse {
        var form = MultipartBuilder()
        form.addField(name: "device_id", value: deviceId.uuidString)

        let plain = richLines.map { $0.spans.map(\.text).joined() }.joined(separator: "\n")
        if !plain.isEmpty {
            form.addField(name: "body", value: plain)
        }
        form.addField(name: "style", value: "{\"bold\":false,\"size\":\"normal\",\"align\":\"left\"}")

        if let richBodyData = try? Self.encoder.encode(richLines),
           let richBodyStr = String(data: richBodyData, encoding: .utf8) {
            form.addField(name: "rich_body", value: richBodyStr)
        }

        if let image, let jpeg = image.jpegData(compressionQuality: 0.85) {
            form.addFile(name: "image", filename: "photo.jpg", mimeType: "image/jpeg", data: jpeg)
        }
        let (formData, boundary) = form.build()
        return try await request(
            "/api/v1/messages",
            method: "POST",
            body: formData,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    func deleteMessage(id: UUID) async throws {
        try await requestVoid("/api/v1/messages/\(id.uuidString)")
    }
}
