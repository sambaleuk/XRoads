import Foundation

actor OrchestrationHistoryService {
    private let fileManager: FileManager = .default
    private let directory: URL
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let limit = 50

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".crossroads/history", isDirectory: true)) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("orchestrations.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() async -> [OrchestrationRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let history = try decoder.decode(OrchestrationHistory.self, from: data)
            return history.records
        } catch {
            return []
        }
    }

    func append(record: OrchestrationRecord) async {
        var records = await load()
        records.insert(record, at: 0)
        if records.count > limit {
            records = Array(records.prefix(limit))
        }
        do {
            try ensureDirectory()
            let data = try encoder.encode(OrchestrationHistory(records: records))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // swallow for now
        }
    }

    private func ensureDirectory() throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
