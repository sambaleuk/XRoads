import Foundation
import GRDB
import os

// MARK: - CockpitDatabaseManager

/// Manages the SQLite database for cockpit session persistence.
/// Handles schema creation and versioned migrations.
actor CockpitDatabaseManager {

    private let logger = Logger(subsystem: "com.xroads", category: "CockpitDB")

    /// The GRDB database queue (thread-safe access)
    let dbQueue: DatabaseQueue

    /// Initialize with a file path for persistent storage
    init(path: String) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        self.dbQueue = try DatabaseQueue(path: path, configuration: config)
        try migrator.migrate(dbQueue)
        let dbPath = path
        logger.info("CockpitDB initialized at \(dbPath)")
    }

    /// Initialize with an in-memory database (for testing)
    init() throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        self.dbQueue = try DatabaseQueue(configuration: config)
        try migrator.migrate(dbQueue)
        logger.info("CockpitDB initialized in-memory")
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_cockpit_tables") { db in
            // CockpitSession table
            try db.create(table: "cockpit_session") { t in
                t.primaryKey("id", .text).notNull()
                t.column("projectPath", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "idle")
                t.column("chairmanBrief", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Unique index: one active session per project_path
            // (active = not closed)
            try db.create(
                index: "idx_cockpit_session_project_active",
                on: "cockpit_session",
                columns: ["projectPath", "status"],
                unique: true,
                condition: Column("status") != "closed"
            )

            // AgentSlot table with FK to CockpitSession
            try db.create(table: "agent_slot") { t in
                t.primaryKey("id", .text).notNull()
                t.column("cockpitSessionId", .text)
                    .notNull()
                    .references("cockpit_session", onDelete: .cascade)
                t.column("slotIndex", .integer).notNull()
                t.column("status", .text).notNull().defaults(to: "empty")
                t.column("agentType", .text).notNull()
                t.column("worktreePath", .text)
                t.column("branchName", .text)
                t.column("skillId", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Indexes from model.json
            try db.create(
                index: "idx_agent_slot_slot_index",
                on: "agent_slot",
                columns: ["slotIndex"]
            )
            try db.create(
                index: "idx_agent_slot_status",
                on: "agent_slot",
                columns: ["status"]
            )
        }

        return migrator
    }

    /// Path to the default cockpit database file
    static func defaultPath() throws -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("XRoads")

        try FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )

        return appSupport.appendingPathComponent("cockpit.sqlite").path
    }
}
