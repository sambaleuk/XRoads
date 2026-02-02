import Foundation

/// Log severity levels
enum LogLevel: String, Codable, Hashable, Sendable, CaseIterable {
    case debug
    case info
    case warn
    case error

    var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warn: return "WARN"
        case .error: return "ERROR"
        }
    }

    var sortOrder: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warn: return 2
        case .error: return 3
        }
    }
}
