import Foundation

// MARK: - IntegrationTestActionError

/// Errors that can occur during integration test action execution
enum IntegrationTestActionError: LocalizedError {
    case noIntegrationPointsFound
    case analysisFailure(reason: String)
    case testGenerationFailed(reason: String)
    case outputFailed(path: String, reason: String)
    case invalidWorkingDirectory(path: String)
    case gitNotAvailable
    case noTestableFlowsFound
    case configurationError(reason: String)

    var errorDescription: String? {
        switch self {
        case .noIntegrationPointsFound:
            return "No integration points found in the codebase"
        case .analysisFailure(let reason):
            return "Integration analysis failed: \(reason)"
        case .testGenerationFailed(let reason):
            return "Test generation failed: \(reason)"
        case .outputFailed(let path, let reason):
            return "Failed to write test output to '\(path)': \(reason)"
        case .invalidWorkingDirectory(let path):
            return "Invalid working directory: \(path)"
        case .gitNotAvailable:
            return "Git is not available in the working directory"
        case .noTestableFlowsFound:
            return "No testable user flows found"
        case .configurationError(let reason):
            return "Configuration error: \(reason)"
        }
    }
}

// MARK: - Integration Test Models

/// Type of integration point detected
enum IntegrationPointType: String, Codable, Sendable, CaseIterable {
    case serviceToService       // Service actor calling another service
    case serviceToExternal      // Service calling external API/system
    case viewModelToService     // ViewModel depending on service
    case processExecution       // Process spawning (CLI, subprocess)
    case fileSystem             // File system operations
    case network                // Network calls
    case database               // Database operations
    case mcp                    // MCP protocol communication

    var displayName: String {
        switch self {
        case .serviceToService: return "Service-to-Service"
        case .serviceToExternal: return "External Integration"
        case .viewModelToService: return "ViewModel-Service"
        case .processExecution: return "Process Execution"
        case .fileSystem: return "File System"
        case .network: return "Network"
        case .database: return "Database"
        case .mcp: return "MCP Protocol"
        }
    }

    var iconName: String {
        switch self {
        case .serviceToService: return "arrow.left.arrow.right"
        case .serviceToExternal: return "cloud.fill"
        case .viewModelToService: return "rectangle.connected.to.line.below"
        case .processExecution: return "terminal.fill"
        case .fileSystem: return "folder.fill"
        case .network: return "network"
        case .database: return "cylinder.fill"
        case .mcp: return "antenna.radiowaves.left.and.right"
        }
    }

    /// Test priority for this type (higher = more important)
    var testPriority: Int {
        switch self {
        case .serviceToExternal, .network: return 10
        case .mcp, .processExecution: return 9
        case .serviceToService: return 8
        case .database: return 7
        case .viewModelToService: return 6
        case .fileSystem: return 5
        }
    }
}

/// An integration point detected in the codebase
struct IntegrationPoint: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let type: IntegrationPointType
    let sourceFile: String
    let sourceName: String        // Class/actor/struct name
    let targetName: String        // What it integrates with
    let lineNumber: Int?
    let description: String
    let complexity: IntegrationComplexity
    let suggestedTestApproach: String

    init(
        id: UUID = UUID(),
        type: IntegrationPointType,
        sourceFile: String,
        sourceName: String,
        targetName: String,
        lineNumber: Int? = nil,
        description: String,
        complexity: IntegrationComplexity = .medium,
        suggestedTestApproach: String
    ) {
        self.id = id
        self.type = type
        self.sourceFile = sourceFile
        self.sourceName = sourceName
        self.targetName = targetName
        self.lineNumber = lineNumber
        self.description = description
        self.complexity = complexity
        self.suggestedTestApproach = suggestedTestApproach
    }

    /// Location string for display
    var locationString: String {
        if let line = lineNumber {
            return "\(sourceFile):\(line)"
        }
        return sourceFile
    }
}

/// Complexity level of an integration point
enum IntegrationComplexity: String, Codable, Sendable {
    case low        // Simple mock/stub
    case medium     // Requires setup/teardown
    case high       // Needs external resources or complex setup
    case critical   // Mission-critical path, needs thorough testing

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var weight: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - E2E Flow Models

/// A testable end-to-end user flow
struct E2EFlow: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let steps: [E2EStep]
    let entryPoint: String       // File/view where flow starts
    let criticalPath: Bool       // Is this a critical user journey?
    let estimatedDuration: String // e.g., "< 1s", "1-5s", "> 5s"

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        steps: [E2EStep],
        entryPoint: String,
        criticalPath: Bool = false,
        estimatedDuration: String = "< 1s"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.entryPoint = entryPoint
        self.criticalPath = criticalPath
        self.estimatedDuration = estimatedDuration
    }

    /// Total number of steps
    var stepCount: Int { steps.count }
}

/// A step in an E2E flow
struct E2EStep: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let order: Int
    let action: String           // What the user/system does
    let expectedResult: String   // What should happen
    let component: String        // View/Service involved
    let assertions: [String]     // What to verify

    init(
        id: UUID = UUID(),
        order: Int,
        action: String,
        expectedResult: String,
        component: String,
        assertions: [String] = []
    ) {
        self.id = id
        self.order = order
        self.action = action
        self.expectedResult = expectedResult
        self.component = component
        self.assertions = assertions
    }
}

// MARK: - Performance Test Models

/// A performance test scenario
struct PerformanceTestScenario: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let targetComponent: String
    let operation: String
    let expectedLatency: String   // e.g., "< 100ms"
    let loadProfile: LoadProfile
    let metrics: [PerformanceMetric]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        targetComponent: String,
        operation: String,
        expectedLatency: String,
        loadProfile: LoadProfile = .single,
        metrics: [PerformanceMetric] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.targetComponent = targetComponent
        self.operation = operation
        self.expectedLatency = expectedLatency
        self.loadProfile = loadProfile
        self.metrics = metrics
    }
}

/// Load profile for performance testing
enum LoadProfile: String, Codable, Sendable {
    case single     // Single operation
    case burst      // Burst of concurrent operations
    case sustained  // Sustained load over time
    case stress     // Maximum load testing

    var displayName: String {
        switch self {
        case .single: return "Single Operation"
        case .burst: return "Burst Load"
        case .sustained: return "Sustained Load"
        case .stress: return "Stress Test"
        }
    }
}

/// Performance metric to track
enum PerformanceMetric: String, Codable, Sendable {
    case latency
    case throughput
    case memoryUsage
    case cpuUsage
    case errorRate

    var displayName: String {
        switch self {
        case .latency: return "Latency"
        case .throughput: return "Throughput"
        case .memoryUsage: return "Memory Usage"
        case .cpuUsage: return "CPU Usage"
        case .errorRate: return "Error Rate"
        }
    }
}

// MARK: - Test Plan Models

/// An integration test plan
struct IntegrationTestPlan: Identifiable, Codable, Sendable {
    let id: UUID
    let workingDirectory: String
    let createdAt: Date
    var integrationPoints: [IntegrationPoint]
    var e2eFlows: [E2EFlow]
    var performanceScenarios: [PerformanceTestScenario]
    var suggestedTestFiles: [SuggestedTestFile]

    init(
        id: UUID = UUID(),
        workingDirectory: String,
        createdAt: Date = Date(),
        integrationPoints: [IntegrationPoint] = [],
        e2eFlows: [E2EFlow] = [],
        performanceScenarios: [PerformanceTestScenario] = [],
        suggestedTestFiles: [SuggestedTestFile] = []
    ) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.createdAt = createdAt
        self.integrationPoints = integrationPoints
        self.e2eFlows = e2eFlows
        self.performanceScenarios = performanceScenarios
        self.suggestedTestFiles = suggestedTestFiles
    }

    /// Total test count across all categories
    var totalTestCount: Int {
        integrationPoints.count + e2eFlows.count + performanceScenarios.count
    }

    /// Has any testable content
    var hasContent: Bool {
        !integrationPoints.isEmpty || !e2eFlows.isEmpty || !performanceScenarios.isEmpty
    }
}

/// A suggested test file to create
struct SuggestedTestFile: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let path: String
    let testType: TestFileType
    let targetComponents: [String]
    let suggestedTestCases: [String]

    init(
        id: UUID = UUID(),
        path: String,
        testType: TestFileType,
        targetComponents: [String],
        suggestedTestCases: [String]
    ) {
        self.id = id
        self.path = path
        self.testType = testType
        self.targetComponents = targetComponents
        self.suggestedTestCases = suggestedTestCases
    }
}

/// Type of test file
enum TestFileType: String, Codable, Sendable {
    case integration
    case e2e
    case performance

    var displayName: String {
        switch self {
        case .integration: return "Integration Tests"
        case .e2e: return "End-to-End Tests"
        case .performance: return "Performance Tests"
        }
    }

    var fileSuffix: String {
        switch self {
        case .integration: return "IntegrationTests"
        case .e2e: return "E2ETests"
        case .performance: return "PerformanceTests"
        }
    }
}

// MARK: - IntegrationTestAction

/// The 'integrationTest' action that generates integration, e2e, and performance tests
/// IMPORTANT: This action does NOT generate unit tests - those are part of the implement action
/// This action:
/// 1. Analyzes the codebase to identify integration points (service boundaries)
/// 2. Generates integration tests for cross-service communication
/// 3. Generates e2e tests for critical user flows
/// 4. Can generate performance test scenarios
actor IntegrationTestAction {

    // MARK: - Dependencies

    private let fileManager: FileManager

    // MARK: - State

    private var currentPlan: IntegrationTestPlan?
    private var workingDirectory: String?

    // MARK: - Initialization

    init() {
        self.fileManager = .default
    }

    // MARK: - Public API

    /// Analyze the codebase and identify integration points
    /// - Parameter workingDir: The working directory to analyze
    /// - Returns: Array of detected integration points
    func analyzeIntegrationPoints(in workingDir: String) async throws -> [IntegrationPoint] {
        try validateWorkingDirectory(workingDir)
        self.workingDirectory = workingDir

        var integrationPoints: [IntegrationPoint] = []

        // Find all Swift service files
        let serviceFiles = try findServiceFiles(in: workingDir)

        for file in serviceFiles {
            let filePoints = try analyzeFileForIntegrationPoints(file, workingDir: workingDir)
            integrationPoints.append(contentsOf: filePoints)
        }

        // Sort by priority
        integrationPoints.sort { $0.type.testPriority > $1.type.testPriority }

        return integrationPoints
    }

    /// Identify testable E2E user flows
    /// - Parameter workingDir: The working directory to analyze
    /// - Returns: Array of identified E2E flows
    func identifyE2EFlows(in workingDir: String) async throws -> [E2EFlow] {
        try validateWorkingDirectory(workingDir)
        self.workingDirectory = workingDir

        var flows: [E2EFlow] = []

        // Find view files to identify user entry points
        let viewFiles = try findViewFiles(in: workingDir)

        for viewFile in viewFiles {
            let fileFlows = try analyzeViewForFlows(viewFile, workingDir: workingDir)
            flows.append(contentsOf: fileFlows)
        }

        // Mark critical paths
        flows = flows.map { flow in
            var updatedFlow = flow
            // Flows involving auth, data persistence, or core actions are critical
            let criticalKeywords = ["auth", "login", "save", "create", "delete", "worktree", "agent", "launch"]
            let isCritical = criticalKeywords.contains { flow.name.lowercased().contains($0) }
            return E2EFlow(
                id: updatedFlow.id,
                name: updatedFlow.name,
                description: updatedFlow.description,
                steps: updatedFlow.steps,
                entryPoint: updatedFlow.entryPoint,
                criticalPath: isCritical,
                estimatedDuration: updatedFlow.estimatedDuration
            )
        }

        return flows
    }

    /// Generate performance test scenarios
    /// - Parameter workingDir: The working directory to analyze
    /// - Returns: Array of performance test scenarios
    func generatePerformanceScenarios(in workingDir: String) async throws -> [PerformanceTestScenario] {
        try validateWorkingDirectory(workingDir)
        self.workingDirectory = workingDir

        var scenarios: [PerformanceTestScenario] = []

        // Find actor/service files that handle heavy operations
        let serviceFiles = try findServiceFiles(in: workingDir)

        for file in serviceFiles {
            let fileName = (file as NSString).lastPathComponent
            let componentName = fileName.replacingOccurrences(of: ".swift", with: "")

            // Analyze for performance-sensitive operations
            let content = try? String(contentsOfFile: file, encoding: .utf8)

            // Process-related operations
            if content?.contains("Process()") == true || content?.contains("ProcessRunner") == true {
                scenarios.append(PerformanceTestScenario(
                    name: "\(componentName) Process Launch",
                    description: "Measure time to launch and communicate with subprocess",
                    targetComponent: componentName,
                    operation: "Process launch and initial output",
                    expectedLatency: "< 500ms",
                    loadProfile: .single,
                    metrics: [.latency, .memoryUsage]
                ))
            }

            // Git operations
            if content?.contains("GitService") == true || componentName.contains("Git") {
                scenarios.append(PerformanceTestScenario(
                    name: "\(componentName) Git Operations",
                    description: "Measure time for git worktree operations",
                    targetComponent: componentName,
                    operation: "Git worktree creation/listing",
                    expectedLatency: "< 1s",
                    loadProfile: .single,
                    metrics: [.latency]
                ))
            }

            // MCP communication
            if content?.contains("MCPClient") == true || componentName.contains("MCP") {
                scenarios.append(PerformanceTestScenario(
                    name: "\(componentName) MCP Communication",
                    description: "Measure MCP server communication latency",
                    targetComponent: componentName,
                    operation: "MCP tool call round-trip",
                    expectedLatency: "< 100ms",
                    loadProfile: .burst,
                    metrics: [.latency, .throughput]
                ))
            }

            // File operations
            if content?.contains("FileManager") == true && content?.contains("contents(") == true {
                scenarios.append(PerformanceTestScenario(
                    name: "\(componentName) File Operations",
                    description: "Measure file read/write performance",
                    targetComponent: componentName,
                    operation: "File I/O operations",
                    expectedLatency: "< 50ms",
                    loadProfile: .sustained,
                    metrics: [.latency, .throughput]
                ))
            }
        }

        return scenarios
    }

    /// Generate a complete integration test plan
    /// - Parameter workingDir: The working directory to analyze
    /// - Returns: A complete integration test plan
    func generateTestPlan(in workingDir: String) async throws -> IntegrationTestPlan {
        try validateWorkingDirectory(workingDir)
        self.workingDirectory = workingDir

        // Run all analyses
        let integrationPoints = try await analyzeIntegrationPoints(in: workingDir)
        let e2eFlows = try await identifyE2EFlows(in: workingDir)
        let performanceScenarios = try await generatePerformanceScenarios(in: workingDir)

        // Generate suggested test files
        let suggestedFiles = generateSuggestedTestFiles(
            integrationPoints: integrationPoints,
            e2eFlows: e2eFlows,
            performanceScenarios: performanceScenarios
        )

        let plan = IntegrationTestPlan(
            workingDirectory: workingDir,
            integrationPoints: integrationPoints,
            e2eFlows: e2eFlows,
            performanceScenarios: performanceScenarios,
            suggestedTestFiles: suggestedFiles
        )

        currentPlan = plan
        return plan
    }

    /// Generate integration test output file
    /// - Parameters:
    ///   - plan: The test plan to output
    ///   - outputPath: Optional custom output path
    /// - Returns: Path to the generated file
    func generateTestPlanMD(for plan: IntegrationTestPlan, outputPath: String? = nil) throws -> String {
        let path = outputPath ?? "\(plan.workingDirectory)/integration-tests.md"
        let content = formatTestPlanMD(plan)

        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw IntegrationTestActionError.outputFailed(path: path, reason: error.localizedDescription)
        }

        return path
    }

    /// Get the current test plan
    func getCurrentPlan() -> IntegrationTestPlan? {
        currentPlan
    }

    /// Get integration points filtered by type
    func getIntegrationPoints(type: IntegrationPointType) -> [IntegrationPoint] {
        currentPlan?.integrationPoints.filter { $0.type == type } ?? []
    }

    /// Get critical E2E flows
    func getCriticalFlows() -> [E2EFlow] {
        currentPlan?.e2eFlows.filter { $0.criticalPath } ?? []
    }

    /// Check if test plan would overlap with existing unit tests
    /// - Parameter testFiles: List of existing test file paths
    /// - Returns: True if there's no overlap (good), false if overlap detected
    func verifyNoUnitTestOverlap(existingTestFiles: [String]) -> Bool {
        guard let plan = currentPlan else { return true }

        // Unit test files typically contain "Tests.swift" without "Integration", "E2E", or "Performance"
        let unitTestFiles = existingTestFiles.filter { file in
            let fileName = (file as NSString).lastPathComponent.lowercased()
            return fileName.contains("tests.swift") &&
                   !fileName.contains("integration") &&
                   !fileName.contains("e2e") &&
                   !fileName.contains("performance")
        }

        // Check if any suggested files match unit test patterns
        for suggested in plan.suggestedTestFiles {
            let suggestedName = (suggested.path as NSString).lastPathComponent.lowercased()

            for unitTest in unitTestFiles {
                let unitTestName = (unitTest as NSString).lastPathComponent.lowercased()

                // Extract component name from both
                let suggestedComponent = suggestedName
                    .replacingOccurrences(of: "integrationtests.swift", with: "")
                    .replacingOccurrences(of: "e2etests.swift", with: "")
                    .replacingOccurrences(of: "performancetests.swift", with: "")

                let unitTestComponent = unitTestName.replacingOccurrences(of: "tests.swift", with: "")

                // If testing same component, that's fine - we're testing different aspects
                // Only warn if the test names are identical (which shouldn't happen with our naming)
                if suggestedName == unitTestName {
                    return false // Overlap detected
                }
            }
        }

        return true // No overlap
    }

    // MARK: - Private Methods

    private func validateWorkingDirectory(_ path: String) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw IntegrationTestActionError.invalidWorkingDirectory(path: path)
        }

        let gitPath = "\(path)/.git"
        guard fileManager.fileExists(atPath: gitPath) else {
            throw IntegrationTestActionError.gitNotAvailable
        }
    }

    private func findServiceFiles(in workingDir: String) throws -> [String] {
        var serviceFiles: [String] = []
        let servicesPath = "\(workingDir)/XRoads/Services"
        let viewModelsPath = "\(workingDir)/XRoads/ViewModels"

        // Find files in Services directory
        if fileManager.fileExists(atPath: servicesPath) {
            if let files = try? fileManager.contentsOfDirectory(atPath: servicesPath) {
                for file in files where file.hasSuffix(".swift") {
                    serviceFiles.append("\(servicesPath)/\(file)")
                }
            }

            // Check subdirectories
            if let subdirs = try? fileManager.contentsOfDirectory(atPath: servicesPath) {
                for subdir in subdirs {
                    let subdirPath = "\(servicesPath)/\(subdir)"
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: subdirPath, isDirectory: &isDir), isDir.boolValue {
                        if let subFiles = try? fileManager.contentsOfDirectory(atPath: subdirPath) {
                            for file in subFiles where file.hasSuffix(".swift") {
                                serviceFiles.append("\(subdirPath)/\(file)")
                            }
                        }
                    }
                }
            }
        }

        // Find files in ViewModels directory
        if fileManager.fileExists(atPath: viewModelsPath) {
            if let files = try? fileManager.contentsOfDirectory(atPath: viewModelsPath) {
                for file in files where file.hasSuffix(".swift") {
                    serviceFiles.append("\(viewModelsPath)/\(file)")
                }
            }
        }

        return serviceFiles
    }

    private func findViewFiles(in workingDir: String) throws -> [String] {
        var viewFiles: [String] = []
        let viewsPath = "\(workingDir)/XRoads/Views"

        func scanDirectory(_ path: String) {
            guard let files = try? fileManager.contentsOfDirectory(atPath: path) else { return }

            for file in files {
                let fullPath = "\(path)/\(file)"
                var isDir: ObjCBool = false

                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    if isDir.boolValue {
                        scanDirectory(fullPath)
                    } else if file.hasSuffix(".swift") && (file.contains("View") || file.contains("Sheet")) {
                        viewFiles.append(fullPath)
                    }
                }
            }
        }

        if fileManager.fileExists(atPath: viewsPath) {
            scanDirectory(viewsPath)
        }

        return viewFiles
    }

    private func analyzeFileForIntegrationPoints(_ filePath: String, workingDir: String) throws -> [IntegrationPoint] {
        var points: [IntegrationPoint] = []

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }

        let fileName = (filePath as NSString).lastPathComponent
        let componentName = fileName.replacingOccurrences(of: ".swift", with: "")
        let relativePath = filePath.replacingOccurrences(of: workingDir + "/", with: "")
        let lines = content.components(separatedBy: .newlines)

        // Detect various integration patterns
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            // Service-to-Service: actor/class calling another service
            if line.contains("private let") || line.contains("private var") {
                let servicePatterns = ["Service", "Client", "Runner", "Coordinator", "Monitor", "Factory", "Registry", "Loader"]
                for pattern in servicePatterns {
                    if line.contains(pattern) && !line.contains("//") {
                        // Extract the service name
                        if let match = line.range(of: ":\\s*\\w+\(pattern)", options: .regularExpression) {
                            let targetName = String(line[match]).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                            points.append(IntegrationPoint(
                                type: .serviceToService,
                                sourceFile: relativePath,
                                sourceName: componentName,
                                targetName: targetName,
                                lineNumber: lineNumber,
                                description: "\(componentName) depends on \(targetName)",
                                complexity: .medium,
                                suggestedTestApproach: "Mock \(targetName) and verify \(componentName) handles responses correctly"
                            ))
                        }
                    }
                }
            }

            // Process execution
            if line.contains("Process()") || line.contains("ProcessRunner") {
                points.append(IntegrationPoint(
                    type: .processExecution,
                    sourceFile: relativePath,
                    sourceName: componentName,
                    targetName: "System Process",
                    lineNumber: lineNumber,
                    description: "\(componentName) spawns external processes",
                    complexity: .high,
                    suggestedTestApproach: "Use mock process or test with real subprocess in isolated environment"
                ))
            }

            // MCP Communication
            if line.contains("MCPClient") || line.contains("JSON-RPC") || line.contains("mcp") {
                points.append(IntegrationPoint(
                    type: .mcp,
                    sourceFile: relativePath,
                    sourceName: componentName,
                    targetName: "MCP Server",
                    lineNumber: lineNumber,
                    description: "\(componentName) communicates via MCP protocol",
                    complexity: .high,
                    suggestedTestApproach: "Mock MCP server responses or use test server instance"
                ))
            }

            // File system operations
            if line.contains("FileManager") && (line.contains("write") || line.contains("read") || line.contains("create") || line.contains("remove")) {
                points.append(IntegrationPoint(
                    type: .fileSystem,
                    sourceFile: relativePath,
                    sourceName: componentName,
                    targetName: "File System",
                    lineNumber: lineNumber,
                    description: "\(componentName) performs file system operations",
                    complexity: .low,
                    suggestedTestApproach: "Use temporary directory for test isolation"
                ))
            }

            // Git operations
            if line.contains("git") && (line.contains("Process") || line.contains("GitService")) {
                points.append(IntegrationPoint(
                    type: .processExecution,
                    sourceFile: relativePath,
                    sourceName: componentName,
                    targetName: "Git CLI",
                    lineNumber: lineNumber,
                    description: "\(componentName) executes git commands",
                    complexity: .high,
                    suggestedTestApproach: "Use test git repository with known state"
                ))
            }

            // External API/Network calls
            if line.contains("URLSession") || line.contains("URLRequest") || line.contains("fetch") {
                points.append(IntegrationPoint(
                    type: .network,
                    sourceFile: relativePath,
                    sourceName: componentName,
                    targetName: "External API",
                    lineNumber: lineNumber,
                    description: "\(componentName) makes network requests",
                    complexity: .medium,
                    suggestedTestApproach: "Use URLProtocol mock or test server"
                ))
            }
        }

        // Remove duplicates (same type in same file)
        var seen = Set<String>()
        points = points.filter { point in
            let key = "\(point.type.rawValue)-\(point.sourceName)-\(point.targetName)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return points
    }

    private func analyzeViewForFlows(_ filePath: String, workingDir: String) throws -> [E2EFlow] {
        var flows: [E2EFlow] = []

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }

        let fileName = (filePath as NSString).lastPathComponent
        let viewName = fileName.replacingOccurrences(of: ".swift", with: "")
        let relativePath = filePath.replacingOccurrences(of: workingDir + "/", with: "")

        // Identify common flow patterns

        // Sheet presentations (user action flows)
        if content.contains(".sheet(") || content.contains("Sheet") {
            let sheetName = viewName.replacingOccurrences(of: "View", with: "")
            flows.append(E2EFlow(
                name: "\(sheetName) Flow",
                description: "User interaction flow through \(viewName)",
                steps: [
                    E2EStep(order: 1, action: "Open \(viewName)", expectedResult: "View displays correctly", component: viewName, assertions: ["View is visible", "Initial state is correct"]),
                    E2EStep(order: 2, action: "Interact with form/content", expectedResult: "Input is accepted", component: viewName, assertions: ["Form validates input"]),
                    E2EStep(order: 3, action: "Submit/confirm action", expectedResult: "Action completes", component: viewName, assertions: ["State updates", "Sheet dismisses"])
                ],
                entryPoint: relativePath,
                estimatedDuration: "1-5s"
            ))
        }

        // Button actions
        if content.contains("Button(") && (content.contains("async") || content.contains("Task {")) {
            flows.append(E2EFlow(
                name: "\(viewName) Actions",
                description: "Button-triggered async actions in \(viewName)",
                steps: [
                    E2EStep(order: 1, action: "Trigger button action", expectedResult: "Loading state shown", component: viewName, assertions: ["Loading indicator visible"]),
                    E2EStep(order: 2, action: "Wait for async completion", expectedResult: "Operation completes", component: viewName, assertions: ["No errors", "Result displayed"])
                ],
                entryPoint: relativePath,
                estimatedDuration: "< 1s"
            ))
        }

        // Worktree/Agent creation (critical path)
        if content.contains("createWorktree") || content.contains("launchAgent") || viewName.contains("Worktree") {
            flows.append(E2EFlow(
                name: "Worktree Creation",
                description: "Complete worktree creation and agent launch flow",
                steps: [
                    E2EStep(order: 1, action: "Open create worktree sheet", expectedResult: "Sheet appears", component: viewName, assertions: ["Form fields visible"]),
                    E2EStep(order: 2, action: "Fill in worktree details", expectedResult: "Form validates", component: viewName, assertions: ["Name valid", "Path valid"]),
                    E2EStep(order: 3, action: "Select agent type", expectedResult: "Agent selected", component: viewName, assertions: ["CLI available"]),
                    E2EStep(order: 4, action: "Create worktree", expectedResult: "Worktree created", component: "GitService", assertions: ["Git worktree exists", "Branch created"]),
                    E2EStep(order: 5, action: "Launch agent", expectedResult: "Agent running", component: "AgentLauncher", assertions: ["Process started", "Output streaming"])
                ],
                entryPoint: relativePath,
                criticalPath: true,
                estimatedDuration: "> 5s"
            ))
        }

        return flows
    }

    private func generateSuggestedTestFiles(
        integrationPoints: [IntegrationPoint],
        e2eFlows: [E2EFlow],
        performanceScenarios: [PerformanceTestScenario]
    ) -> [SuggestedTestFile] {
        var files: [SuggestedTestFile] = []

        // Group integration points by source component
        let pointsByComponent = Dictionary(grouping: integrationPoints) { $0.sourceName }

        for (component, points) in pointsByComponent {
            let testCases = points.map { "test\($0.targetName.replacingOccurrences(of: " ", with: ""))Integration" }

            files.append(SuggestedTestFile(
                path: "Tests/Integration/\(component)IntegrationTests.swift",
                testType: .integration,
                targetComponents: [component] + points.map { $0.targetName },
                suggestedTestCases: testCases
            ))
        }

        // E2E test files
        if !e2eFlows.isEmpty {
            let criticalFlows = e2eFlows.filter { $0.criticalPath }
            if !criticalFlows.isEmpty {
                files.append(SuggestedTestFile(
                    path: "Tests/E2E/CriticalPathsE2ETests.swift",
                    testType: .e2e,
                    targetComponents: criticalFlows.map { $0.entryPoint },
                    suggestedTestCases: criticalFlows.map { "test\($0.name.replacingOccurrences(of: " ", with: ""))" }
                ))
            }

            let otherFlows = e2eFlows.filter { !$0.criticalPath }
            if !otherFlows.isEmpty {
                files.append(SuggestedTestFile(
                    path: "Tests/E2E/UserFlowsE2ETests.swift",
                    testType: .e2e,
                    targetComponents: otherFlows.map { $0.entryPoint },
                    suggestedTestCases: otherFlows.map { "test\($0.name.replacingOccurrences(of: " ", with: ""))" }
                ))
            }
        }

        // Performance test files
        if !performanceScenarios.isEmpty {
            let componentGroups = Dictionary(grouping: performanceScenarios) { $0.targetComponent }

            for (component, scenarios) in componentGroups {
                files.append(SuggestedTestFile(
                    path: "Tests/Performance/\(component)PerformanceTests.swift",
                    testType: .performance,
                    targetComponents: [component],
                    suggestedTestCases: scenarios.map { "testPerformance\($0.operation.replacingOccurrences(of: " ", with: ""))" }
                ))
            }
        }

        return files
    }

    private func formatTestPlanMD(_ plan: IntegrationTestPlan) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var md: [String] = []

        // Header
        md.append("# Integration Test Plan")
        md.append("")
        md.append("**Generated:** \(dateFormatter.string(from: plan.createdAt))")
        md.append("**Working Directory:** \(plan.workingDirectory)")
        md.append("")
        md.append("> **Note:** This plan covers integration, E2E, and performance tests ONLY.")
        md.append("> Unit tests should be written as part of the implementation phase.")
        md.append("")

        // Summary
        md.append("## Summary")
        md.append("")
        md.append("| Category | Count |")
        md.append("|----------|-------|")
        md.append("| Integration Points | \(plan.integrationPoints.count) |")
        md.append("| E2E Flows | \(plan.e2eFlows.count) |")
        md.append("| Performance Scenarios | \(plan.performanceScenarios.count) |")
        md.append("| Suggested Test Files | \(plan.suggestedTestFiles.count) |")
        md.append("")

        // Integration Points
        if !plan.integrationPoints.isEmpty {
            md.append("## Integration Points")
            md.append("")

            let grouped = Dictionary(grouping: plan.integrationPoints) { $0.type }
            for type in IntegrationPointType.allCases {
                if let points = grouped[type], !points.isEmpty {
                    md.append("### \(type.displayName)")
                    md.append("")
                    for point in points {
                        md.append("#### \(point.sourceName) → \(point.targetName)")
                        md.append("- **File:** `\(point.locationString)`")
                        md.append("- **Complexity:** \(point.complexity.displayName)")
                        md.append("- **Description:** \(point.description)")
                        md.append("- **Test Approach:** \(point.suggestedTestApproach)")
                        md.append("")
                    }
                }
            }
        }

        // E2E Flows
        if !plan.e2eFlows.isEmpty {
            md.append("## E2E User Flows")
            md.append("")

            let criticalFlows = plan.e2eFlows.filter { $0.criticalPath }
            let normalFlows = plan.e2eFlows.filter { !$0.criticalPath }

            if !criticalFlows.isEmpty {
                md.append("### Critical Paths (Must Test)")
                md.append("")
                for flow in criticalFlows {
                    md.append("#### 🔴 \(flow.name)")
                    md.append("**Entry Point:** `\(flow.entryPoint)`")
                    md.append("**Duration:** \(flow.estimatedDuration)")
                    md.append("")
                    md.append("**Steps:**")
                    for step in flow.steps {
                        md.append("\(step.order). **\(step.action)** → \(step.expectedResult)")
                        if !step.assertions.isEmpty {
                            md.append("   - Assertions: \(step.assertions.joined(separator: ", "))")
                        }
                    }
                    md.append("")
                }
            }

            if !normalFlows.isEmpty {
                md.append("### Standard Flows")
                md.append("")
                for flow in normalFlows {
                    md.append("#### \(flow.name)")
                    md.append("**Entry Point:** `\(flow.entryPoint)`")
                    md.append("**Duration:** \(flow.estimatedDuration)")
                    md.append("")
                    md.append("**Steps:**")
                    for step in flow.steps {
                        md.append("\(step.order). **\(step.action)** → \(step.expectedResult)")
                    }
                    md.append("")
                }
            }
        }

        // Performance Scenarios
        if !plan.performanceScenarios.isEmpty {
            md.append("## Performance Test Scenarios")
            md.append("")
            for scenario in plan.performanceScenarios {
                md.append("### \(scenario.name)")
                md.append("- **Component:** \(scenario.targetComponent)")
                md.append("- **Operation:** \(scenario.operation)")
                md.append("- **Expected Latency:** \(scenario.expectedLatency)")
                md.append("- **Load Profile:** \(scenario.loadProfile.displayName)")
                md.append("- **Metrics:** \(scenario.metrics.map { $0.displayName }.joined(separator: ", "))")
                md.append("")
            }
        }

        // Suggested Test Files
        if !plan.suggestedTestFiles.isEmpty {
            md.append("## Suggested Test Files to Create")
            md.append("")
            for file in plan.suggestedTestFiles {
                md.append("### `\(file.path)`")
                md.append("**Type:** \(file.testType.displayName)")
                md.append("**Targets:** \(file.targetComponents.joined(separator: ", "))")
                md.append("")
                md.append("**Suggested Test Cases:**")
                for testCase in file.suggestedTestCases {
                    md.append("- `\(testCase)()`")
                }
                md.append("")
            }
        }

        // Footer
        md.append("---")
        md.append("*Generated by XRoads Integration Test Action*")
        md.append("*This file does NOT include unit tests - those are written with implementation*")

        return md.joined(separator: "\n")
    }
}

// MARK: - Convenience Extensions

extension IntegrationTestAction {

    /// Quick analysis and plan generation
    /// - Parameter workingDir: Working directory path
    /// - Returns: Path to generated integration-tests.md
    func quickAnalyze(in workingDir: String) async throws -> String {
        let plan = try await generateTestPlan(in: workingDir)

        if !plan.hasContent {
            throw IntegrationTestActionError.noIntegrationPointsFound
        }

        return try generateTestPlanMD(for: plan)
    }

    /// Get summary of current plan
    func getPlanSummary() -> String {
        guard let plan = currentPlan else {
            return "No plan loaded"
        }

        var summary = "Integration Test Plan\n"
        summary += "---------------------\n"
        summary += "Integration Points: \(plan.integrationPoints.count)\n"
        summary += "E2E Flows: \(plan.e2eFlows.count) (\(plan.e2eFlows.filter { $0.criticalPath }.count) critical)\n"
        summary += "Performance Scenarios: \(plan.performanceScenarios.count)\n"
        summary += "Test Files to Create: \(plan.suggestedTestFiles.count)"

        return summary
    }

    /// Check if there are critical flows that need testing
    func hasCriticalFlows() -> Bool {
        currentPlan?.e2eFlows.contains { $0.criticalPath } ?? false
    }

    /// Get all high-complexity integration points
    func getHighComplexityPoints() -> [IntegrationPoint] {
        currentPlan?.integrationPoints.filter { $0.complexity == .high || $0.complexity == .critical } ?? []
    }
}
