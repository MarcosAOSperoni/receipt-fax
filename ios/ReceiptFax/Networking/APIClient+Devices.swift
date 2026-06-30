import Foundation

extension APIClient {
    func getDevices() async throws -> [DeviceResponse] {
        try await request("/api/v1/devices")
    }

    func createDevice(name: String) async throws -> DeviceCreateResponse {
        let body = try Self.encoder.encode(DeviceCreateBody(name: name))
        return try await request("/api/v1/devices", method: "POST", body: body)
    }

    func deleteDevice(id: UUID) async throws {
        try await requestVoid("/api/v1/devices/\(id.uuidString)")
    }
}
