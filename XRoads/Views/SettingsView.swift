import SwiftUI

// MARK: - SettingsView

/// Main settings view for XRoads preferences
struct SettingsView: View {
    // MARK: - State

    /// Selected settings tab
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            CLISettingsView()
                .tabItem {
                    Label("CLI Paths", systemImage: "terminal")
                }
                .tag(SettingsTab.cli)
        }
        .frame(width: 500, height: 350)
        .background(Color.bgApp)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Settings Tabs

enum SettingsTab: Hashable {
    case general
    case cli
}

// MARK: - GeneralSettingsView

/// General application settings
struct GeneralSettingsView: View {
    // MARK: - App Storage

    /// Default repository path for new worktrees
    @AppStorage("defaultRepoPath") private var defaultRepoPath: String = ""

    /// Whether to auto-start log streaming on launch
    @AppStorage("autoStartLogStreaming") private var autoStartLogStreaming: Bool = true

    /// Maximum number of logs to keep in memory
    @AppStorage("maxLogEntries") private var maxLogEntries: Int = 500

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Default Repository Path", text: $defaultRepoPath)
                        .textFieldStyle(DarkProTextFieldStyle())

                    Button("Browse...") {
                        browseForDirectory()
                    }
                    .buttonStyle(.bordered)
                }

                if !defaultRepoPath.isEmpty {
                    HStack {
                        Image(systemName: directoryExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(directoryExists ? Color.statusSuccess : Color.statusError)

                        Text(directoryExists ? "Directory exists" : "Directory not found")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            } header: {
                Text("Default Repository")
                    .foregroundStyle(Color.textPrimary)
            } footer: {
                Text("The default path used when creating new worktrees")
                    .foregroundStyle(Color.textTertiary)
            }

            Section {
                Toggle("Auto-start log streaming", isOn: $autoStartLogStreaming)
                    .foregroundStyle(Color.textPrimary)

                Picker("Max log entries", selection: $maxLogEntries) {
                    Text("250").tag(250)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text("2000").tag(2000)
                }
                .foregroundStyle(Color.textPrimary)
            } header: {
                Text("Logging")
                    .foregroundStyle(Color.textPrimary)
            } footer: {
                Text("Higher log limits may impact performance")
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgSurface)
        .padding()
    }

    // MARK: - Computed Properties

    private var directoryExists: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: defaultRepoPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    // MARK: - Actions

    private func browseForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select default repository directory"
        panel.prompt = "Select"

        if !defaultRepoPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: defaultRepoPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            defaultRepoPath = url.path
        }
    }
}

// MARK: - CLISettingsView

/// CLI executable path settings
struct CLISettingsView: View {
    // MARK: - App Storage

    @AppStorage("claudeCliPath") private var claudeCliPath: String = "/usr/local/bin/claude"
    @AppStorage("geminiCliPath") private var geminiCliPath: String = "/usr/local/bin/gemini"
    @AppStorage("codexCliPath") private var codexCliPath: String = "/usr/local/bin/codex"

    var body: some View {
        Form {
            Section {
                CLIPathRow(
                    name: "Claude Code",
                    icon: "brain.head.profile",
                    iconColor: Color.accentPrimary,
                    path: $claudeCliPath,
                    defaultPath: "/usr/local/bin/claude"
                )

                CLIPathRow(
                    name: "Gemini CLI",
                    icon: "sparkles",
                    iconColor: Color.statusWarning,
                    path: $geminiCliPath,
                    defaultPath: "/usr/local/bin/gemini"
                )

                CLIPathRow(
                    name: "Codex",
                    icon: "terminal",
                    iconColor: Color.statusSuccess,
                    path: $codexCliPath,
                    defaultPath: "/usr/local/bin/codex"
                )
            } header: {
                Text("CLI Executable Paths")
                    .foregroundStyle(Color.textPrimary)
            } footer: {
                Text("Configure custom paths if CLIs are not in standard locations")
                    .foregroundStyle(Color.textTertiary)
            }

            Section {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .foregroundStyle(Color.statusError)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgSurface)
        .padding()
    }

    // MARK: - Actions

    private func resetToDefaults() {
        claudeCliPath = "/usr/local/bin/claude"
        geminiCliPath = "/usr/local/bin/gemini"
        codexCliPath = "/usr/local/bin/codex"
    }
}

// MARK: - CLIPathRow

/// Row component for CLI path configuration
struct CLIPathRow: View {
    let name: String
    let icon: String
    let iconColor: Color
    @Binding var path: String
    let defaultPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                Text(name)
                    .font(.body14)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                StatusIndicator(isAvailable: isAvailable)
            }

            HStack {
                TextField("Path", text: $path)
                    .textFieldStyle(DarkProTextFieldStyle())
                    .font(.mono(12))

                Button("Browse...") {
                    browseForExecutable()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Computed Properties

    private var isAvailable: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Actions

    private func browseForExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select \(name) executable"
        panel.prompt = "Select"

        // Start in the directory of the current path
        if !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        }

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

// MARK: - StatusIndicator

/// Small indicator showing CLI availability status
struct StatusIndicator: View {
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(isAvailable ? Color.statusSuccess : Color.statusError)
                .frame(width: 8, height: 8)

            Text(isAvailable ? "Available" : "Not found")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - UserDefaults Keys Extension

extension UserDefaults {
    /// Keys for XRoads settings
    enum Keys {
        static let defaultRepoPath = "defaultRepoPath"
        static let autoStartLogStreaming = "autoStartLogStreaming"
        static let maxLogEntries = "maxLogEntries"
        static let claudeCliPath = "claudeCliPath"
        static let geminiCliPath = "geminiCliPath"
        static let codexCliPath = "codexCliPath"
        static let fullAgenticMode = "fullAgenticMode"
    }
}

// MARK: - AppSettings

/// Helper struct to access all settings in a type-safe way
struct AppSettings {
    /// Access to UserDefaults
    private static var defaults: UserDefaults { .standard }

    // MARK: - General Settings

    /// Default repository path for new worktrees
    static var defaultRepoPath: String {
        get { defaults.string(forKey: UserDefaults.Keys.defaultRepoPath) ?? "" }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.defaultRepoPath) }
    }

    /// Whether to auto-start log streaming on launch
    static var autoStartLogStreaming: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.autoStartLogStreaming) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.autoStartLogStreaming) }
    }

    /// Whether Full Agentic Mode is enabled
    static var fullAgenticMode: Bool {
        get { defaults.bool(forKey: UserDefaults.Keys.fullAgenticMode) }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.fullAgenticMode) }
    }

    /// Maximum number of logs to keep in memory
    static var maxLogEntries: Int {
        get {
            let value = defaults.integer(forKey: UserDefaults.Keys.maxLogEntries)
            return value > 0 ? value : 500
        }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.maxLogEntries) }
    }

    // MARK: - CLI Paths

    /// Claude CLI executable path
    static var claudeCliPath: String {
        get { defaults.string(forKey: UserDefaults.Keys.claudeCliPath) ?? "/usr/local/bin/claude" }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.claudeCliPath) }
    }

    /// Gemini CLI executable path
    static var geminiCliPath: String {
        get { defaults.string(forKey: UserDefaults.Keys.geminiCliPath) ?? "/usr/local/bin/gemini" }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.geminiCliPath) }
    }

    /// Codex CLI executable path
    static var codexCliPath: String {
        get { defaults.string(forKey: UserDefaults.Keys.codexCliPath) ?? "/usr/local/bin/codex" }
        set { defaults.set(newValue, forKey: UserDefaults.Keys.codexCliPath) }
    }

    /// Get CLI path for a specific agent type
    static func cliPath(for agentType: AgentType) -> String {
        switch agentType {
        case .claude: return claudeCliPath
        case .gemini: return geminiCliPath
        case .codex: return codexCliPath
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
