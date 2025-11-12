//
//  Folder.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

struct Folder: Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var displayName: String? // Optional display name from workspace file
    
    init(id: UUID = UUID(), name: String, path: String, displayName: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.displayName = displayName
    }
    
    /// Check if the folder exists on disk
    var existsOnDisk: Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    /// Check if the folder is a git repository
    var isGitRepository: Bool {
        guard existsOnDisk else { return false }
        let gitPath = (path as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

