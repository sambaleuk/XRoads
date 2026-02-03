# macOS-Specific Swift Development

## AppKit vs SwiftUI

For macOS apps, you have two main UI framework choices:

### SwiftUI (Modern, Recommended for New Projects)
- Declarative, cross-platform (macOS, iOS, watchOS, tvOS)
- Less boilerplate, automatic state management
- macOS 10.15+ (Catalina and newer)

### AppKit (Legacy, More Control)
- Imperative, macOS-only
- More fine-grained control, mature ecosystem
- Required for macOS 10.14 and below

## Basic macOS App Structure (SwiftUI)

```swift
import SwiftUI

@main
struct MyMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // Add custom menu commands
            CommandMenu("Custom") {
                Button("Do Something") {
                    print("Action performed")
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
            }
        }
    }
}

struct ContentView: View {
    @State private var text = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, macOS!")
                .font(.largeTitle)

            TextField("Enter text", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            Button("Submit") {
                print("Submitted: \(text)")
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
```

## macOS Window Management

```swift
// Multiple windows
WindowGroup {
    ContentView()
}

// Settings window
Settings {
    SettingsView()
}

// Single window (utility, preferences)
Window("About", id: "about") {
    AboutView()
}

// Document-based app
DocumentGroup(newDocument: MyDocument()) { file in
    DocumentView(document: file.$document)
}
```

## Menu Bar Integration

```swift
struct MyMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // Replace existing commands
            CommandGroup(replacing: .newItem) {
                Button("New Custom Item") {
                    // Action
                }
            }

            // Add to existing menu
            CommandGroup(after: .toolbar) {
                Button("Custom Tool") {
                    // Action
                }
            }

            // Custom menu
            CommandMenu("Tools") {
                Button("Tool 1") { }
                Button("Tool 2") { }
                Divider()
                Button("Tool 3") { }
            }
        }
    }
}
```

## Toolbar Customization

```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            Text("Content")
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { }) {
                    Image(systemName: "sidebar.left")
                }
            }

            ToolbarItem {
                Button(action: { }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
```

## Sidebar Navigation (macOS Style)

```swift
struct ContentView: View {
    @State private var selection: String?

    var body: some View {
        NavigationView {
            // Sidebar
            List(selection: $selection) {
                Section("Main") {
                    NavigationLink("Home", tag: "home", selection: $selection) {
                        HomeView()
                    }
                    NavigationLink("Projects", tag: "projects", selection: $selection) {
                        ProjectsView()
                    }
                }

                Section("Settings") {
                    NavigationLink("Preferences", tag: "prefs", selection: $selection) {
                        PreferencesView()
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)

            // Default view
            Text("Select an item")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

## File Operations (macOS)

```swift
import UniformTypeIdentifiers

// Open file picker
func openFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.text, .json]

    if panel.runModal() == .OK, let url = panel.url {
        // Read file
        do {
            let content = try String(contentsOf: url)
            print(content)
        } catch {
            print("Error reading file: \(error)")
        }
    }
}

// Save file picker
func saveFile(content: String) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.text]
    panel.nameFieldStringValue = "untitled.txt"

    if panel.runModal() == .OK, let url = panel.url {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving file: \(error)")
        }
    }
}
```

## Preferences Window Pattern

```swift
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
        .frame(width: 500, height: 300)
    }
}
```

## Keyboard Shortcuts

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Button("Save") {
                save()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("New") {
                createNew()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
```

## App Sandbox & Entitlements

For Mac App Store distribution, configure entitlements in Xcode:

```xml
<!-- Example: MyApp.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

Common entitlements:
- `com.apple.security.app-sandbox` - Enable sandbox
- `com.apple.security.files.user-selected.read-write` - User-selected files
- `com.apple.security.network.client` - Outgoing network connections
- `com.apple.security.network.server` - Incoming network connections

## AppKit Interop (When Needed)

```swift
import SwiftUI
import AppKit

// Wrap NSView in SwiftUI
struct NSViewWrapper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.red.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update view
    }
}

// Use in SwiftUI
struct ContentView: View {
    var body: some View {
        NSViewWrapper()
            .frame(width: 200, height: 200)
    }
}
```

## Status Bar App (Menu Bar Extra)

```swift
@main
struct MyStatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "star", accessibilityDescription: "App")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }

    @objc func statusBarButtonClicked() {
        print("Status bar clicked")
    }
}
```

## Native Alerts & Dialogs

```swift
func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        print("OK clicked")
    }
}
```

## Drag & Drop

```swift
struct ContentView: View {
    @State private var droppedText = "Drop here"

    var body: some View {
        Text(droppedText)
            .frame(width: 300, height: 200)
            .background(Color.gray.opacity(0.2))
            .onDrop(of: [.text], isTargeted: nil) { providers in
                providers.first?.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
                    if let data = data as? Data,
                       let text = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            droppedText = text
                        }
                    }
                }
                return true
            }
    }
}
```
