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

/// Groups workspaces sharing the same name but different types (e.g., cursor + claude).
struct WorkspaceGroup: Identifiable {
    let name: String
    let workspaces: [Workspace]

    var id: String { name }

    /// Pinned if any workspace in the group is pinned.
    var isPinned: Bool { workspaces.contains { $0.isPinned } }

    /// Sorted: cursor first, then claude.
    static func groups(from workspaces: [Workspace]) -> [WorkspaceGroup] {
        // Group by name, sort each group cursor-first, then sort groups pinned-first.
        let dict = Dictionary(grouping: workspaces) { $0.name }
        let groups = dict.map { name, wss in
            WorkspaceGroup(name: name, workspaces: wss.sorted { $0.type == .cursor && $1.type == .claude })
        }
        return groups.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }
}

struct Workspace: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var filePath: String // Cursor: path to .code-workspace file; Claude: path to workspace directory
    var createdAt: Date
    var type: WorkspaceType
    var isPinned: Bool
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, filePath: String, createdAt: Date = Date(), type: WorkspaceType = .cursor, isPinned: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.createdAt = createdAt
        self.type = type
        self.isPinned = isPinned
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        filePath = try container.decode(String.self, forKey: .filePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        type = (try? container.decode(WorkspaceType.self, forKey: .type)) ?? .cursor
        isPinned = (try? container.decode(Bool.self, forKey: .isPinned)) ?? false
        sortOrder = (try? container.decode(Int.self, forKey: .sortOrder)) ?? 0
    }
}

