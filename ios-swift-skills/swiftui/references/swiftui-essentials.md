# SwiftUI Essentials for Maestro-like App

## Views & Layouts

### Grid Layout (pour sessions multiples)
```swift
LazyVGrid(columns: [
    GridItem(.flexible()),
    GridItem(.flexible()),
    GridItem(.flexible())
], spacing: 16) {
    ForEach(sessions) { session in
        SessionCardView(session: session)
    }
}
```

### List avec sections
```swift
List {
    Section("Active Sessions") {
        ForEach(activeSessions) { session in
            SessionRowView(session: session)
        }
    }

    Section("Templates") {
        ForEach(templates) { template in
            TemplateRowView(template: template)
        }
    }
}
```

## State Management

### @State - Local state
```swift
struct ContentView: View {
    @State private var isRunning = false
    @State private var outputText = ""

    var body: some View {
        VStack {
            Text(outputText)
            Button(isRunning ? "Stop" : "Start") {
                isRunning.toggle()
            }
        }
    }
}
```

### @StateObject - ViewModel ownership
```swift
struct SessionsView: View {
    @StateObject private var viewModel = SessionsViewModel()

    var body: some View {
        VStack {
            ForEach(viewModel.sessions) { session in
                SessionCard(session: session)
            }
        }
        .task {
            await viewModel.loadSessions()
        }
    }
}
```

### @ObservedObject - Passed ViewModel
```swift
struct SessionCardView: View {
    @ObservedObject var session: SessionViewModel

    var body: some View {
        VStack {
            Text(session.status.rawValue)
            Text(session.output)
        }
    }
}
```

### @Binding - Two-way binding
```swift
struct TerminalView: View {
    @Binding var command: String

    var body: some View {
        TextField("Command", text: $command)
            .onSubmit {
                // Execute command
            }
    }
}
```

## Navigation

### NavigationStack (modern)
```swift
NavigationStack {
    List(sessions) { session in
        NavigationLink(value: session) {
            SessionRowView(session: session)
        }
    }
    .navigationDestination(for: Session.self) { session in
        SessionDetailView(session: session)
    }
    .navigationTitle("Sessions")
}
```

### Sheets & Alerts
```swift
struct ContentView: View {
    @State private var showingSettings = false
    @State private var showingAlert = false

    var body: some View {
        Button("Settings") {
            showingSettings = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}
```

## Terminal-like UI

### ScrollView avec Text
```swift
struct TerminalOutputView: View {
    let output: String

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("bottom")
                    .onChange(of: output) { _, _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
            }
        }
        .background(Color.black)
    }
}
```

### Custom Status Indicator
```swift
struct StatusView: View {
    let status: SessionStatus

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status.rawValue)
                .font(.caption)
        }
    }

    var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .working: return .blue
        case .waiting: return .orange
        case .done: return .green
        case .error: return .red
        }
    }
}
```

## Session Grid Layout

```swift
struct SessionsGridView: View {
    @StateObject var viewModel: SessionsViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(viewModel.sessions) { session in
                    SessionCard(session: session)
                        .frame(height: 400)
                }
            }
            .padding()
        }
    }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: viewModel.columnCount)
    }
}

struct SessionCard: View {
    @ObservedObject var session: SessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(session.name)
                    .font(.headline)
                Spacer()
                StatusView(status: session.status)
            }

            // Terminal output
            TerminalOutputView(output: session.output)

            // Actions
            HStack {
                Button("Run") {
                    Task { await session.run() }
                }
                Button("Stop") {
                    session.stop()
                }
                Button("Clear") {
                    session.clearOutput()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
```

## Toolbar & Commands

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            SessionsGridView(viewModel: viewModel)
                .navigationTitle("Maestro")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Add Session") { }
                            Button("Load Template") { }
                            Button("Settings") { }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
        }
    }
}
```

## Async/Await with SwiftUI

```swift
struct SessionDetailView: View {
    @StateObject var viewModel: SessionViewModel

    var body: some View {
        VStack {
            Text(viewModel.output)
        }
        .task {
            // Runs when view appears
            await viewModel.startMonitoring()
        }
        .task(id: viewModel.sessionId) {
            // Runs when sessionId changes
            await viewModel.loadData()
        }
    }
}
```

## Forms & Settings

```swift
struct SettingsView: View {
    @AppStorage("defaultBranch") private var defaultBranch = "main"
    @AppStorage("maxSessions") private var maxSessions = 6

    var body: some View {
        Form {
            Section("Git") {
                TextField("Default Branch", text: $defaultBranch)
            }

            Section("Sessions") {
                Stepper("Max Sessions: \(maxSessions)", value: $maxSessions, in: 1...12)
            }
        }
        .formStyle(.grouped)
    }
}
```

## Custom Modifiers

```swift
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// Usage
Text("Hello")
    .cardStyle()
```
