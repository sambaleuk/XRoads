import SwiftUI

/// Collapsible panel showing loop scripts installation status
/// Displayed at the bottom of the main window
struct LoopConfigurationPanel: View {
    @State private var isExpanded = false
    @State private var scriptStatuses: [LoopScriptLocator.ScriptStatus] = []
    @State private var isInstalling = false
    @State private var installOutput: String = ""
    @State private var showInstallOutput = false

    var body: some View {
        VStack(spacing: 0) {
            // Toggle bar
            toggleBar

            // Expandable content
            if isExpanded {
                contentPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.bgElevated)
        .onAppear {
            refreshStatuses()
        }
    }

    // MARK: - Toggle Bar

    private var toggleBar: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(Color.accentPrimary)

                Text("Loop Scripts")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textPrimary)

                Spacer()

                // Status indicator
                statusIndicator

                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.bgSurface)
        }
        .buttonStyle(.plain)
    }

    private var statusIndicator: some View {
        let installedCount = scriptStatuses.filter { $0.isInstalled }.count
        let totalCount = scriptStatuses.count

        return HStack(spacing: 4) {
            Circle()
                .fill(installedCount == totalCount ? Color.statusSuccess : Color.statusWarning)
                .frame(width: 8, height: 8)

            Text("\(installedCount)/\(totalCount)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.textSecondary)
        }
    }

    // MARK: - Content Panel

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Scripts list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(scriptStatuses, id: \.type) { status in
                    scriptRow(status)
                }
            }

            Divider()
                .background(Color.borderDefault)

            // Actions
            HStack(spacing: 12) {
                // Install button
                Button(action: runInstaller) {
                    HStack(spacing: 6) {
                        if isInstalling {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(isInstalling ? "Installing..." : "Install to ~/bin")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)

                // Refresh button
                Button(action: refreshStatuses) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(Color.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Show output if available
                if !installOutput.isEmpty {
                    Button(action: { showInstallOutput.toggle() }) {
                        Text(showInstallOutput ? "Hide Output" : "Show Output")
                            .font(.system(size: 11))
                            .foregroundColor(Color.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Install output
            if showInstallOutput && !installOutput.isEmpty {
                ScrollView {
                    Text(installOutput)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
                .padding(8)
                .background(Color.bgApp)
                .cornerRadius(4)
            }

            // Help text
            Text("Scripts enable autonomous development loops. Install globally for CLI access.")
                .font(.system(size: 10))
                .foregroundColor(Color.textTertiary)
        }
        .padding(16)
    }

    private func scriptRow(_ status: LoopScriptLocator.ScriptStatus) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: status.type.iconName)
                .font(.system(size: 14))
                .foregroundColor(status.isInstalled ? Color.statusSuccess : Color.textTertiary)
                .frame(width: 20)

            // Name and description
            VStack(alignment: .leading, spacing: 2) {
                Text(status.type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.textPrimary)

                Text(status.type.description)
                    .font(.system(size: 10))
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            // Status badge
            statusBadge(for: status)
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(for status: LoopScriptLocator.ScriptStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.isInstalled ? Color.statusSuccess : Color.statusError)
                .frame(width: 6, height: 6)

            Text(status.source)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(status.isInstalled ? Color.statusSuccess : Color.statusError)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            (status.isInstalled ? Color.statusSuccess : Color.statusError)
                .opacity(0.15)
        )
        .cornerRadius(4)
    }

    // MARK: - Actions

    private func refreshStatuses() {
        scriptStatuses = LoopScriptLocator.getScriptStatuses()
    }

    private func runInstaller() {
        guard let installPath = LoopScriptLocator.findInstallScript() else {
            installOutput = "Error: install.sh not found"
            showInstallOutput = true
            return
        }

        isInstalling = true
        installOutput = ""

        Task {
            do {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [installPath]
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                await MainActor.run {
                    installOutput = output
                    showInstallOutput = true
                    isInstalling = false
                    refreshStatuses()
                }
            } catch {
                await MainActor.run {
                    installOutput = "Error: \(error.localizedDescription)"
                    showInstallOutput = true
                    isInstalling = false
                }
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        LoopConfigurationPanel()
    }
    .frame(width: 600, height: 400)
    .background(Color.bgApp)
}
