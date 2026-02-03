// Basic macOS SwiftUI App Template
// Replace "MyMacApp" with your app name

import SwiftUI

@main
struct MyMacApp: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .commands {
            // Custom menu commands
            CommandMenu("Actions") {
                Button("Perform Action") {
                    performAction()
                }
                .keyboardShortcut("p", modifiers: .command)

                Divider()

                Button("Another Action") {
                    anotherAction()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }

        // Settings/Preferences window
        Settings {
            SettingsView()
        }
    }

    // MARK: - Actions

    private func performAction() {
        print("Action performed")
        // TODO: Implement your action
    }

    private func anotherAction() {
        print("Another action performed")
        // TODO: Implement your action
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @State private var selectedItem: String? = "home"

    var body: some View {
        NavigationView {
            // Sidebar
            SidebarView(selection: $selectedItem)

            // Detail view
            DetailView(selectedItem: selectedItem)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            Section("Main") {
                Label("Home", systemImage: "house")
                    .tag("home")

                Label("Projects", systemImage: "folder")
                    .tag("projects")

                Label("Documents", systemImage: "doc")
                    .tag("documents")
            }

            Section("Settings") {
                Label("Preferences", systemImage: "gear")
                    .tag("preferences")
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 250)
    }
}

// MARK: - Detail View

struct DetailView: View {
    let selectedItem: String?

    var body: some View {
        Group {
            switch selectedItem {
            case "home":
                HomeView()
            case "projects":
                ProjectsView()
            case "documents":
                DocumentsView()
            case "preferences":
                PreferencesView()
            default:
                Text("Select an item from the sidebar")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Individual Views

struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Welcome Home")
                .font(.largeTitle)

            Text("This is your home view")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ProjectsView: View {
    @State private var projects = ["Project 1", "Project 2", "Project 3"]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Projects")
                .font(.largeTitle)
                .padding()

            List(projects, id: \.self) { project in
                Text(project)
            }

            Spacer()
        }
    }
}

struct DocumentsView: View {
    var body: some View {
        VStack {
            Text("Documents")
                .font(.largeTitle)

            Text("Your documents will appear here")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct PreferencesView: View {
    var body: some View {
        VStack {
            Text("Preferences")
                .font(.largeTitle)

            Text("Configure your app settings here")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AccountsSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.circle")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 500, height: 350)
        .padding(20)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("enableNotifications") private var enableNotifications = true

    var body: some View {
        Form {
            Section {
                TextField("User Name", text: $userName)

                Toggle("Enable Notifications", isOn: $enableNotifications)
            } header: {
                Text("General Settings")
            }
        }
        .formStyle(.grouped)
    }
}

struct AccountsSettingsView: View {
    var body: some View {
        VStack {
            Text("Accounts")
                .font(.headline)

            Text("Manage your accounts here")
                .foregroundColor(.secondary)

            // TODO: Add account management UI
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("debugMode") private var debugMode = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Debug Mode", isOn: $debugMode)

                Button("Reset All Settings") {
                    // TODO: Implement reset
                    print("Resetting all settings...")
                }
                .foregroundColor(.red)
            } header: {
                Text("Advanced Settings")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
