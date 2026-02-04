//
//  GitCommit.swift
//  XRoads
//
//  Model for git commit information
//

import Foundation

// MARK: - Git Commit

struct GitCommit: Identifiable, Sendable, Hashable {
    let id: UUID
    let hash: String
    let message: String
    let author: String
    let date: Date

    init(id: UUID = UUID(), hash: String, message: String, author: String = "", date: Date = Date()) {
        self.id = id
        self.hash = hash
        self.message = message
        self.author = author
        self.date = date
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var shortHash: String {
        String(hash.prefix(7))
    }
}
