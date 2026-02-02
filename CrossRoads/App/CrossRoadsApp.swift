import SwiftUI

@main
struct CrossRoadsApp: App {

    /// Global application state
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.appState, appState)
                .frame(
                    minWidth: Theme.Layout.minWindowWidth,
                    minHeight: Theme.Layout.minWindowHeight
                )
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: Theme.Layout.defaultWindowWidth,
            height: Theme.Layout.defaultWindowHeight
        )
    }
}
