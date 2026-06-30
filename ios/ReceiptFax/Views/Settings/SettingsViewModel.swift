import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var devices: [DeviceResponse] = []
    @Published var newDeviceName = ""
    @Published var createdDevice: DeviceCreateResponse?
    @Published var isLoading = false
    @Published var error: String?

    func loadDevices(apiClient: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            devices = try await apiClient.getDevices()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addDevice(apiClient: APIClient) async {
        let name = newDeviceName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let created = try await apiClient.createDevice(name: name)
            devices.append(DeviceResponse(
                id: created.id,
                name: created.name,
                lastSeenAt: created.lastSeenAt,
                createdAt: created.createdAt
            ))
            newDeviceName = ""
            createdDevice = created
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteDevice(id: UUID, apiClient: APIClient) async {
        do {
            try await apiClient.deleteDevice(id: id)
            devices.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
