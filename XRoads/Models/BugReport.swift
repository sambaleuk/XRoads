//
//  BugReport.swift
//  XRoads
//
//  Bug report model and debug-specific types for the debug dispatch workflow.
//

import Foundation

// MARK: - BugReport

/// Captures the initial signal for a structured debug workflow
struct BugReport: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    let signal: String              // Raw symptom description
    let expected: String            // What should happen
    let actual: String              // What actually happens
    let severity: BugSeverity
    let reproducibility: BugReproducibility
    let affectedFiles: [String]     // Known affected files (can be empty)
    let stackTrace: String?         // Optional stack trace / error output
    let suspectCommit: String?      // Optional suspect commit SHA
    let createdAt: Date

    init(
        id: UUID = UUID(),
        signal: String,
        expected: String,
        actual: String,
        severity: BugSeverity = .medium,
        reproducibility: BugReproducibility = .unknown,
        affectedFiles: [String] = [],
        stackTrace: String? = nil,
        suspectCommit: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.signal = signal
        self.expected = expected
        self.actual = actual
        self.severity = severity
        self.reproducibility = reproducibility
        self.affectedFiles = affectedFiles
        self.stackTrace = stackTrace
        self.suspectCommit = suspectCommit
        self.createdAt = createdAt
    }
}

// MARK: - BugSeverity

enum BugSeverity: String, Codable, Sendable, CaseIterable, Hashable {
    case critical
    case high
    case medium
    case low

    var displayName: String { rawValue.capitalized }

    var priority: PRDPriority {
        switch self {
        case .critical: return .critical
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

// MARK: - BugReproducibility

enum BugReproducibility: String, Codable, Sendable, CaseIterable, Hashable {
    case always
    case intermittent
    case rare
    case unknown

    var displayName: String { rawValue.capitalized }
}

// MARK: - DebugRole

/// Debug-specific story roles for AGENT.md generation
enum DebugRole: String, Codable, Sendable, Hashable {
    case reproducer           // Layer 0: Write failing test
    case blastRadiusAnalyst   // Layer 0: Map callers, coverage, contracts
    case regressionDetector   // Layer 0: git blame, bisect logic
    case investigator         // Layer 1: Explore a hypothesis
    case fixAuthor            // Layer 2: Implement minimal fix
    case guardAuthor          // Layer 2: Write non-regression tests
    case suiteRunner          // Layer 3: Run full test suite
    case patternScanner       // Layer 3: Scan codebase for same anti-pattern
    case retexAuthor          // Layer 4: Write RETEX + update knowledge

    var displayName: String {
        switch self {
        case .reproducer: return "Bug Reproducer"
        case .blastRadiusAnalyst: return "Blast Radius Analyst"
        case .regressionDetector: return "Regression Detector"
        case .investigator: return "Hypothesis Investigator"
        case .fixAuthor: return "Fix Author"
        case .guardAuthor: return "Guard Author"
        case .suiteRunner: return "Suite Runner"
        case .patternScanner: return "Pattern Scanner"
        case .retexAuthor: return "RETEX Author"
        }
    }

    /// Preferred agent type for this role
    var preferredAgent: AgentType {
        switch self {
        case .reproducer: return .claude
        case .blastRadiusAnalyst: return .gemini
        case .regressionDetector: return .gemini
        case .investigator: return .claude
        case .fixAuthor: return .claude
        case .guardAuthor: return .claude
        case .suiteRunner: return .codex
        case .patternScanner: return .gemini
        case .retexAuthor: return .gemini
        }
    }

    /// Story ID prefix for this role
    var storyIdPrefix: String {
        switch self {
        case .reproducer: return "BUG-REPRO"
        case .blastRadiusAnalyst: return "BUG-BLAST"
        case .regressionDetector: return "BUG-REGR"
        case .investigator: return "BUG-H"
        case .fixAuthor: return "BUG-FIX"
        case .guardAuthor: return "BUG-GUARD"
        case .suiteRunner: return "BUG-SUITE"
        case .patternScanner: return "BUG-SCAN"
        case .retexAuthor: return "BUG-RETEX"
        }
    }
}
