//
//  Workspace.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

enum WorkspaceKind: String, Codable {
    // A virtual workspace directory under the Shark settings folder.
    case workspace
    // A direct reference to an existing folder on disk.
    case project
}

struct Workspace: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var filePath: String // Virtual folder workspace directory path, or the project folder path
    var createdAt: Date
    var isPinned: Bool
    var sortOrder: Int
    var kind: WorkspaceKind

    init(id: UUID = UUID(), name: String, filePath: String, createdAt: Date = Date(), isPinned: Bool = false, sortOrder: Int = 0, kind: WorkspaceKind = .workspace) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        filePath = try container.decode(String.self, forKey: .filePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = (try? container.decode(Bool.self, forKey: .isPinned)) ?? false
        sortOrder = (try? container.decode(Int.self, forKey: .sortOrder)) ?? 0
        kind = (try? container.decode(WorkspaceKind.self, forKey: .kind)) ?? .workspace
    }
}
