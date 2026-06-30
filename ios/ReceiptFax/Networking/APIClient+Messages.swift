import UIKit

extension APIClient {
    func getMessages() async throws -> [MessageResponse] {
        try await request("/api/v1/messages")
    }

    func sendMessage(
        deviceId: UUID,
        body: String?,
        style: MessageStyle,
        image: UIImage?
    ) async throws -> MessageResponse {
        var form = MultipartBuilder()
        form.addField(name: "device_id", value: deviceId.uuidString)
        if let body, !body.isEmpty {
            form.addField(name: "body", value: body)
        }
        let styleJSON = (try? String(data: Self.encoder.encode(style), encoding: .utf8)) ?? "{}"
        form.addField(name: "style", value: styleJSON)
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
