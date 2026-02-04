//
//  SkillsBrowserView.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  Interface for browsing and managing available skills
//

import SwiftUI

// MARK: - SkillsBrowserView

struct SkillsBrowserView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = SkillsViewModel()
    @State private var selectedSkill: Skill? = nil
    @State private var showDetailSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            skillsHeader

            Divider()
                .background(Color.borderDefault)

            // Content area
            if viewModel.isLoading {
                loadingView
            } else if viewModel.allSkills.isEmpty {
                emptyStateView
            } else {
                skillsContent
            }
        }
        .background(Color.bgSurface)
        .task {
            await viewModel.loadSkills()
        }
        .sheet(isPresented: $showDetailSheet) {
            if let skill = selectedSkill {
                SkillDetailView(
                    skill: skill,
                    isEnabled: viewModel.isSkillEnabled(skill),
                    onToggle: { viewModel.toggleSkill(skill) },
                    onDismiss: { showDetailSheet = false }
                )
            }
        }
    }

    // MARK: - Header

    private var skillsHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Title and count
            HStack {
                Text("Skills")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("\(viewModel.filteredSkillCount)/\(viewModel.totalSkillCount)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgElevated)
                    .cornerRadius(4)

                Spacer()

                // Reload button
                Button {
                    Task { await viewModel.reloadSkills() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Reload skills")
            }

            // Search bar
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)

                TextField("Search skills...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .background(Color.bgCanvas)
            .cornerRadius(Theme.Radius.sm)

            // Filter chips
            HStack(spacing: Theme.Spacing.sm) {
                // Category filter
                Menu {
                    Button("All Categories") {
                        viewModel.selectedCategory = nil
                    }
                    Divider()
                    ForEach(SkillCategory.allCases, id: \.self) { category in
                        Button {
                            viewModel.selectedCategory = category
                        } label: {
                            Label {
                                HStack {
                                    Text(category.displayName)
                                    if let count = viewModel.categoryCounts[category] {
                                        Text("(\(count))")
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                }
                            } icon: {
                                Image(systemName: category.iconName)
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        icon: viewModel.selectedCategory?.iconName ?? "folder",
                        label: viewModel.selectedCategory?.displayName ?? "All Categories",
                        isActive: viewModel.selectedCategory != nil
                    )
                }
                .menuStyle(.borderlessButton)

                // CLI filter
                Menu {
                    Button("All CLIs") {
                        viewModel.selectedCLI = nil
                    }
                    Divider()
                    ForEach(AgentType.allCases, id: \.self) { cli in
                        Button {
                            viewModel.selectedCLI = cli
                        } label: {
                            Label(cli.displayName, systemImage: cli.iconName)
                        }
                    }
                } label: {
                    FilterChip(
                        icon: viewModel.selectedCLI?.iconName ?? "terminal",
                        label: viewModel.selectedCLI?.displayName ?? "All CLIs",
                        isActive: viewModel.selectedCLI != nil
                    )
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Clear filters
                if viewModel.selectedCategory != nil || viewModel.selectedCLI != nil || !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearFilters()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Content

    private var skillsContent: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                // Grouped by category
                ForEach(viewModel.availableCategories, id: \.self) { category in
                    if let skills = viewModel.skillsByCategory[category], !skills.isEmpty {
                        Section {
                            ForEach(skills, id: \.id) { skill in
                                SkillRowView(
                                    skill: skill,
                                    isEnabled: viewModel.isSkillEnabled(skill),
                                    isUserSkill: false, // Will be updated async
                                    hasMissingTools: !viewModel.hasRequiredTools(skill),
                                    missingTools: viewModel.missingTools(for: skill),
                                    onToggle: { viewModel.toggleSkill(skill) },
                                    onSelect: {
                                        selectedSkill = skill
                                        showDetailSheet = true
                                    }
                                )
                            }
                        } header: {
                            CategorySectionHeader(category: category, count: skills.count)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading skills...")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.textTertiary)

            Text("No Skills Found")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            Text("Skills help agents perform specialized tasks.\nAdd skills to ~/.xroads/skills/ directory.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.reloadSkills() }
            } label: {
                Label("Reload Skills", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let icon: String
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
        }
        .foregroundStyle(isActive ? Color.accentPrimary : Color.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(isActive ? Color.accentPrimary.opacity(0.1) : Color.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(isActive ? Color.accentPrimary.opacity(0.3) : Color.borderDefault, lineWidth: 1)
        )
    }
}

// MARK: - Category Section Header

private struct CategorySectionHeader: View {
    let category: SkillCategory
    let count: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: category.iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(categoryColor)

            Text(category.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("(\(count))")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.bgSurface.opacity(0.95))
    }

    private var categoryColor: Color {
        switch category {
        case .git: return .statusInfo
        case .code: return .accentPrimary
        case .test: return .statusSuccess
        case .docs: return .statusWarning
        case .review: return Color(red: 0.8, green: 0.4, blue: 1.0)
        case .custom: return .textSecondary
        }
    }
}

// MARK: - Skill Detail View (Sheet)

private struct SkillDetailView: View {
    let skill: Skill
    let isEnabled: Bool
    let onToggle: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    HStack(spacing: Theme.Spacing.xs) {
                        Text("v\(skill.version)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.textTertiary)

                        if let category = skill.category {
                            Text("|")
                                .foregroundStyle(Color.textTertiary)
                            Image(systemName: category.iconName)
                                .font(.system(size: 10))
                            Text(category.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }

                        if let author = skill.author {
                            Text("|")
                                .foregroundStyle(Color.textTertiary)
                            Text("by \(author)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.lg)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Description
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Description")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        Text(skill.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textPrimary)
                    }

                    // CLI Compatibility
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Compatible CLIs")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(AgentType.allCases, id: \.self) { cli in
                                CLICompatibilityBadge(
                                    cli: cli,
                                    isCompatible: skill.isCompatible(with: cli)
                                )
                            }
                        }
                    }

                    // Required Tools
                    if !skill.requiredTools.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Required Tools")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)

                            SkillsFlowLayout(spacing: 6) {
                                ForEach(skill.requiredTools, id: \.self) { tool in
                                    Text(tool)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.textPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.bgElevated)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Toggle
                    HStack {
                        Text(isEnabled ? "Enabled for this project" : "Disabled for this project")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Button {
                            onToggle()
                        } label: {
                            Text(isEnabled ? "Disable" : "Enable")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isEnabled ? Color.statusError : Color.statusSuccess)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Color.bgElevated)
                    .cornerRadius(Theme.Radius.md)
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .frame(width: 500, height: 450)
        .background(Color.bgSurface)
    }
}

// MARK: - SkillsFlowLayout (for tags/tools)

private struct SkillsFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SkillsBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        SkillsBrowserView()
            .frame(width: 600, height: 700)
            .background(Color.bgApp)
    }
}
#endif
