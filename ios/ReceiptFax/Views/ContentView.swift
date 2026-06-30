import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isAuthenticated {
            Text("Home (coming in Task 8)")  // replaced in Task 8
        } else {
            Text("Onboarding (coming in Task 3)")  // replaced in Task 3
        }
    }
}
