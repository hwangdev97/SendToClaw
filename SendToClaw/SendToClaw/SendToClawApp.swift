import SwiftUI

@main
struct SendToClawApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("SendToClaw", systemImage: "mic.circle") {
            MenuBarView(appState: appState)
                .onAppear {
                    appState.setup()
                }
        }
    }
}
