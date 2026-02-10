//
//  ToolExecutor.swift
//  XRoads
//
//  Created by Nexus on 2026-02-10.
//  Tool execution for orchestrator API mode (bash, read_file, list_directory)
//

import Foundation

/// Executes tools requested by the Anthropic API during orchestrator chat.
/// Wraps ProcessRunner for bash execution and FileManager for file operations.
actor ToolExecutor {
    private let processRunner: ProcessRunner
    private let workingDirectory: String

    /// Maximum output length returned to the API (characters)
    private static let maxOutputLength = 30000

    /// Maximum iterations for the tool-use loop
    static let maxToolIterations = 10

    init(processRunner: ProcessRunner, workingDirectory: String) {
        self.processRunner = processRunner
        self.workingDirectory = workingDirectory
    }

    // MARK: - Tool Definitions

    /// Tool definitions in the Anthropic API format (dictionary-based, matching existing code style)
    static let toolDefinitions: [[String: Any]] = [
        [
            "name": "bash",
            "description": "Execute a bash command and return stdout/stderr. Use for running build commands, git operations, and other shell tasks.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "command": ["type": "string", "description": "The bash command to execute"]
                ],
                "required": ["command"]
            ] as [String: Any]
        ],
        [
            "name": "read_file",
            "description": "Read the contents of a file at the given path.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Absolute or relative file path to read"]
                ],
                "required": ["path"]
            ] as [String: Any]
        ],
        [
            "name": "list_directory",
            "description": "List files and directories at the given path.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Directory path (defaults to working directory if empty)"]
                ],
                "required": [] as [String]
            ] as [String: Any]
        ]
    ]

    // MARK: - Execution

    /// Execute a tool by name with the given input parameters.
    /// Returns (content, isError) tuple.
    func execute(toolName: String, input: [String: Any]) async -> (content: String, isError: Bool) {
        switch toolName {
        case "bash":
            return await executeBash(input: input)
        case "read_file":
            return await executeReadFile(input: input)
        case "list_directory":
            return await executeListDirectory(input: input)
        default:
            return ("Unknown tool: \(toolName)", true)
        }
    }

    // MARK: - Tool Implementations

    private func executeBash(input: [String: Any]) async -> (content: String, isError: Bool) {
        guard let command = input["command"] as? String, !command.isEmpty else {
            return ("Missing required parameter: command", true)
        }

        // Basic safety: reject obviously destructive commands
        if command.contains("rm -rf /") && !command.contains("rm -rf ./") {
            return ("Refused: potentially destructive command", true)
        }

        do {
            let result = try await processRunner.execute(
                executable: "/bin/bash",
                arguments: ["-c", command],
                currentDirectory: workingDirectory
            )

            var output = ""
            if !result.stdout.isEmpty {
                output += result.stdout
            }
            if !result.stderr.isEmpty {
                if !output.isEmpty { output += "\n" }
                output += result.stderr
            }
            if output.isEmpty {
                output = "(no output)"
            }

            // Truncate if too long
            if output.count > Self.maxOutputLength {
                output = String(output.prefix(Self.maxOutputLength)) + "\n... (truncated)"
            }

            let isError = result.exitCode != 0
            if isError {
                output = "Exit code: \(result.exitCode)\n\(output)"
            }

            return (output, isError)
        } catch {
            return ("Failed to execute command: \(error.localizedDescription)", true)
        }
    }

    private func executeReadFile(input: [String: Any]) async -> (content: String, isError: Bool) {
        guard let path = input["path"] as? String, !path.isEmpty else {
            return ("Missing required parameter: path", true)
        }

        let resolvedPath = resolvePath(path)

        // Safety: only allow reading within workingDirectory or /tmp
        guard isPathAllowed(resolvedPath) else {
            return ("Access denied: path outside allowed directories", true)
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: resolvedPath) else {
            return ("File not found: \(resolvedPath)", true)
        }

        do {
            var content = try String(contentsOfFile: resolvedPath, encoding: .utf8)
            if content.count > Self.maxOutputLength {
                content = String(content.prefix(Self.maxOutputLength)) + "\n... (truncated)"
            }
            return (content, false)
        } catch {
            return ("Failed to read file: \(error.localizedDescription)", true)
        }
    }

    private func executeListDirectory(input: [String: Any]) async -> (content: String, isError: Bool) {
        let path = (input["path"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? workingDirectory
        let resolvedPath = resolvePath(path)

        guard isPathAllowed(resolvedPath) else {
            return ("Access denied: path outside allowed directories", true)
        }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: resolvedPath, isDirectory: &isDir), isDir.boolValue else {
            return ("Not a directory: \(resolvedPath)", true)
        }

        do {
            let items = try fm.contentsOfDirectory(atPath: resolvedPath).sorted()
            if items.isEmpty {
                return ("(empty directory)", false)
            }
            let listing = items.joined(separator: "\n")
            return (listing, false)
        } catch {
            return ("Failed to list directory: \(error.localizedDescription)", true)
        }
    }

    // MARK: - Helpers

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        // Resolve relative to working directory
        return (workingDirectory as NSString).appendingPathComponent(path)
    }

    private func isPathAllowed(_ path: String) -> Bool {
        let resolved = (path as NSString).standardizingPath
        return resolved.hasPrefix(workingDirectory) || resolved.hasPrefix("/tmp")
    }
}
