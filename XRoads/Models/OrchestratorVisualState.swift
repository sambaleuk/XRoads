//
//  OrchestratorVisualState.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Visual states for the central orchestrator creature
//

import Foundation
import SwiftUI

/// Visual states for the orchestrator creature animation
enum OrchestratorVisualState: String, Codable, Sendable, CaseIterable {
    /// Neutral state, minimal animation
    case idle

    /// "Thinking" state - analyzing PRD or planning
    case planning

    /// Sending tasks to agents - rays toward terminals
    case distributing

    /// Actively monitoring agent progress
    case monitoring

    /// Gathering results from completed agents
    case synthesizing

    /// All tasks completed successfully
    case celebrating

    /// Problems detected in one or more agents
    case concerned

    /// No agents running, low power mode
    case sleeping

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .planning: return "Planning"
        case .distributing: return "Distributing"
        case .monitoring: return "Monitoring"
        case .synthesizing: return "Synthesizing"
        case .celebrating: return "Complete!"
        case .concerned: return "Attention Needed"
        case .sleeping: return "Sleeping"
        }
    }

    /// Primary color for this state
    var color: Color {
        switch self {
        case .idle: return .creatureIdle
        case .planning: return .creaturePlanning
        case .distributing: return .creatureDistributing
        case .monitoring: return .creatureMonitoring
        case .synthesizing: return .creatureSynthesizing
        case .celebrating: return .creatureCelebrating
        case .concerned: return .creatureConcerned
        case .sleeping: return .creatureSleeping
        }
    }

    /// Animation pulse duration for this state
    var pulseDuration: Double {
        switch self {
        case .idle: return 4.0
        case .planning: return 2.0
        case .distributing: return 0.5
        case .monitoring: return 1.5
        case .synthesizing: return 2.0
        case .celebrating: return 0.8
        case .concerned: return 0.5
        case .sleeping: return 6.0
        }
    }

    /// Glow intensity for this state (0.0 - 1.0)
    var glowIntensity: Double {
        switch self {
        case .idle: return 0.3
        case .planning: return 0.6
        case .distributing: return 0.9
        case .monitoring: return 0.7
        case .synthesizing: return 0.8
        case .celebrating: return 1.0
        case .concerned: return 0.8
        case .sleeping: return 0.1
        }
    }

    /// Rotation speed multiplier for orbital rings
    var rotationSpeed: Double {
        switch self {
        case .idle: return 1.0
        case .planning: return 2.0
        case .distributing: return 4.0
        case .monitoring: return 2.5
        case .synthesizing: return 3.0
        case .celebrating: return 5.0
        case .concerned: return 1.5
        case .sleeping: return 0.3
        }
    }

    /// Whether to show particle effects
    var showsParticles: Bool {
        switch self {
        case .idle, .sleeping: return false
        default: return true
        }
    }

    /// Status message for display
    var statusMessage: String {
        switch self {
        case .idle: return "Waiting for instructions..."
        case .planning: return "Analyzing PRD..."
        case .distributing: return "Assigning tasks to agents..."
        case .monitoring: return "Monitoring agent progress..."
        case .synthesizing: return "Gathering results..."
        case .celebrating: return "All tasks completed!"
        case .concerned: return "Some agents need attention"
        case .sleeping: return "Zzz..."
        }
    }
}
