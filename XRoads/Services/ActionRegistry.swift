import Foundation

/// Registry for managing available actions per CLI type
/// Handles action availability, custom action registration, and CLI compatibility filtering
actor ActionRegistry {
    /// Singleton instance for app-wide access
    static let shared = ActionRegistry()

    /// Custom actions registered by the user
    private var customActions: [CustomAction] = []

    /// CLI-specific action availability overrides
    private var cliActionOverrides: [AgentType: Set<ActionType>] = [:]

    /// Initialize with default configuration
    init() {}

    // MARK: - Built-in Action Queries

    /// Returns all built-in action types (excluding custom)
    func builtInActions() -> [ActionType] {
        ActionType.allCases.filter { $0 != .custom }
    }

    /// Returns actions available for a specific CLI
    /// - Parameter cliType: The CLI agent type to filter for
    /// - Returns: Array of ActionType available for the specified CLI
    func actions(for cliType: AgentType) -> [ActionType] {
        // Check for CLI-specific overrides
        if let overrides = cliActionOverrides[cliType] {
            return Array(overrides).sorted { $0.rawValue < $1.rawValue }
        }

        // Default: all CLIs support all built-in actions
        // In future, this could filter based on CLI capabilities
        return builtInActions()
    }

    /// Returns actions filtered by category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of ActionType in the specified category
    func actions(in category: ActionCategory) -> [ActionType] {
        ActionType.allCases.filter { $0.category == category }
    }

    /// Returns actions for a specific CLI filtered by category
    /// - Parameters:
    ///   - cliType: The CLI agent type
    ///   - category: The category to filter by
    /// - Returns: Array of ActionType matching both filters
    func actions(for cliType: AgentType, in category: ActionCategory) -> [ActionType] {
        actions(for: cliType).filter { $0.category == category }
    }

    /// Check if a specific action is available for a CLI
    /// - Parameters:
    ///   - action: The action type to check
    ///   - cliType: The CLI agent type
    /// - Returns: True if the action is available
    func isActionAvailable(_ action: ActionType, for cliType: AgentType) -> Bool {
        if action == .custom {
            return !customActions.isEmpty
        }
        return actions(for: cliType).contains(action)
    }

    // MARK: - Custom Action Management

    /// Register a custom action
    /// - Parameter action: The custom action to register
    func registerCustomAction(_ action: CustomAction) {
        // Avoid duplicates by ID
        if !customActions.contains(where: { $0.id == action.id }) {
            customActions.append(action)
        }
    }

    /// Remove a custom action by ID
    /// - Parameter id: The ID of the custom action to remove
    func removeCustomAction(id: String) {
        customActions.removeAll { $0.id == id }
    }

    /// Get all registered custom actions
    /// - Returns: Array of CustomAction
    func allCustomActions() -> [CustomAction] {
        customActions
    }

    /// Get custom actions compatible with a specific CLI
    /// - Parameter cliType: The CLI agent type
    /// - Returns: Array of CustomAction compatible with the CLI
    func customActions(for cliType: AgentType) -> [CustomAction] {
        customActions.filter { $0.isCompatible(with: cliType) }
    }

    // MARK: - CLI Override Management

    /// Set available actions for a specific CLI (override defaults)
    /// - Parameters:
    ///   - actions: Set of available actions
    ///   - cliType: The CLI to configure
    func setAvailableActions(_ actions: Set<ActionType>, for cliType: AgentType) {
        cliActionOverrides[cliType] = actions
    }

    /// Clear CLI-specific overrides
    /// - Parameter cliType: The CLI to reset to defaults
    func clearOverrides(for cliType: AgentType) {
        cliActionOverrides.removeValue(forKey: cliType)
    }

    /// Clear all custom actions and overrides
    func reset() {
        customActions.removeAll()
        cliActionOverrides.removeAll()
    }
}

// MARK: - CustomAction Model

/// Represents a user-defined custom action
struct CustomAction: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let requiredSkills: [String]
    let compatibleCLIs: Set<AgentType>

    /// Create a custom action
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Display name
    ///   - description: What this action does
    ///   - iconName: SF Symbol icon name
    ///   - requiredSkills: Skills needed for this action
    ///   - compatibleCLIs: CLIs that can run this action (empty = all)
    init(
        id: String,
        name: String,
        description: String,
        iconName: String = "gearshape.fill",
        requiredSkills: [String] = [],
        compatibleCLIs: Set<AgentType> = Set(AgentType.allCases)
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.requiredSkills = requiredSkills
        self.compatibleCLIs = compatibleCLIs
    }

    /// Check if this custom action is compatible with a CLI
    /// - Parameter cliType: The CLI to check
    /// - Returns: True if compatible
    func isCompatible(with cliType: AgentType) -> Bool {
        compatibleCLIs.isEmpty || compatibleCLIs.contains(cliType)
    }
}
