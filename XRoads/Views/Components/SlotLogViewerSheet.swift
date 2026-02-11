//
//  SlotLogViewerSheet.swift
//  XRoads
//
//  Created by Nexus on 2026-02-11.
//  Full log viewer sheet for a terminal slot
//

import SwiftUI
import AppKit

struct SlotLogViewerSheet: View {
    let slot: TerminalSlot
    @State private var filterLevel: LogLevel? = nil
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredLogs: [LogEntry] {
        slot.logs.filter { entry in
            (filterLevel == nil || entry.level == filterLevel) &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(Color.borderMuted)

            // Toolbar: filters + search
            toolbar

            Divider()
                .background(Color.borderMuted)

            // Log content
            if filteredLogs.isEmpty {
                emptyState
            } else {
                TerminalView(logs: filteredLogs, style: .wide)
            }

            Divider()
                .background(Color.borderMuted)

            // Footer
            footer
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color.bgCanvas)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "terminal")
                .foregroundStyle(agentColor)

            Text("SLOT \(slot.slotNumber)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)

            if let agent = slot.agentType {
                Text("•")
                    .foregroundStyle(agentColor)
                Text(agent.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(agentColor)
            }

            if let branch = slot.worktree?.branch {
                Text("on")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Text(branch)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.accentPrimary)
            }

            Spacer()

            SlotStatusBadge(status: slot.status, compact: true)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.bgSurface)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Level filter
            HStack(spacing: 2) {
                filterButton(label: "All", level: nil)
                filterButton(label: "Info", level: .info)
                filterButton(label: "Warn", level: .warn)
                filterButton(label: "Error", level: .error)
            }
            .padding(2)
            .background(Color.bgSurface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)

                TextField("Search logs...", text: $searchText)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderMuted, lineWidth: 1)
            )

            Spacer()

            Text("\(filteredLogs.count) entries")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(Color.bgCanvas)
    }

    private func filterButton(label: String, level: LogLevel?) -> some View {
        let isActive = filterLevel == level
        return Button {
            filterLevel = level
        } label: {
            Text(label)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isActive ? Color.white : Color.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? levelColor(for: level).opacity(0.8) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func levelColor(for level: LogLevel?) -> Color {
        guard let level else { return Color.accentPrimary }
        switch level {
        case .debug: return Color.textTertiary
        case .info: return Color.terminalCyan
        case .warn: return Color.terminalYellow
        case .error: return Color.terminalRed
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Color.textTertiary)
            Text("No matching logs")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            if !searchText.isEmpty || filterLevel != nil {
                Text("Try adjusting your filters")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                exportToClipboard()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                    Text("Copy to Clipboard")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.borderMuted, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderMuted, lineWidth: 1)
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.bgCanvas)
    }

    // MARK: - Actions

    private func exportToClipboard() {
        let text = filteredLogs.map { entry in
            "\(entry.formattedTimestamp) \(entry.level.displayName) [\(entry.source)] \(entry.message)"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Computed

    private var agentColor: Color {
        slot.agentType?.neonColor ?? Color(red: 0.0, green: 0.9, blue: 1.0)
    }
}
