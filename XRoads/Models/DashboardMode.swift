//
//  DashboardMode.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  Dashboard display modes for XRoads
//

import Foundation

/// Dashboard display mode
enum DashboardMode: String, Codable, Sendable, CaseIterable {
    /// Single large terminal view for focused work
    case single

    /// Multi-terminal hexagonal layout with central orchestrator
    case agentic

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .agentic: return "Agentic"
        }
    }

    var description: String {
        switch self {
        case .single:
            return "Single focused terminal for one agent"
        case .agentic:
            return "Multi-agent orchestration with 6 terminals"
        }
    }

    var iconName: String {
        switch self {
        case .single: return "rectangle"
        case .agentic: return "hexagon"
        }
    }

    /// Maximum number of terminal slots for this mode
    var maxSlots: Int {
        switch self {
        case .single: return 1
        case .agentic: return 6
        }
    }

    /// Whether this mode shows the central orchestrator
    var showsOrchestrator: Bool {
        switch self {
        case .single: return false
        case .agentic: return true
        }
    }

    /// Whether this mode shows the side panels
    var showsSidePanels: Bool {
        switch self {
        case .single: return false
        case .agentic: return true
        }
    }
}
