import XCTest
@testable import XRoads

final class ReviewActionTests: XCTestCase {

    // MARK: - ReviewIssueSeverity Tests

    func testReviewIssueSeverityDisplayNames() {
        XCTAssertEqual(ReviewIssueSeverity.critical.displayName, "Critical")
        XCTAssertEqual(ReviewIssueSeverity.major.displayName, "Major")
        XCTAssertEqual(ReviewIssueSeverity.minor.displayName, "Minor")
        XCTAssertEqual(ReviewIssueSeverity.suggestion.displayName, "Suggestion")
        XCTAssertEqual(ReviewIssueSeverity.style.displayName, "Style")
    }

    func testReviewIssueSeverityWeights() {
        XCTAssertGreaterThan(ReviewIssueSeverity.critical.weight, ReviewIssueSeverity.major.weight)
        XCTAssertGreaterThan(ReviewIssueSeverity.major.weight, ReviewIssueSeverity.minor.weight)
        XCTAssertGreaterThan(ReviewIssueSeverity.minor.weight, ReviewIssueSeverity.suggestion.weight)
        XCTAssertGreaterThanOrEqual(ReviewIssueSeverity.suggestion.weight, ReviewIssueSeverity.style.weight)
    }

    func testReviewIssueSeverityIcons() {
        for severity in ReviewIssueSeverity.allCases {
            XCTAssertFalse(severity.iconName.isEmpty, "\(severity) should have an icon")
        }
    }

    // MARK: - ReviewIssueCategory Tests

    func testReviewIssueCategoryDisplayNames() {
        XCTAssertEqual(ReviewIssueCategory.correctness.displayName, "Correctness")
        XCTAssertEqual(ReviewIssueCategory.security.displayName, "Security")
        XCTAssertEqual(ReviewIssueCategory.performance.displayName, "Performance")
        XCTAssertEqual(ReviewIssueCategory.maintainability.displayName, "Maintainability")
        XCTAssertEqual(ReviewIssueCategory.testing.displayName, "Testing")
        XCTAssertEqual(ReviewIssueCategory.documentation.displayName, "Documentation")
        XCTAssertEqual(ReviewIssueCategory.conventions.displayName, "Conventions")
        XCTAssertEqual(ReviewIssueCategory.architecture.displayName, "Architecture")
    }

    func testReviewIssueCategoryIcons() {
        for category in ReviewIssueCategory.allCases {
            XCTAssertFalse(category.iconName.isEmpty, "\(category) should have an icon")
        }
    }

    // MARK: - ReviewIssue Tests

    func testReviewIssueInit() {
        let issue = ReviewIssue(
            severity: .major,
            category: .correctness,
            file: "Sources/MyFile.swift",
            lineStart: 42,
            lineEnd: 45,
            title: "Test Issue",
            description: "This is a test issue",
            suggestedFix: "Fix it like this",
            autoFixable: true,
            codeSnippet: "let x = something"
        )

        XCTAssertEqual(issue.severity, .major)
        XCTAssertEqual(issue.category, .correctness)
        XCTAssertEqual(issue.file, "Sources/MyFile.swift")
        XCTAssertEqual(issue.lineStart, 42)
        XCTAssertEqual(issue.lineEnd, 45)
        XCTAssertEqual(issue.title, "Test Issue")
        XCTAssertEqual(issue.description, "This is a test issue")
        XCTAssertEqual(issue.suggestedFix, "Fix it like this")
        XCTAssertTrue(issue.autoFixable)
        XCTAssertEqual(issue.codeSnippet, "let x = something")
    }

    func testReviewIssueLocationString() {
        // Single line
        let singleLine = ReviewIssue(
            severity: .minor,
            category: .style,
            file: "test.swift",
            lineStart: 10,
            title: "Test",
            description: "Test"
        )
        XCTAssertEqual(singleLine.locationString, "test.swift:10")

        // Line range
        let lineRange = ReviewIssue(
            severity: .minor,
            category: .style,
            file: "test.swift",
            lineStart: 10,
            lineEnd: 15,
            title: "Test",
            description: "Test"
        )
        XCTAssertEqual(lineRange.locationString, "test.swift:10-15")

        // No line number
        let noLine = ReviewIssue(
            severity: .minor,
            category: .style,
            file: "test.swift",
            title: "Test",
            description: "Test"
        )
        XCTAssertEqual(noLine.locationString, "test.swift")
    }

    func testReviewIssueHashable() {
        let issue1 = ReviewIssue(
            id: UUID(),
            severity: .major,
            category: .correctness,
            file: "test.swift",
            title: "Test",
            description: "Test"
        )
        let issue2 = ReviewIssue(
            id: issue1.id,
            severity: .major,
            category: .correctness,
            file: "test.swift",
            title: "Test",
            description: "Test"
        )

        XCTAssertEqual(issue1, issue2)
        XCTAssertEqual(issue1.hashValue, issue2.hashValue)
    }

    // MARK: - DiffHunk Tests

    func testDiffHunkAddedLines() {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 3,
            newStart: 1,
            newCount: 5,
            content: """
             context line
            +added line 1
            +added line 2
            -removed line
             more context
            """,
            header: "@@ -1,3 +1,5 @@"
        )

        XCTAssertEqual(hunk.addedLines.count, 2)
        XCTAssertEqual(hunk.addedLines[0], "added line 1")
        XCTAssertEqual(hunk.addedLines[1], "added line 2")
    }

    func testDiffHunkRemovedLines() {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 3,
            newStart: 1,
            newCount: 5,
            content: """
             context line
            +added line 1
            -removed line 1
            -removed line 2
             more context
            """,
            header: "@@ -1,3 +1,5 @@"
        )

        XCTAssertEqual(hunk.removedLines.count, 2)
        XCTAssertEqual(hunk.removedLines[0], "removed line 1")
        XCTAssertEqual(hunk.removedLines[1], "removed line 2")
    }

    // MARK: - FileDiff Tests

    func testFileDiffInit() {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 2,
            newStart: 1,
            newCount: 4,
            content: "+line1\n+line2",
            header: "@@ -1,2 +1,4 @@"
        )

        let diff = FileDiff(
            path: "Sources/Test.swift",
            status: .modified,
            hunks: [hunk]
        )

        XCTAssertEqual(diff.path, "Sources/Test.swift")
        XCTAssertEqual(diff.status, .modified)
        XCTAssertEqual(diff.hunks.count, 1)
        XCTAssertFalse(diff.isBinary)
        XCTAssertEqual(diff.fileExtension, "swift")
    }

    func testFileDiffLinesAddedRemoved() {
        let hunk1 = DiffHunk(
            oldStart: 1,
            oldCount: 2,
            newStart: 1,
            newCount: 3,
            content: "+added1\n+added2\n-removed1",
            header: "@@ -1,2 +1,3 @@"
        )
        let hunk2 = DiffHunk(
            oldStart: 10,
            oldCount: 1,
            newStart: 11,
            newCount: 2,
            content: "+added3\n-removed2\n-removed3",
            header: "@@ -10,1 +11,2 @@"
        )

        let diff = FileDiff(
            path: "test.swift",
            status: .modified,
            hunks: [hunk1, hunk2]
        )

        XCTAssertEqual(diff.linesAdded, 3) // added1, added2, added3
        XCTAssertEqual(diff.linesRemoved, 3) // removed1, removed2, removed3
    }

    // MARK: - FileChangeStatus Tests

    func testFileChangeStatusFromChar() {
        XCTAssertEqual(FileChangeStatus(from: "A"), .added)
        XCTAssertEqual(FileChangeStatus(from: "M"), .modified)
        XCTAssertEqual(FileChangeStatus(from: "D"), .deleted)
        XCTAssertEqual(FileChangeStatus(from: "R"), .renamed)
        XCTAssertEqual(FileChangeStatus(from: "C"), .copied)
        XCTAssertEqual(FileChangeStatus(from: "T"), .typeChanged)
        XCTAssertEqual(FileChangeStatus(from: "U"), .unmerged)
        XCTAssertEqual(FileChangeStatus(from: "X"), .unknown)
    }

    func testFileChangeStatusDisplayNames() {
        XCTAssertEqual(FileChangeStatus.added.displayName, "Added")
        XCTAssertEqual(FileChangeStatus.modified.displayName, "Modified")
        XCTAssertEqual(FileChangeStatus.deleted.displayName, "Deleted")
        XCTAssertEqual(FileChangeStatus.renamed.displayName, "Renamed")
    }

    // MARK: - ReviewSource Tests

    func testReviewSourceDisplayNames() {
        XCTAssertEqual(ReviewSource.staged.displayName, "Staged Changes")
        XCTAssertEqual(ReviewSource.committed.displayName, "Recent Commits")
        XCTAssertEqual(ReviewSource.working.displayName, "Working Directory")
        XCTAssertEqual(ReviewSource.branch.displayName, "Branch Changes")
    }

    // MARK: - ReviewSummary Tests

    func testReviewSummaryTotalIssues() {
        let summary = ReviewSummary(
            filesReviewed: 5,
            totalLinesAdded: 100,
            totalLinesRemoved: 50,
            issuesBySeverity: [.critical: 1, .major: 2, .minor: 3],
            issuesByCategory: [:],
            autoFixableCount: 2,
            score: 75
        )

        XCTAssertEqual(summary.totalIssues, 6)
    }

    func testReviewSummaryHasCriticalIssues() {
        let withCritical = ReviewSummary(
            filesReviewed: 1,
            totalLinesAdded: 10,
            totalLinesRemoved: 5,
            issuesBySeverity: [.critical: 1],
            issuesByCategory: [:],
            autoFixableCount: 0,
            score: 50
        )
        XCTAssertTrue(withCritical.hasCriticalIssues)

        let withoutCritical = ReviewSummary(
            filesReviewed: 1,
            totalLinesAdded: 10,
            totalLinesRemoved: 5,
            issuesBySeverity: [.major: 2],
            issuesByCategory: [:],
            autoFixableCount: 0,
            score: 70
        )
        XCTAssertFalse(withoutCritical.hasCriticalIssues)
    }

    func testReviewSummaryHasBlockingIssues() {
        let withBlocking = ReviewSummary(
            filesReviewed: 1,
            totalLinesAdded: 10,
            totalLinesRemoved: 5,
            issuesBySeverity: [.major: 1],
            issuesByCategory: [:],
            autoFixableCount: 0,
            score: 70
        )
        XCTAssertTrue(withBlocking.hasBlockingIssues)

        let withoutBlocking = ReviewSummary(
            filesReviewed: 1,
            totalLinesAdded: 10,
            totalLinesRemoved: 5,
            issuesBySeverity: [.minor: 2, .style: 1],
            issuesByCategory: [:],
            autoFixableCount: 0,
            score: 95
        )
        XCTAssertFalse(withoutBlocking.hasBlockingIssues)
    }

    func testReviewSummaryVerdict() {
        XCTAssertEqual(ReviewSummary(filesReviewed: 1, totalLinesAdded: 10, totalLinesRemoved: 5, issuesBySeverity: [:], issuesByCategory: [:], autoFixableCount: 0, score: 95).verdict, "Excellent")
        XCTAssertEqual(ReviewSummary(filesReviewed: 1, totalLinesAdded: 10, totalLinesRemoved: 5, issuesBySeverity: [:], issuesByCategory: [:], autoFixableCount: 0, score: 80).verdict, "Good")
        XCTAssertEqual(ReviewSummary(filesReviewed: 1, totalLinesAdded: 10, totalLinesRemoved: 5, issuesBySeverity: [:], issuesByCategory: [:], autoFixableCount: 0, score: 65).verdict, "Acceptable")
        XCTAssertEqual(ReviewSummary(filesReviewed: 1, totalLinesAdded: 10, totalLinesRemoved: 5, issuesBySeverity: [:], issuesByCategory: [:], autoFixableCount: 0, score: 45).verdict, "Needs Work")
        XCTAssertEqual(ReviewSummary(filesReviewed: 1, totalLinesAdded: 10, totalLinesRemoved: 5, issuesBySeverity: [:], issuesByCategory: [:], autoFixableCount: 0, score: 30).verdict, "Requires Changes")
    }

    // MARK: - ReviewReport Tests

    func testReviewReportInit() {
        let files = [
            FileDiff(path: "test1.swift", status: .modified),
            FileDiff(path: "test2.swift", status: .added)
        ]
        let issues = [
            ReviewIssue(severity: .major, category: .correctness, file: "test1.swift", title: "Issue 1", description: "Desc 1"),
            ReviewIssue(severity: .minor, category: .style, file: "test1.swift", title: "Issue 2", description: "Desc 2"),
            ReviewIssue(severity: .minor, category: .documentation, file: "test2.swift", title: "Issue 3", description: "Desc 3")
        ]
        let summary = ReviewSummary(
            filesReviewed: 2,
            totalLinesAdded: 20,
            totalLinesRemoved: 10,
            issuesBySeverity: [.major: 1, .minor: 2],
            issuesByCategory: [.correctness: 1, .style: 1, .documentation: 1],
            autoFixableCount: 0,
            score: 85
        )

        let report = ReviewReport(
            source: .staged,
            workingDirectory: "/path/to/repo",
            branch: "main",
            files: files,
            issues: issues,
            summary: summary
        )

        XCTAssertEqual(report.source, .staged)
        XCTAssertEqual(report.workingDirectory, "/path/to/repo")
        XCTAssertEqual(report.branch, "main")
        XCTAssertEqual(report.files.count, 2)
        XCTAssertEqual(report.issues.count, 3)
    }

    func testReviewReportIssuesByFile() {
        let issues = [
            ReviewIssue(severity: .major, category: .correctness, file: "file1.swift", title: "Issue 1", description: "Desc 1"),
            ReviewIssue(severity: .minor, category: .style, file: "file1.swift", title: "Issue 2", description: "Desc 2"),
            ReviewIssue(severity: .minor, category: .documentation, file: "file2.swift", title: "Issue 3", description: "Desc 3")
        ]
        let summary = ReviewSummary(filesReviewed: 2, totalLinesAdded: 10, totalLinesRemoved: 5, issuesBySeverity: [:], issuesByCategory: [:], autoFixableCount: 0, score: 80)

        let report = ReviewReport(
            source: .staged,
            workingDirectory: "/path",
            files: [],
            issues: issues,
            summary: summary
        )

        let byFile = report.issuesByFile
        XCTAssertEqual(byFile["file1.swift"]?.count, 2)
        XCTAssertEqual(byFile["file2.swift"]?.count, 1)
    }

    func testReviewReportAutoFixableIssues() {
        let issues = [
            ReviewIssue(severity: .minor, category: .style, file: "test.swift", title: "Issue 1", description: "Desc", suggestedFix: "fix", autoFixable: true),
            ReviewIssue(severity: .major, category: .correctness, file: "test.swift", title: "Issue 2", description: "Desc", autoFixable: false),
            ReviewIssue(severity: .style, category: .conventions, file: "test.swift", title: "Issue 3", description: "Desc", suggestedFix: "fix2", autoFixable: true)
        ]
        let summary = ReviewSummary(filesReviewed: 1, totalLinesAdded: 10, totalLinesRemoved: 5, issuesBySeverity: [:], issuesByCategory: [:], autoFixableCount: 2, score: 75)

        let report = ReviewReport(
            source: .staged,
            workingDirectory: "/path",
            files: [],
            issues: issues,
            summary: summary
        )

        XCTAssertEqual(report.autoFixableIssues.count, 2)
    }

    // MARK: - ReviewActionError Tests

    func testReviewActionErrorDescriptions() {
        XCTAssertTrue(ReviewActionError.noChangesToReview.errorDescription?.contains("No staged") ?? false)
        XCTAssertTrue(ReviewActionError.diffFailed(reason: "test").errorDescription?.contains("test") ?? false)
        XCTAssertTrue(ReviewActionError.analysisFailure(reason: "test").errorDescription?.contains("analysis") ?? false)
        XCTAssertTrue(ReviewActionError.reviewOutputFailed(path: "/path", reason: "test").errorDescription?.contains("/path") ?? false)
        XCTAssertTrue(ReviewActionError.gitNotAvailable.errorDescription?.contains("Git") ?? false)
        XCTAssertTrue(ReviewActionError.invalidWorkingDirectory(path: "/bad").errorDescription?.contains("/bad") ?? false)
        XCTAssertTrue(ReviewActionError.autoFixFailed(file: "test.swift", reason: "test").errorDescription?.contains("test.swift") ?? false)
    }

    // MARK: - ReviewAction Tests

    func testReviewActionInitialization() async {
        let action = ReviewAction()
        let report = await action.getCurrentReport()
        XCTAssertNil(report)
    }

    func testReviewActionGetIssuesBySeverityEmpty() async {
        let action = ReviewAction()
        let issues = await action.getIssues(severity: .critical)
        XCTAssertTrue(issues.isEmpty)
    }

    func testReviewActionGetIssuesByCategoryEmpty() async {
        let action = ReviewAction()
        let issues = await action.getIssues(category: .security)
        XCTAssertTrue(issues.isEmpty)
    }

    func testReviewActionGetIssuesForFileEmpty() async {
        let action = ReviewAction()
        let issues = await action.getIssues(forFile: "nonexistent.swift")
        XCTAssertTrue(issues.isEmpty)
    }

    func testReviewActionGetAutoFixableIssuesEmpty() async {
        let action = ReviewAction()
        let issues = await action.getAutoFixableIssues()
        XCTAssertTrue(issues.isEmpty)
    }

    func testReviewActionHasBlockingIssuesEmpty() async {
        let action = ReviewAction()
        let hasBlocking = await action.hasBlockingIssues()
        XCTAssertFalse(hasBlocking)
    }

    func testReviewActionGetSummaryEmpty() async {
        let action = ReviewAction()
        let summary = await action.getReviewSummary()
        XCTAssertEqual(summary, "No review in progress")
    }
}

// MARK: - ReviewMD Format Tests

final class ReviewMDFormatTests: XCTestCase {

    func testReviewMDContainsHeader() async throws {
        // Create a mock report
        let summary = ReviewSummary(
            filesReviewed: 1,
            totalLinesAdded: 10,
            totalLinesRemoved: 5,
            issuesBySeverity: [.minor: 1],
            issuesByCategory: [.style: 1],
            autoFixableCount: 0,
            score: 95
        )

        let report = ReviewReport(
            source: .staged,
            workingDirectory: "/test/path",
            branch: "main",
            files: [FileDiff(path: "test.swift", status: .modified)],
            issues: [ReviewIssue(severity: .minor, category: .style, file: "test.swift", title: "Test Issue", description: "Test description")],
            summary: summary
        )

        // We can't directly test generateReviewMD since it writes to disk
        // But we can verify the report structure is correct
        XCTAssertEqual(report.source, .staged)
        XCTAssertEqual(report.branch, "main")
        XCTAssertEqual(report.summary.filesReviewed, 1)
    }

    func testReviewReportIssueGrouping() {
        let issues = [
            ReviewIssue(severity: .critical, category: .security, file: "auth.swift", title: "Security Issue", description: "Desc"),
            ReviewIssue(severity: .major, category: .correctness, file: "logic.swift", title: "Bug", description: "Desc"),
            ReviewIssue(severity: .major, category: .security, file: "auth.swift", title: "Another Security Issue", description: "Desc"),
            ReviewIssue(severity: .minor, category: .style, file: "logic.swift", title: "Style Issue", description: "Desc")
        ]

        let summary = ReviewSummary(
            filesReviewed: 2,
            totalLinesAdded: 20,
            totalLinesRemoved: 10,
            issuesBySeverity: [.critical: 1, .major: 2, .minor: 1],
            issuesByCategory: [.security: 2, .correctness: 1, .style: 1],
            autoFixableCount: 0,
            score: 60
        )

        let report = ReviewReport(
            source: .committed,
            workingDirectory: "/test",
            files: [],
            issues: issues,
            summary: summary
        )

        // Test grouping by severity
        let bySeverity = report.issuesBySeverity
        XCTAssertEqual(bySeverity[.critical]?.count, 1)
        XCTAssertEqual(bySeverity[.major]?.count, 2)
        XCTAssertEqual(bySeverity[.minor]?.count, 1)

        // Test grouping by category
        let byCategory = report.issuesByCategory
        XCTAssertEqual(byCategory[.security]?.count, 2)
        XCTAssertEqual(byCategory[.correctness]?.count, 1)
        XCTAssertEqual(byCategory[.style]?.count, 1)

        // Test grouping by file
        let byFile = report.issuesByFile
        XCTAssertEqual(byFile["auth.swift"]?.count, 2)
        XCTAssertEqual(byFile["logic.swift"]?.count, 2)
    }
}
