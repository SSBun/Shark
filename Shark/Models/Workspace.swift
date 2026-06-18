//
//  Workspace.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

struct Workspace: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var filePath: String // Virtual folder workspace directory path
    var createdAt: Date
    var isPinned: Bool
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, filePath: String, createdAt: Date = Date(), isPinned: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        filePath = try container.decode(String.self, forKey: .filePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = (try? container.decode(Bool.self, forKey: .isPinned)) ?? false
        sortOrder = (try? container.decode(Int.self, forKey: .sortOrder)) ?? 0
    }
}
