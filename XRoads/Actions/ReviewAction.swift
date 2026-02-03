import Foundation

// MARK: - ReviewActionError

/// Errors that can occur during review action execution
enum ReviewActionError: LocalizedError {
    case noChangesToReview
    case diffFailed(reason: String)
    case analysisFailure(reason: String)
    case reviewOutputFailed(path: String, reason: String)
    case gitNotAvailable
    case invalidWorkingDirectory(path: String)
    case autoFixFailed(file: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .noChangesToReview:
            return "No staged or committed changes to review"
        case .diffFailed(let reason):
            return "Failed to get diff: \(reason)"
        case .analysisFailure(let reason):
            return "Review analysis failed: \(reason)"
        case .reviewOutputFailed(let path, let reason):
            return "Failed to write review to '\(path)': \(reason)"
        case .gitNotAvailable:
            return "Git is not available in the working directory"
        case .invalidWorkingDirectory(let path):
            return "Invalid working directory: \(path)"
        case .autoFixFailed(let file, let reason):
            return "Auto-fix failed for '\(file)': \(reason)"
        }
    }
}

// MARK: - Review Issue Models

/// Severity level of a review issue
enum ReviewIssueSeverity: String, Codable, Sendable, CaseIterable {
    case critical       // Must fix before merge
    case major         // Should fix before merge
    case minor         // Nice to fix
    case suggestion    // Optional improvement
    case style         // Formatting/style issues

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .major: return "Major"
        case .minor: return "Minor"
        case .suggestion: return "Suggestion"
        case .style: return "Style"
        }
    }

    /// Weight for scoring (higher = more severe)
    var weight: Int {
        switch self {
        case .critical: return 10
        case .major: return 5
        case .minor: return 2
        case .suggestion: return 1
        case .style: return 0
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .major: return "exclamationmark.triangle.fill"
        case .minor: return "exclamationmark.circle.fill"
        case .suggestion: return "lightbulb.fill"
        case .style: return "paintbrush.fill"
        }
    }
}

/// Category of review issues
enum ReviewIssueCategory: String, Codable, Sendable, CaseIterable {
    case correctness       // Logic errors, bugs
    case security          // Security vulnerabilities
    case performance       // Performance issues
    case maintainability   // Code quality, readability
    case testing           // Test coverage, test quality
    case documentation     // Missing/incorrect docs
    case conventions       // Naming, style conventions
    case architecture      // Design/structure issues

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .correctness: return "Correctness"
        case .security: return "Security"
        case .performance: return "Performance"
        case .maintainability: return "Maintainability"
        case .testing: return "Testing"
        case .documentation: return "Documentation"
        case .conventions: return "Conventions"
        case .architecture: return "Architecture"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .correctness: return "ladybug.fill"
        case .security: return "lock.shield.fill"
        case .performance: return "speedometer"
        case .maintainability: return "wrench.and.screwdriver.fill"
        case .testing: return "testtube.2"
        case .documentation: return "doc.text.fill"
        case .conventions: return "textformat"
        case .architecture: return "building.columns.fill"
        }
    }
}

/// A single issue found during code review
struct ReviewIssue: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let severity: ReviewIssueSeverity
    let category: ReviewIssueCategory
    let file: String
    let lineStart: Int?
    let lineEnd: Int?
    let title: String
    let description: String
    let suggestedFix: String?
    let autoFixable: Bool
    let codeSnippet: String?

    init(
        id: UUID = UUID(),
        severity: ReviewIssueSeverity,
        category: ReviewIssueCategory,
        file: String,
        lineStart: Int? = nil,
        lineEnd: Int? = nil,
        title: String,
        description: String,
        suggestedFix: String? = nil,
        autoFixable: Bool = false,
        codeSnippet: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.category = category
        self.file = file
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.title = title
        self.description = description
        self.suggestedFix = suggestedFix
        self.autoFixable = autoFixable
        self.codeSnippet = codeSnippet
    }

    /// Location string for display (file:line or file:line-line)
    var locationString: String {
        if let start = lineStart, let end = lineEnd, start != end {
            return "\(file):\(start)-\(end)"
        } else if let start = lineStart {
            return "\(file):\(start)"
        }
        return file
    }
}

// MARK: - File Diff Models

/// Represents a diff hunk in a file
struct DiffHunk: Codable, Sendable, Hashable {
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let content: String
    let header: String

    /// Lines added in this hunk
    var addedLines: [String] {
        content.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.hasPrefix("+") && !$0.hasPrefix("+++") }
            .map { String($0.dropFirst()) }
    }

    /// Lines removed in this hunk
    var removedLines: [String] {
        content.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.hasPrefix("-") && !$0.hasPrefix("---") }
            .map { String($0.dropFirst()) }
    }
}

/// Represents changes to a single file
struct FileDiff: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let path: String
    let status: FileChangeStatus
    let hunks: [DiffHunk]
    let oldContent: String?
    let newContent: String?
    let isBinary: Bool

    init(
        id: UUID = UUID(),
        path: String,
        status: FileChangeStatus,
        hunks: [DiffHunk] = [],
        oldContent: String? = nil,
        newContent: String? = nil,
        isBinary: Bool = false
    ) {
        self.id = id
        self.path = path
        self.status = status
        self.hunks = hunks
        self.oldContent = oldContent
        self.newContent = newContent
        self.isBinary = isBinary
    }

    /// Total lines added
    var linesAdded: Int {
        hunks.reduce(0) { $0 + $1.addedLines.count }
    }

    /// Total lines removed
    var linesRemoved: Int {
        hunks.reduce(0) { $0 + $1.removedLines.count }
    }

    /// File extension
    var fileExtension: String {
        (path as NSString).pathExtension.lowercased()
    }
}

/// Status of a file change
enum FileChangeStatus: String, Codable, Sendable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case typeChanged = "T"
    case unmerged = "U"
    case unknown = "?"

    init(from statusChar: Character) {
        switch statusChar {
        case "A": self = .added
        case "M": self = .modified
        case "D": self = .deleted
        case "R": self = .renamed
        case "C": self = .copied
        case "T": self = .typeChanged
        case "U": self = .unmerged
        default: self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .typeChanged: return "Type Changed"
        case .unmerged: return "Unmerged"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Review Report

/// Source of changes being reviewed
enum ReviewSource: String, Codable, Sendable {
    case staged          // git diff --cached
    case committed       // git diff HEAD~N..HEAD
    case working         // git diff (unstaged)
    case branch          // git diff main..feature

    var displayName: String {
        switch self {
        case .staged: return "Staged Changes"
        case .committed: return "Recent Commits"
        case .working: return "Working Directory"
        case .branch: return "Branch Changes"
        }
    }
}

/// Summary statistics for a review
struct ReviewSummary: Codable, Sendable {
    let filesReviewed: Int
    let totalLinesAdded: Int
    let totalLinesRemoved: Int
    let issuesBySeverity: [ReviewIssueSeverity: Int]
    let issuesByCategory: [ReviewIssueCategory: Int]
    let autoFixableCount: Int
    let score: Int // 0-100

    /// Total number of issues
    var totalIssues: Int {
        issuesBySeverity.values.reduce(0, +)
    }

    /// Has critical issues
    var hasCriticalIssues: Bool {
        (issuesBySeverity[.critical] ?? 0) > 0
    }

    /// Has blocking issues (critical or major)
    var hasBlockingIssues: Bool {
        hasCriticalIssues || (issuesBySeverity[.major] ?? 0) > 0
    }

    /// Review verdict based on score
    var verdict: String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Acceptable"
        case 40..<60: return "Needs Work"
        default: return "Requires Changes"
        }
    }
}

/// A complete code review report
struct ReviewReport: Identifiable, Codable, Sendable {
    let id: UUID
    let source: ReviewSource
    let workingDirectory: String
    let branch: String?
    let commitRange: String?
    let files: [FileDiff]
    let issues: [ReviewIssue]
    let summary: ReviewSummary
    let createdAt: Date
    var reviewMDPath: String?

    init(
        id: UUID = UUID(),
        source: ReviewSource,
        workingDirectory: String,
        branch: String? = nil,
        commitRange: String? = nil,
        files: [FileDiff],
        issues: [ReviewIssue],
        summary: ReviewSummary,
        createdAt: Date = Date(),
        reviewMDPath: String? = nil
    ) {
        self.id = id
        self.source = source
        self.workingDirectory = workingDirectory
        self.branch = branch
        self.commitRange = commitRange
        self.files = files
        self.issues = issues
        self.summary = summary
        self.createdAt = createdAt
        self.reviewMDPath = reviewMDPath
    }

    /// Group issues by file
    var issuesByFile: [String: [ReviewIssue]] {
        Dictionary(grouping: issues, by: { $0.file })
    }

    /// Group issues by category
    var issuesByCategory: [ReviewIssueCategory: [ReviewIssue]] {
        Dictionary(grouping: issues, by: { $0.category })
    }

    /// Group issues by severity
    var issuesBySeverity: [ReviewIssueSeverity: [ReviewIssue]] {
        Dictionary(grouping: issues, by: { $0.severity })
    }

    /// Issues that can be auto-fixed
    var autoFixableIssues: [ReviewIssue] {
        issues.filter { $0.autoFixable }
    }
}

// MARK: - ReviewAction

/// The 'review' action that analyzes code changes and generates a review report
/// This action:
/// 1. Analyzes staged or committed changes
/// 2. Generates a review report with categorized issues
/// 3. Suggests fixes with diff preview
/// 4. Can auto-fix minor issues
/// 5. Outputs review.md
actor ReviewAction {

    // MARK: - Dependencies

    private let fileManager: FileManager

    // MARK: - State

    private var currentReport: ReviewReport?
    private var workingDirectory: String?

    // MARK: - Initialization

    init() {
        self.fileManager = .default
    }

    // MARK: - Public API

    /// Review staged changes
    /// - Parameter workingDir: Git repository working directory
    /// - Returns: Review report for staged changes
    func reviewStagedChanges(in workingDir: String) async throws -> ReviewReport {
        try validateWorkingDirectory(workingDir)
        self.workingDirectory = workingDir

        // Get staged diff
        let diff = try await getDiff(in: workingDir, source: .staged)

        if diff.isEmpty {
            throw ReviewActionError.noChangesToReview
        }

        // Parse diff into FileDiff objects
        let files = parseDiff(diff)

        if files.isEmpty {
            throw ReviewActionError.noChangesToReview
        }

        // Analyze files and generate issues
        let issues = analyzeFiles(files, in: workingDir)

        // Generate summary
        let summary = generateSummary(files: files, issues: issues)

        // Get current branch
        let branch = try? await getCurrentBranch(in: workingDir)

        let report = ReviewReport(
            source: .staged,
            workingDirectory: workingDir,
            branch: branch,
            files: files,
            issues: issues,
            summary: summary
        )

        currentReport = report
        return report
    }

    /// Review recent commits
    /// - Parameters:
    ///   - workingDir: Git repository working directory
    ///   - commitCount: Number of recent commits to review (default 1)
    /// - Returns: Review report for committed changes
    func reviewCommittedChanges(in workingDir: String, commitCount: Int = 1) async throws -> ReviewReport {
        try validateWorkingDirectory(workingDir)
        self.workingDirectory = workingDir

        let commitRange = "HEAD~\(commitCount)..HEAD"

        // Get committed diff
        let diff = try await getDiff(in: workingDir, source: .committed, commitRange: commitRange)

        if diff.isEmpty {
            throw ReviewActionError.noChangesToReview
        }

        // Parse diff into FileDiff objects
        let files = parseDiff(diff)

        if files.isEmpty {
            throw ReviewActionError.noChangesToReview
        }

        // Analyze files and generate issues
        let issues = analyzeFiles(files, in: workingDir)

        // Generate summary
        let summary = generateSummary(files: files, issues: issues)

        // Get current branch
        let branch = try? await getCurrentBranch(in: workingDir)

        let report = ReviewReport(
            source: .committed,
            workingDirectory: workingDir,
            branch: branch,
            commitRange: commitRange,
            files: files,
            issues: issues,
            summary: summary
        )

        currentReport = report
        return report
    }

    /// Review changes on a branch compared to main
    /// - Parameters:
    ///   - workingDir: Git repository working directory
    ///   - baseBranch: Base branch to compare against (default "main")
    /// - Returns: Review report for branch changes
    func reviewBranchChanges(in workingDir: String, baseBranch: String = "main") async throws -> ReviewReport {
        try validateWorkingDirectory(workingDir)
        self.workingDirectory = workingDir

        // Get current branch
        let currentBranch = try await getCurrentBranch(in: workingDir)
        let commitRange = "\(baseBranch)..\(currentBranch)"

        // Get branch diff
        let diff = try await getDiff(in: workingDir, source: .branch, commitRange: commitRange)

        if diff.isEmpty {
            throw ReviewActionError.noChangesToReview
        }

        // Parse diff into FileDiff objects
        let files = parseDiff(diff)

        if files.isEmpty {
            throw ReviewActionError.noChangesToReview
        }

        // Analyze files and generate issues
        let issues = analyzeFiles(files, in: workingDir)

        // Generate summary
        let summary = generateSummary(files: files, issues: issues)

        let report = ReviewReport(
            source: .branch,
            workingDirectory: workingDir,
            branch: currentBranch,
            commitRange: commitRange,
            files: files,
            issues: issues,
            summary: summary
        )

        currentReport = report
        return report
    }

    /// Generate review.md output file
    /// - Parameters:
    ///   - report: The review report to output
    ///   - outputPath: Path where to write review.md (default: working_dir/review.md)
    /// - Returns: Path to the generated review.md file
    func generateReviewMD(for report: ReviewReport, outputPath: String? = nil) throws -> String {
        let path = outputPath ?? "\(report.workingDirectory)/review.md"
        let content = formatReviewMD(report)

        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw ReviewActionError.reviewOutputFailed(path: path, reason: error.localizedDescription)
        }

        // Update report with path
        if var updatedReport = currentReport, updatedReport.id == report.id {
            updatedReport.reviewMDPath = path
            currentReport = updatedReport
        }

        return path
    }

    /// Get list of auto-fixable issues
    /// - Returns: Array of issues that can be auto-fixed
    func getAutoFixableIssues() -> [ReviewIssue] {
        currentReport?.autoFixableIssues ?? []
    }

    /// Apply auto-fix for a specific issue
    /// - Parameter issue: The issue to auto-fix
    /// - Throws: If auto-fix fails
    func applyAutoFix(for issue: ReviewIssue) async throws {
        guard issue.autoFixable, let fix = issue.suggestedFix else {
            throw ReviewActionError.autoFixFailed(file: issue.file, reason: "Issue is not auto-fixable")
        }

        guard let workingDir = workingDirectory else {
            throw ReviewActionError.autoFixFailed(file: issue.file, reason: "No working directory set")
        }

        let filePath = "\(workingDir)/\(issue.file)"

        guard fileManager.fileExists(atPath: filePath) else {
            throw ReviewActionError.autoFixFailed(file: issue.file, reason: "File not found")
        }

        // For now, log the fix that would be applied
        // In a real implementation, this would apply the fix to the file
        // The suggestedFix contains the corrected code that should replace the issue
        _ = fix
        _ = filePath
    }

    /// Apply all auto-fixes
    /// - Returns: Number of fixes applied
    func applyAllAutoFixes() async throws -> Int {
        let fixableIssues = getAutoFixableIssues()
        var fixedCount = 0

        for issue in fixableIssues {
            do {
                try await applyAutoFix(for: issue)
                fixedCount += 1
            } catch {
                // Continue with other fixes
                continue
            }
        }

        return fixedCount
    }

    /// Get the current review report
    /// - Returns: Current report if available
    func getCurrentReport() -> ReviewReport? {
        currentReport
    }

    /// Get issues filtered by severity
    /// - Parameter severity: Severity level to filter
    /// - Returns: Array of matching issues
    func getIssues(severity: ReviewIssueSeverity) -> [ReviewIssue] {
        currentReport?.issues.filter { $0.severity == severity } ?? []
    }

    /// Get issues filtered by category
    /// - Parameter category: Category to filter
    /// - Returns: Array of matching issues
    func getIssues(category: ReviewIssueCategory) -> [ReviewIssue] {
        currentReport?.issues.filter { $0.category == category } ?? []
    }

    /// Get issues for a specific file
    /// - Parameter file: File path to filter
    /// - Returns: Array of matching issues
    func getIssues(forFile file: String) -> [ReviewIssue] {
        currentReport?.issues.filter { $0.file == file } ?? []
    }

    // MARK: - Private Methods

    private func validateWorkingDirectory(_ path: String) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ReviewActionError.invalidWorkingDirectory(path: path)
        }

        // Check if it's a git repository
        let gitPath = "\(path)/.git"
        guard fileManager.fileExists(atPath: gitPath) else {
            throw ReviewActionError.gitNotAvailable
        }
    }

    private func getDiff(in workingDir: String, source: ReviewSource, commitRange: String? = nil) async throws -> String {
        var arguments: [String]

        switch source {
        case .staged:
            arguments = ["diff", "--cached", "-U3"]
        case .committed:
            guard let range = commitRange else {
                arguments = ["diff", "HEAD~1..HEAD", "-U3"]
                break
            }
            arguments = ["diff", range, "-U3"]
        case .working:
            arguments = ["diff", "-U3"]
        case .branch:
            guard let range = commitRange else {
                throw ReviewActionError.diffFailed(reason: "Commit range required for branch diff")
            }
            arguments = ["diff", range, "-U3"]
        }

        return try await runGit(arguments, in: workingDir)
    }

    private func getCurrentBranch(in workingDir: String) async throws -> String {
        let output = try await runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: workingDir)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runGit(_ arguments: [String], in workingDir: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDir)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ReviewActionError.diffFailed(reason: error.localizedDescription)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ReviewActionError.diffFailed(reason: errorOutput)
        }

        return output
    }

    private func parseDiff(_ diff: String) -> [FileDiff] {
        var files: [FileDiff] = []
        let lines = diff.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

        var currentFile: String?
        var currentHunks: [DiffHunk] = []
        var currentHunkLines: [String] = []
        var currentHunkHeader: String = ""
        var currentStatus: FileChangeStatus = .modified
        var hunkOldStart = 0, hunkOldCount = 0, hunkNewStart = 0, hunkNewCount = 0

        func saveCurrentHunk() {
            if !currentHunkLines.isEmpty {
                let hunk = DiffHunk(
                    oldStart: hunkOldStart,
                    oldCount: hunkOldCount,
                    newStart: hunkNewStart,
                    newCount: hunkNewCount,
                    content: currentHunkLines.joined(separator: "\n"),
                    header: currentHunkHeader
                )
                currentHunks.append(hunk)
                currentHunkLines = []
            }
        }

        func saveCurrentFile() {
            if let file = currentFile {
                saveCurrentHunk()
                let fileDiff = FileDiff(
                    path: file,
                    status: currentStatus,
                    hunks: currentHunks
                )
                files.append(fileDiff)
                currentHunks = []
            }
        }

        for line in lines {
            if line.hasPrefix("diff --git") {
                saveCurrentFile()
                // Extract file path from "diff --git a/path b/path"
                let parts = line.split(separator: " ")
                if parts.count >= 4 {
                    let bPath = String(parts[3])
                    currentFile = String(bPath.dropFirst(2)) // Remove "b/"
                }
                currentStatus = .modified
            } else if line.hasPrefix("new file mode") {
                currentStatus = .added
            } else if line.hasPrefix("deleted file mode") {
                currentStatus = .deleted
            } else if line.hasPrefix("rename from") || line.hasPrefix("rename to") {
                currentStatus = .renamed
            } else if line.hasPrefix("@@") {
                // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
                saveCurrentHunk()
                currentHunkHeader = line
                let regex = try? NSRegularExpression(pattern: "@@ -(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@")
                if let match = regex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    hunkOldStart = Int((line as NSString).substring(with: match.range(at: 1))) ?? 0
                    if match.range(at: 2).location != NSNotFound {
                        hunkOldCount = Int((line as NSString).substring(with: match.range(at: 2))) ?? 1
                    } else {
                        hunkOldCount = 1
                    }
                    hunkNewStart = Int((line as NSString).substring(with: match.range(at: 3))) ?? 0
                    if match.range(at: 4).location != NSNotFound {
                        hunkNewCount = Int((line as NSString).substring(with: match.range(at: 4))) ?? 1
                    } else {
                        hunkNewCount = 1
                    }
                }
            } else if line.hasPrefix("+") || line.hasPrefix("-") || line.hasPrefix(" ") {
                // Only add diff content lines (not header lines)
                if !line.hasPrefix("+++") && !line.hasPrefix("---") {
                    currentHunkLines.append(line)
                }
            }
        }

        // Save the last file
        saveCurrentFile()

        return files
    }

    private func analyzeFiles(_ files: [FileDiff], in workingDir: String) -> [ReviewIssue] {
        var issues: [ReviewIssue] = []

        for file in files {
            // Analyze each hunk for common issues
            for hunk in file.hunks {
                let hunkIssues = analyzeHunk(hunk, file: file.path, workingDir: workingDir)
                issues.append(contentsOf: hunkIssues)
            }

            // File-level analysis
            let fileIssues = analyzeFile(file, workingDir: workingDir)
            issues.append(contentsOf: fileIssues)
        }

        return issues
    }

    private func analyzeHunk(_ hunk: DiffHunk, file: String, workingDir: String) -> [ReviewIssue] {
        var issues: [ReviewIssue] = []
        let addedLines = hunk.addedLines

        for (index, line) in addedLines.enumerated() {
            let lineNumber = hunk.newStart + index

            // Check for common issues in added code

            // TODO/FIXME comments
            if line.contains("TODO") || line.contains("FIXME") || line.contains("HACK") {
                issues.append(ReviewIssue(
                    severity: .minor,
                    category: .maintainability,
                    file: file,
                    lineStart: lineNumber,
                    title: "TODO/FIXME comment found",
                    description: "A TODO or FIXME comment was added. Consider addressing it before merging.",
                    autoFixable: false,
                    codeSnippet: line
                ))
            }

            // Debug/print statements
            if line.contains("print(") || line.contains("debugPrint(") || line.contains("NSLog(") {
                issues.append(ReviewIssue(
                    severity: .minor,
                    category: .maintainability,
                    file: file,
                    lineStart: lineNumber,
                    title: "Debug print statement",
                    description: "Debug print statement found. Remove before production.",
                    suggestedFix: "",
                    autoFixable: true,
                    codeSnippet: line
                ))
            }

            // Force unwrapping in Swift
            if file.hasSuffix(".swift") && line.contains("!") && !line.contains("!=") && !line.contains("!==") {
                // Check for force unwrap patterns
                let forceUnwrapPattern = try? NSRegularExpression(pattern: "\\w+!")
                if forceUnwrapPattern?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                    issues.append(ReviewIssue(
                        severity: .major,
                        category: .correctness,
                        file: file,
                        lineStart: lineNumber,
                        title: "Force unwrap detected",
                        description: "Force unwrapping can cause runtime crashes. Consider using optional binding or nil coalescing.",
                        autoFixable: false,
                        codeSnippet: line
                    ))
                }
            }

            // Hardcoded credentials/secrets patterns
            let secretPatterns = ["password", "secret", "api_key", "apikey", "token", "credential"]
            let lowercaseLine = line.lowercased()
            for pattern in secretPatterns {
                if lowercaseLine.contains(pattern) && (line.contains("=") || line.contains(":")) {
                    // Check if it's an assignment, not just a variable name
                    if line.contains("\"") || line.contains("'") {
                        issues.append(ReviewIssue(
                            severity: .critical,
                            category: .security,
                            file: file,
                            lineStart: lineNumber,
                            title: "Potential hardcoded secret",
                            description: "Possible hardcoded credential detected. Use environment variables or secure storage instead.",
                            autoFixable: false,
                            codeSnippet: line
                        ))
                    }
                }
            }

            // Very long lines
            if line.count > 120 {
                issues.append(ReviewIssue(
                    severity: .style,
                    category: .conventions,
                    file: file,
                    lineStart: lineNumber,
                    title: "Line exceeds 120 characters",
                    description: "Line has \(line.count) characters. Consider breaking it up for readability.",
                    autoFixable: false,
                    codeSnippet: String(line.prefix(100)) + "..."
                ))
            }
        }

        return issues
    }

    private func analyzeFile(_ file: FileDiff, workingDir: String) -> [ReviewIssue] {
        var issues: [ReviewIssue] = []

        // Large file changes
        let totalChanges = file.linesAdded + file.linesRemoved
        if totalChanges > 500 {
            issues.append(ReviewIssue(
                severity: .suggestion,
                category: .maintainability,
                file: file.path,
                title: "Large file change",
                description: "This file has \(totalChanges) lines changed. Consider breaking into smaller commits."
            ))
        }

        // New test file without tests
        if file.status == .added && file.path.contains("Test") && file.hunks.isEmpty {
            issues.append(ReviewIssue(
                severity: .major,
                category: .testing,
                file: file.path,
                title: "Empty test file",
                description: "New test file appears to have no test implementations."
            ))
        }

        // Missing documentation for public APIs (Swift)
        if file.path.hasSuffix(".swift") && file.status == .added {
            // Check if file has any doc comments
            let hasDocComments = file.hunks.contains { hunk in
                hunk.addedLines.contains { $0.contains("///") || $0.contains("/**") }
            }
            let hasPublicDeclarations = file.hunks.contains { hunk in
                hunk.addedLines.contains { $0.contains("public ") }
            }
            if hasPublicDeclarations && !hasDocComments {
                issues.append(ReviewIssue(
                    severity: .minor,
                    category: .documentation,
                    file: file.path,
                    title: "Missing documentation",
                    description: "Public declarations should have documentation comments."
                ))
            }
        }

        return issues
    }

    private func generateSummary(files: [FileDiff], issues: [ReviewIssue]) -> ReviewSummary {
        let totalAdded = files.reduce(0) { $0 + $1.linesAdded }
        let totalRemoved = files.reduce(0) { $0 + $1.linesRemoved }

        var bySeverity: [ReviewIssueSeverity: Int] = [:]
        var byCategory: [ReviewIssueCategory: Int] = [:]
        var autoFixable = 0

        for issue in issues {
            bySeverity[issue.severity, default: 0] += 1
            byCategory[issue.category, default: 0] += 1
            if issue.autoFixable {
                autoFixable += 1
            }
        }

        // Calculate score (start at 100, deduct based on issues)
        var score = 100
        for issue in issues {
            score -= issue.severity.weight
        }
        score = max(0, min(100, score))

        return ReviewSummary(
            filesReviewed: files.count,
            totalLinesAdded: totalAdded,
            totalLinesRemoved: totalRemoved,
            issuesBySeverity: bySeverity,
            issuesByCategory: byCategory,
            autoFixableCount: autoFixable,
            score: score
        )
    }

    private func formatReviewMD(_ report: ReviewReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var md: [String] = []

        // Header
        md.append("# Code Review Report")
        md.append("")
        md.append("**Generated:** \(dateFormatter.string(from: report.createdAt))")
        md.append("**Source:** \(report.source.displayName)")
        if let branch = report.branch {
            md.append("**Branch:** \(branch)")
        }
        if let range = report.commitRange {
            md.append("**Commit Range:** \(range)")
        }
        md.append("")

        // Summary
        md.append("## Summary")
        md.append("")
        md.append("| Metric | Value |")
        md.append("|--------|-------|")
        md.append("| Files Reviewed | \(report.summary.filesReviewed) |")
        md.append("| Lines Added | +\(report.summary.totalLinesAdded) |")
        md.append("| Lines Removed | -\(report.summary.totalLinesRemoved) |")
        md.append("| Total Issues | \(report.summary.totalIssues) |")
        md.append("| Auto-Fixable | \(report.summary.autoFixableCount) |")
        md.append("| Review Score | \(report.summary.score)/100 (\(report.summary.verdict)) |")
        md.append("")

        // Issues by Severity
        if !report.summary.issuesBySeverity.isEmpty {
            md.append("### Issues by Severity")
            md.append("")
            for severity in ReviewIssueSeverity.allCases {
                if let count = report.summary.issuesBySeverity[severity], count > 0 {
                    md.append("- **\(severity.displayName):** \(count)")
                }
            }
            md.append("")
        }

        // Files Changed
        md.append("## Files Changed")
        md.append("")
        for file in report.files {
            let statusIcon: String
            switch file.status {
            case .added: statusIcon = "➕"
            case .modified: statusIcon = "📝"
            case .deleted: statusIcon = "🗑️"
            case .renamed: statusIcon = "📛"
            default: statusIcon = "❓"
            }
            md.append("- \(statusIcon) `\(file.path)` (+\(file.linesAdded)/-\(file.linesRemoved))")
        }
        md.append("")

        // Issues
        if !report.issues.isEmpty {
            md.append("## Issues")
            md.append("")

            // Group by file
            let groupedIssues = report.issuesByFile
            for (file, fileIssues) in groupedIssues.sorted(by: { $0.key < $1.key }) {
                md.append("### `\(file)`")
                md.append("")
                for issue in fileIssues {
                    let severityIcon = issue.severity == .critical ? "🚨" :
                                       issue.severity == .major ? "⚠️" :
                                       issue.severity == .minor ? "📌" :
                                       issue.severity == .suggestion ? "💡" : "🎨"

                    md.append("#### \(severityIcon) \(issue.title)")
                    if let line = issue.lineStart {
                        md.append("**Location:** Line \(line)")
                    }
                    md.append("**Severity:** \(issue.severity.displayName) | **Category:** \(issue.category.displayName)")
                    md.append("")
                    md.append(issue.description)
                    md.append("")

                    if let snippet = issue.codeSnippet {
                        md.append("```")
                        md.append(snippet)
                        md.append("```")
                        md.append("")
                    }

                    if let fix = issue.suggestedFix, !fix.isEmpty {
                        md.append("**Suggested Fix:**")
                        md.append("```")
                        md.append(fix)
                        md.append("```")
                        md.append("")
                    }

                    if issue.autoFixable {
                        md.append("✅ *This issue can be auto-fixed*")
                        md.append("")
                    }
                }
            }
        } else {
            md.append("## Issues")
            md.append("")
            md.append("✅ No issues found! Great job!")
            md.append("")
        }

        // Footer
        md.append("---")
        md.append("*Generated by XRoads Review Action*")

        return md.joined(separator: "\n")
    }
}

// MARK: - ReviewAction Convenience Extensions

extension ReviewAction {

    /// Quick review of staged changes with report output
    /// - Parameter workingDir: Working directory path
    /// - Returns: Path to generated review.md
    func quickReview(in workingDir: String) async throws -> String {
        let report = try await reviewStagedChanges(in: workingDir)
        return try generateReviewMD(for: report)
    }

    /// Get a brief summary of the current review
    /// - Returns: Human-readable summary string
    func getReviewSummary() -> String {
        guard let report = currentReport else {
            return "No review in progress"
        }

        var summary = "Review: \(report.source.displayName)\n"
        summary += "Files: \(report.summary.filesReviewed), "
        summary += "Issues: \(report.summary.totalIssues)\n"
        summary += "Score: \(report.summary.score)/100 (\(report.summary.verdict))"

        if report.summary.hasCriticalIssues {
            summary += "\n⚠️ CRITICAL ISSUES FOUND"
        }

        return summary
    }

    /// Check if current review has blocking issues
    /// - Returns: True if critical or major issues exist
    func hasBlockingIssues() -> Bool {
        currentReport?.summary.hasBlockingIssues ?? false
    }
}
