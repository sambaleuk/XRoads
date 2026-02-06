//
//  XRoadsLogger.swift
//  XRoads
//
//  Structured logging using os.Logger with subsystem filtering.
//  Replaces raw print() calls throughout the codebase.
//

import os

/// Centralized logging for XRoads using Apple's unified logging system (`os.Logger`).
///
/// Usage:
/// ```swift
/// Log.mcp.debug("Searching for MCP server...")
/// Log.loop.info("Slot \(slotNumber) launched")
/// Log.dashboard.error("Slot not found")
/// ```
///
/// View logs in Console.app with subsystem filter: `com.xroads`
enum Log {
    /// Subsystem identifier for all XRoads logs
    static let subsystem = "com.xroads"

    // MARK: - Service Loggers

    /// MCP client / server communication
    static let mcp = Logger(subsystem: subsystem, category: "mcp")

    /// Loop launcher and management
    static let loop = Logger(subsystem: subsystem, category: "loop")

    /// Status monitor
    static let status = Logger(subsystem: subsystem, category: "status")

    /// Layered dispatcher
    static let dispatcher = Logger(subsystem: subsystem, category: "dispatcher")

    /// Action runner
    static let action = Logger(subsystem: subsystem, category: "action")

    /// Orchestrator service
    static let orchestrator = Logger(subsystem: subsystem, category: "orchestrator")

    /// Agent launcher
    static let agent = Logger(subsystem: subsystem, category: "agent")

    // MARK: - UI Loggers

    /// Dashboard views
    static let dashboard = Logger(subsystem: subsystem, category: "dashboard")

    /// Text field and input components
    static let input = Logger(subsystem: subsystem, category: "input")

    /// Modal panels and sheets
    static let modal = Logger(subsystem: subsystem, category: "modal")

    /// App lifecycle
    static let app = Logger(subsystem: subsystem, category: "app")
}
