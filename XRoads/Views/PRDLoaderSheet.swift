import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct PRDLoaderSheet: View {
    private let initialURL: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @StateObject private var viewModel = PRDLoaderViewModel()

    init(initialURL: URL? = nil) {
        self.initialURL = initialURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header
            content
            actions
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 640, height: 480)
        .background(Color.bgApp)
        .onAppear {
            loadInitialPRDIfNeeded()
        }
        .onDisappear {
            appState.setActivePRD(url: nil, name: nil)
        }
        .onChange(of: viewModel.document?.featureName ?? "") { _, _ in
            appState.setActivePRD(url: viewModel.selectedURL, name: viewModel.document?.featureName)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Load PRD")
                .font(.largeTitle)
                .foregroundStyle(Color.textPrimary)
            Text("Select a prd.json file to review the plan before starting orchestration.")
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var content: some View {
        Group {
            if let doc = viewModel.document {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text(doc.featureName)
                            .font(.title2)
                            .foregroundStyle(Color.textPrimary)
                        Text(doc.description)
                            .foregroundStyle(Color.textSecondary)
                        Divider()
                        ForEach(doc.userStories) { story in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("\(story.id) – \(story.title)")
                                    .font(.headline)
                                    .foregroundStyle(Color.textPrimary)
                                Text(story.description)
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                HStack {
                                    Label(story.priority.rawValue.capitalized, systemImage: "exclamationmark.circle")
                                    if !story.dependsOn.isEmpty {
                                        Label("Depends on: \(story.dependsOn.joined(separator: ", "))", systemImage: "link")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.textSecondary)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                    }
                }
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(Color.statusError)
            } else {
                Text("Select a prd.json file to preview stories.")
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private var actions: some View {
        HStack {
            Button("Browse…") {
                browseForPRD()
            }
            .buttonStyle(.borderedProminent)

            if viewModel.document != nil {
                Button("Reset") {
                    viewModel.reset()
                    appState.setActivePRD(url: nil, name: nil)
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Start Orchestration") {
                // Future: trigger orchestrator once integrated
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.document == nil)
        }
    }

    private func browseForPRD() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.json]
        } else {
            panel.allowedFileTypes = ["json"]
        }
        panel.message = "Select prd.json"
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.load(url: url)
            }
        }
#endif
    }

    private func loadInitialPRDIfNeeded() {
        guard let url = initialURL,
              viewModel.document == nil else { return }
        Task {
            await viewModel.load(url: url)
        }
    }
}
