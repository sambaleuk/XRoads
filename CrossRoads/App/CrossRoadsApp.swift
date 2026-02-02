import SwiftUI

@main
struct CrossRoadsApp: App {

    /// Global application state
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appState, appState)
        }
        .windowStyle(.automatic)
    }
}
