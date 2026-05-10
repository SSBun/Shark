//
//  Workspace.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

enum WorkspaceType: String, Codable, CaseIterable, Identifiable {
    case cursor = "cursor"
    case claude = "claude"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claude: return "Claude Code"
        }
    }

    var systemImageName: String {
        switch self {
        case .cursor: return "cursor.rays"
        case .claude: return "terminal.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .cursor: return "blue"
        case .claude: return "orange"
        }
    }
}

struct Workspace: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var filePath: String // Cursor: path to .code-workspace file; Claude: path to workspace directory
    var createdAt: Date
    var type: WorkspaceType

    init(id: UUID = UUID(), name: String, filePath: String, createdAt: Date = Date(), type: WorkspaceType = .cursor) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.createdAt = createdAt
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        filePath = try container.decode(String.self, forKey: .filePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        type = (try? container.decode(WorkspaceType.self, forKey: .type)) ?? .cursor
    }
}

