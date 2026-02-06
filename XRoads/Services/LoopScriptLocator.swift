import Foundation

/// Locates Nexus Loop scripts with fallback logic
/// Priority: 1. Bundled scripts 2. User's ~/bin 3. ~/.nexus
struct LoopScriptLocator: Sendable {

    enum LoopType: String, CaseIterable, Sendable {
        case nexus = "nexus-loop"
        case gemini = "gemini-loop"
        case codex = "codex-loop"

        var agentType: AgentType {
            switch self {
            case .nexus: return .claude
            case .gemini: return .gemini
            case .codex: return .codex
            }
        }

        var displayName: String {
            switch self {
            case .nexus: return "Nexus Loop (Claude)"
            case .gemini: return "Gemini Loop"
            case .codex: return "Codex Loop"
            }
        }
    }

    /// Finds the path to a loop script for an agent type
    static func findLoopScript(for agentType: AgentType) -> String? {
        switch agentType {
        case .claude:
            return findLoop(.nexus)
        case .gemini:
            return findLoop(.gemini)
        case .codex:
            return findLoop(.codex)
        }
    }

    enum ScriptType: String, CaseIterable, Sendable {
        case nexusInit = "nexus-init"
        case nexusLoop = "nexus-loop"
        case geminiLoop = "gemini-loop"
        case codexLoop = "codex-loop"

        var displayName: String {
            switch self {
            case .nexusInit: return "Nexus Init"
            case .nexusLoop: return "Nexus Loop (Claude)"
            case .geminiLoop: return "Gemini Loop"
            case .codexLoop: return "Codex Loop"
            }
        }

        var description: String {
            switch self {
            case .nexusInit: return "Initialize project with PRD template"
            case .nexusLoop: return "Autonomous development with Claude"
            case .geminiLoop: return "Autonomous development with Gemini"
            case .codexLoop: return "Autonomous development with Codex"
            }
        }

        var iconName: String {
            switch self {
            case .nexusInit: return "folder.badge.plus"
            case .nexusLoop: return "arrow.triangle.2.circlepath"
            case .geminiLoop: return "arrow.triangle.2.circlepath"
            case .codexLoop: return "arrow.triangle.2.circlepath"
            }
        }
    }

    /// Finds the path to a loop script
    /// - Parameter type: The type of loop to find
    /// - Returns: Path to the script, or nil if not found
    static func findLoop(_ type: LoopType) -> String? {
        let scriptName = type.rawValue
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // 1. Check bundled scripts (relative to app bundle or repo)
        let bundledPaths = [
            Bundle.main.resourcePath.map { "\($0)/scripts/\(scriptName)" },
            // If running from Xcode/swift run, check repo structure
            findRepoScriptsPath(scriptName: scriptName)
        ].compactMap { $0 }

        for path in bundledPaths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 2. Check user's ~/bin (installed via install.sh or manually)
        let userBinPath = "\(home)/bin/\(scriptName)"
        if fm.isExecutableFile(atPath: userBinPath) {
            return userBinPath
        }

        // 3. Check ~/.nexus/bin (legacy location)
        let nexusBinPath = "\(home)/.nexus/bin/\(scriptName)"
        if fm.isExecutableFile(atPath: nexusBinPath) {
            return nexusBinPath
        }

        // 4. Try which command as last resort
        if let path = shellWhich(scriptName) {
            return path
        }

        return nil
    }

    /// Finds the common.sh library path
    static func findCommonLib() -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // 1. Bundled
        let bundledPaths = [
            Bundle.main.resourcePath.map { "\($0)/scripts/lib/common.sh" },
            findRepoScriptsPath(scriptName: "lib/common.sh")
        ].compactMap { $0 }

        for path in bundledPaths {
            if fm.fileExists(atPath: path) {
                return path
            }
        }

        // 2. User's ~/.nexus
        let nexusLibPath = "\(home)/.nexus/lib/common.sh"
        if fm.fileExists(atPath: nexusLibPath) {
            return nexusLibPath
        }

        return nil
    }

    /// Finds the path to any script
    static func findScript(_ type: ScriptType) -> String? {
        let scriptName = type.rawValue
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // 1. Check bundled scripts
        let bundledPaths = [
            Bundle.main.resourcePath.map { "\($0)/scripts/\(scriptName)" },
            findRepoScriptsPath(scriptName: scriptName)
        ].compactMap { $0 }

        for path in bundledPaths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 2. Check user's ~/bin
        let userBinPath = "\(home)/bin/\(scriptName)"
        if fm.isExecutableFile(atPath: userBinPath) {
            return userBinPath
        }

        // 3. Try which command
        if let path = shellWhich(scriptName) {
            return path
        }

        return nil
    }

    /// Checks which loops are available
    static func checkAvailability() -> [LoopType: Bool] {
        var result: [LoopType: Bool] = [:]
        for type in LoopType.allCases {
            result[type] = findLoop(type) != nil
        }
        return result
    }

    /// Checks which scripts are available
    static func checkScriptAvailability() -> [ScriptType: Bool] {
        var result: [ScriptType: Bool] = [:]
        for type in ScriptType.allCases {
            result[type] = findScript(type) != nil
        }
        return result
    }

    /// Script status with path info
    struct ScriptStatus: Sendable {
        let type: ScriptType
        let isInstalled: Bool
        let path: String?
        let source: String // "bundled", "user", "not found"
    }

    /// Get detailed status for all scripts
    static func getScriptStatuses() -> [ScriptStatus] {
        return ScriptType.allCases.map { type in
            if let path = findScript(type) {
                let source: String
                if path.contains("CrossRoads/scripts") || path.contains(".app/Contents") {
                    source = "bundled"
                } else {
                    source = "user"
                }
                return ScriptStatus(type: type, isInstalled: true, path: path, source: source)
            } else {
                return ScriptStatus(type: type, isInstalled: false, path: nil, source: "not found")
            }
        }
    }

    /// Path to the install.sh script
    static func findInstallScript() -> String? {
        let fm = FileManager.default

        // Check bundled
        if let bundled = Bundle.main.resourcePath {
            let path = "\(bundled)/scripts/install.sh"
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Check repo
        if let repoPath = findRepoScriptsPath(scriptName: "install.sh") {
            if fm.isExecutableFile(atPath: repoPath) {
                return repoPath
            }
        }

        return nil
    }

    /// Returns info about where loops were found
    static func diagnostics() -> String {
        var lines: [String] = ["Loop Script Locations:"]
        for type in LoopType.allCases {
            if let path = findLoop(type) {
                lines.append("  \(type.rawValue): \(path)")
            } else {
                lines.append("  \(type.rawValue): NOT FOUND")
            }
        }
        if let lib = findCommonLib() {
            lines.append("  common.sh: \(lib)")
        } else {
            lines.append("  common.sh: NOT FOUND")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    /// Attempts to find repo scripts directory when running in development
    private static func findRepoScriptsPath(scriptName: String) -> String? {
        // When running via `swift run`, we might be in the repo
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath

        // Check common development paths
        let possibleRepoPaths = [
            "\(cwd)/scripts/\(scriptName)",
            "\(cwd)/../scripts/\(scriptName)",
            "\(cwd)/../../scripts/\(scriptName)"
        ]

        for path in possibleRepoPaths {
            let resolvedPath = (path as NSString).standardizingPath
            if fm.fileExists(atPath: resolvedPath) {
                return resolvedPath
            }
        }

        return nil
    }

    private static func shellWhich(_ command: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(command)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }
}
