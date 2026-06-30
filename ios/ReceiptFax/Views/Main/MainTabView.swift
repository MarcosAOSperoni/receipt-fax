import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var messageStore: MessageStore
    @StateObject private var settingsViewModel = SettingsViewModel()

    var body: some View {
        TabView {
            ComposeView()
                .tabItem { Label("Compose", systemImage: "pencil") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            SettingsView(viewModel: settingsViewModel)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .task {
            await messageStore.reload(apiClient: appState.apiClient)
        }
    }
}
