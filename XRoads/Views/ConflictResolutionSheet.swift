import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ConflictResolutionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Resolve Conflicts")
                    .font(.title2.bold())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button("Close") {
                    appState.dismissConflictSheet()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(Theme.Spacing.md)

            Divider()

            // Content
            HStack(spacing: Theme.Spacing.lg) {
                conflictList
                    .frame(width: 220)
                conflictDetail
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(width: 800, height: 520)
        .background(Color.bgApp)
    }

    private var conflictList: some View {
        List(selection: selectedFileBinding) {
            if appState.conflictFiles.isEmpty {
                Text("No conflicts")
            } else {
                ForEach(appState.conflictFiles, id: \.self) { file in
                    Label(file, systemImage: "doc.richtext")
                        .font(.caption)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .listStyle(.inset)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private var conflictDetail: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(selectedFileBinding.wrappedValue ?? "Select a file")
                .font(.title3)
                .foregroundStyle(Color.textPrimary)

            Text("Choose how to resolve this conflict. You can pick the orchestrator's version (ours), the agent's version (theirs), or open the file in your editor for manual edits.")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)

            HStack {
                Button("Keep Ours") {
                    resolveCurrent(keepOurs: true)
                }
                .buttonStyle(.borderedProminent)

                Button("Keep Theirs") {
                    resolveCurrent(keepOurs: false)
                }
                .buttonStyle(.bordered)

                Button("Mark as Resolved") {
                    markCurrentResolved()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    openInEditor()
                } label: {
                    Label("Open in Editor", systemImage: "arrow.up.forward.app")
                }
            }

            Spacer()

            Button(role: .destructive) {
                Task {
                    await appState.abortMerge()
                }
            } label: {
                Label("Abort Merge", systemImage: "xmark.octagon")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selectedFileBinding: Binding<String?> {
        Binding(
            get: {
                appState.selectedConflictFile ?? appState.conflictFiles.first
            },
            set: { newValue in
                appState.selectedConflictFile = newValue
            }
        )
    }

    private func resolveCurrent(keepOurs: Bool) {
        guard let file = selectedFileBinding.wrappedValue else { return }
        Task {
            if keepOurs {
                await appState.keepOurs(for: file)
            } else {
                await appState.keepTheirs(for: file)
            }
        }
    }

    private func markCurrentResolved() {
        guard let file = selectedFileBinding.wrappedValue else { return }
        Task {
            await appState.markResolved(file: file)
        }
    }

    private func openInEditor() {
#if os(macOS)
        guard let repo = appState.orchestrationRepoPath,
              let file = selectedFileBinding.wrappedValue else { return }
        let url = repo.appendingPathComponent(file)
        NSWorkspace.shared.open(url)
#endif
    }
}
