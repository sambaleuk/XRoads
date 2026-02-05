import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct PRDLoaderSheet: View {
    private let initialURL: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @StateObject private var viewModel = PRDLoaderViewModel()
    @State private var repoPath: String = ""
    @State private var isStarting: Bool = false
    @State private var showSlotAssignment: Bool = false

    init(initialURL: URL? = nil) {
        self.initialURL = initialURL
    }

    private var repoURL: URL? {
        guard !repoPath.isEmpty else { return nil }
        return URL(fileURLWithPath: repoPath)
    }

    private var canStart: Bool {
        viewModel.document != nil && repoURL != nil && !isStarting
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
        .sheet(isPresented: $showSlotAssignment) {
            if let doc = viewModel.document, let url = repoURL {
                SlotAssignmentSheet(prd: doc, repoPath: url) {
                    // Close this sheet when SlotAssignmentSheet completes
                    dismiss()
                }
            }
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
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Repository Path Selector
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Repository Path")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                HStack {
                    TextField("Select repository...", text: $repoPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse") {
                        browseForRepo()
                    }
                    .buttonStyle(.bordered)
                }

                if !repoPath.isEmpty {
                    let exists = FileManager.default.fileExists(atPath: repoPath)
                    HStack(spacing: 4) {
                        Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(exists ? Color.statusSuccess : Color.statusError)
                        Text(exists ? "Valid path" : "Path does not exist")
                            .font(.caption)
                            .foregroundStyle(exists ? Color.textSecondary : Color.statusError)
                    }
                }
            }

            Divider()

            // PRD Preview
            Group {
                if let doc = viewModel.document {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text(doc.featureName)
                                .font(.title2)
                                .foregroundStyle(Color.textPrimary)
                            Text(doc.description)
                                .foregroundStyle(Color.textSecondary)

                            HStack {
                                Label("\(doc.userStories.count) stories", systemImage: "list.bullet")
                                Spacer()
                                let criticalCount = doc.userStories.filter { $0.priority == .critical }.count
                                if criticalCount > 0 {
                                    Label("\(criticalCount) critical", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.statusWarning)
                                }
                            }
                            .font(.caption)
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
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private var actions: some View {
        HStack {
            Button("Load PRD…") {
                browseForPRD()
            }
            .buttonStyle(.borderedProminent)

            if viewModel.document != nil {
                Button("Reset") {
                    viewModel.reset()
                    repoPath = ""
                    appState.setActivePRD(url: nil, name: nil)
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button {
                startOrchestration()
            } label: {
                if isStarting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 100)
                } else {
                    Text("Start Orchestration")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.statusSuccess)
            .disabled(!canStart)
        }
    }

    private func startOrchestration() {
        guard viewModel.document != nil, repoURL != nil else { return }
        showSlotAssignment = true
    }

    private func browseForRepo() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "Select git repository"
        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
        }
#endif
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
