//
//  ActionPickerMenu.swift
//  XRoads
//
//  Created by Nexus on 2026-02-03.
//  UI component for selecting action type when configuring a terminal slot
//

import SwiftUI

// MARK: - ActionPickerMenu

/// Main action picker component for selecting an action type
/// Groups actions by category and shows required skills
struct ActionPickerMenu: View {
    /// Currently selected action
    @Binding var selectedAction: ActionType?

    /// Optional CLI type to filter compatible actions
    var cliType: AgentType?

    /// Callback when an action is selected
    var onSelect: ((ActionType) -> Void)?

    /// Whether to show as a compact inline picker or full menu
    var style: ActionPickerStyle = .menu

    /// Available skills to check action compatibility
    @State private var availableSkillIDs: Set<String> = []

    /// Track if skills have been loaded
    @State private var isLoaded: Bool = false

    var body: some View {
        Group {
            switch style {
            case .menu:
                menuStyle
            case .inline:
                inlineStyle
            case .compact:
                compactStyle
            }
        }
        .task {
            await loadAvailableSkills()
        }
    }

    // MARK: - Menu Style

    private var menuStyle: some View {
        Menu {
            ForEach(ActionCategory.allCases, id: \.self) { category in
                Section(category.displayName) {
                    ForEach(actionsInCategory(category), id: \.self) { action in
                        actionButton(for: action)
                    }
                }
            }
        } label: {
            menuLabel
        }
        .menuStyle(.borderlessButton)
    }

    private var menuLabel: some View {
        HStack {
            if let action = selectedAction {
                Image(systemName: action.iconName)
                    .foregroundStyle(actionColor(for: action))
                Text(action.displayName)
            } else {
                Text("Select Action")
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
        }
        .font(.small)
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.bgElevated)
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: - Inline Style

    private var inlineStyle: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(ActionCategory.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Category header
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(categoryColor(category))
                            .frame(width: 8, height: 8)
                        Text(category.displayName)
                            .font(.small)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.bottom, Theme.Spacing.xs)

                    // Actions in category
                    ForEach(actionsInCategory(category), id: \.self) { action in
                        inlineActionRow(for: action)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
    }

    private func inlineActionRow(for action: ActionType) -> some View {
        let isDisabled = !isActionAvailable(action)
        let isSelected = selectedAction == action

        return Button {
            if !isDisabled {
                selectedAction = action
                onSelect?(action)
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                // Icon
                Image(systemName: action.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(isDisabled ? Color.textTertiary : actionColor(for: action))
                    .frame(width: 20)

                // Title and description
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(action.displayName)
                            .font(.small)
                            .fontWeight(.medium)
                            .foregroundStyle(isDisabled ? Color.textTertiary : Color.textPrimary)

                        if action.includesUnitTests {
                            Text("+ TU")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.statusInfo)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.statusInfo.opacity(0.15))
                                .cornerRadius(Theme.Radius.xs)
                        }
                    }

                    Text(action.description)
                        .font(.xs)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Skills badge
                if !action.requiredSkills.isEmpty {
                    skillsBadge(for: action, isDisabled: isDisabled)
                }

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(isSelected ? Color.accentPrimary.opacity(0.1) : Color.clear)
            .background(isDisabled ? Color.bgSurface.opacity(0.5) : Color.clear)
            .cornerRadius(Theme.Radius.sm)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - Compact Style

    private var compactStyle: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ActionType.allCases.filter { $0 != .custom }, id: \.self) { action in
                compactActionButton(for: action)
            }
        }
    }

    private func compactActionButton(for action: ActionType) -> some View {
        let isDisabled = !isActionAvailable(action)
        let isSelected = selectedAction == action

        return Button {
            if !isDisabled {
                selectedAction = action
                onSelect?(action)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.iconName)
                    .font(.system(size: 16))
                Text(action.displayName)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .foregroundStyle(
                isDisabled ? Color.textTertiary :
                    (isSelected ? Color.accentPrimary : actionColor(for: action))
            )
            .frame(width: 60, height: 50)
            .background(isSelected ? Color.accentPrimary.opacity(0.15) : Color.bgElevated)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Color.accentPrimary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(action.description)
    }

    // MARK: - Action Button (for Menu Style)

    private func actionButton(for action: ActionType) -> some View {
        let isDisabled = !isActionAvailable(action)

        return Button {
            selectedAction = action
            onSelect?(action)
        } label: {
            HStack {
                Label(action.displayName, systemImage: action.iconName)
                Spacer()
                if !action.requiredSkills.isEmpty {
                    Text("\(action.requiredSkills.count) skills")
                        .font(.xs)
                        .foregroundStyle(Color.textTertiary)
                }
                if selectedAction == action {
                    Image(systemName: "checkmark")
                }
            }
        }
        .disabled(isDisabled)
    }

    // MARK: - Skills Badge

    private func skillsBadge(for action: ActionType, isDisabled: Bool) -> some View {
        let missingCount = missingSkillCount(for: action)
        let totalCount = action.requiredSkills.count

        return HStack(spacing: 2) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 9))
            Text("\(totalCount - missingCount)/\(totalCount)")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(missingCount > 0 ? Color.statusWarning : Color.textTertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            missingCount > 0 ? Color.statusWarning.opacity(0.1) : Color.bgSurface
        )
        .cornerRadius(Theme.Radius.xs)
    }

    // MARK: - Helper Methods

    private func actionsInCategory(_ category: ActionCategory) -> [ActionType] {
        ActionType.allCases.filter { $0.category == category && $0 != .custom }
    }

    private func isActionAvailable(_ action: ActionType) -> Bool {
        // Custom actions are always available
        if action == .custom {
            return true
        }

        // If no CLI specified, all actions are available
        guard cliType != nil else {
            return true
        }

        // Check if all required skills are available for this CLI
        let requiredSkills = action.requiredSkills
        if requiredSkills.isEmpty {
            return true
        }

        // Check each required skill is available
        for skillID in requiredSkills {
            if !availableSkillIDs.contains(skillID) {
                return false
            }
        }

        return true
    }

    private func missingSkillCount(for action: ActionType) -> Int {
        let requiredSkills = Set(action.requiredSkills)
        let missing = requiredSkills.subtracting(availableSkillIDs)
        return missing.count
    }

    private func loadAvailableSkills() async {
        let registry = SkillRegistry.shared
        await registry.initialize()

        if let cli = cliType {
            let skills = await registry.skills(for: cli)
            availableSkillIDs = Set(skills.map { $0.id })
        } else {
            let allSkillIDs = await registry.allSkillIDs()
            availableSkillIDs = Set(allSkillIDs)
        }
        isLoaded = true
    }

    private func actionColor(for action: ActionType) -> Color {
        switch action.category {
        case .dev:
            return .statusInfo
        case .qa:
            return .statusSuccess
        case .ops:
            return .statusWarning
        }
    }

    private func categoryColor(_ category: ActionCategory) -> Color {
        switch category {
        case .dev:
            return .statusInfo
        case .qa:
            return .statusSuccess
        case .ops:
            return .statusWarning
        }
    }
}

// MARK: - ActionPickerStyle

/// Defines the visual style of the action picker
enum ActionPickerStyle {
    /// Dropdown menu style (default)
    case menu
    /// Expanded inline list with descriptions
    case inline
    /// Compact horizontal button bar
    case compact
}

// MARK: - ActionPickerPopover

/// A popover wrapper for the action picker with additional context
struct ActionPickerPopover: View {
    @Binding var selectedAction: ActionType?
    var cliType: AgentType?
    var onSelect: ((ActionType) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Select Action")
                    .font(.h3)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if let cli = cliType {
                    HStack(spacing: 4) {
                        Image(systemName: cli.iconName)
                        Text(cli.displayName)
                    }
                    .font(.xs)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.sm)
                }
            }
            .padding(Theme.Spacing.md)

            Divider()
                .background(Color.borderMuted)

            // Action list
            ScrollView {
                ActionPickerMenu(
                    selectedAction: $selectedAction,
                    cliType: cliType,
                    onSelect: { action in
                        onSelect?(action)
                        dismiss()
                    },
                    style: .inline
                )
            }
            .frame(maxHeight: 350)
        }
        .frame(width: 320)
        .background(Color.bgSurface)
    }
}

// MARK: - Convenience Extensions

extension ActionType {
    /// Returns a color appropriate for this action type
    var accentColor: Color {
        switch category {
        case .dev:
            return .statusInfo
        case .qa:
            return .statusSuccess
        case .ops:
            return .statusWarning
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ActionPickerMenu_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Menu style
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Menu Style")
                    .font(.h3)
                    .foregroundStyle(Color.textSecondary)
                ActionPickerMenu(
                    selectedAction: .constant(.implement),
                    cliType: .claude,
                    style: .menu
                )
                .frame(width: 200)
            }

            Divider()

            // Compact style
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Compact Style")
                    .font(.h3)
                    .foregroundStyle(Color.textSecondary)
                ActionPickerMenu(
                    selectedAction: .constant(.review),
                    cliType: .gemini,
                    style: .compact
                )
            }

            Divider()

            // Inline style
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Inline Style")
                    .font(.h3)
                    .foregroundStyle(Color.textSecondary)
                ActionPickerMenu(
                    selectedAction: .constant(.integrationTest),
                    cliType: .codex,
                    style: .inline
                )
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Color.bgApp)
        .frame(width: 400)
    }
}

struct ActionPickerPopover_Previews: PreviewProvider {
    static var previews: some View {
        ActionPickerPopover(
            selectedAction: .constant(.implement),
            cliType: .claude
        )
        .background(Color.bgApp)
    }
}
#endif
