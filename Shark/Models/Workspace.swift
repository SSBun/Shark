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
    var filePath: String // Path to the .code-workspace file
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, filePath: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.createdAt = createdAt
    }
}

