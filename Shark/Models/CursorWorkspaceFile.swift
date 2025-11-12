//
//  CursorWorkspaceFile.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

struct CursorWorkspaceFile: Codable {
    var folders: [WorkspaceFolder]
    var settings: [String: AnyCodable]?
    
    struct WorkspaceFolder: Codable {
        let path: String
        let name: String?
    }
}

// Helper for decoding Any type in JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Cannot encode AnyCodable"
                )
            )
        }
    }
}

extension CursorWorkspaceFile {
    /// Create a new empty workspace file
    static func createEmpty() -> CursorWorkspaceFile {
        CursorWorkspaceFile(folders: [], settings: nil)
    }
    
    /// Parse a .code-workspace file from a file URL
    static func parse(from url: URL) throws -> CursorWorkspaceFile {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(CursorWorkspaceFile.self, from: data)
    }
    
    /// Save the workspace file to a URL
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    /// Convert to a Workspace model
    func toWorkspace(filePath: String, name: String? = nil) -> Workspace {
        let workspaceName = name ?? URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        return Workspace(
            name: workspaceName,
            filePath: filePath
        )
    }
    
    /// Get folders listed in this workspace file
    func toFolders() -> [Folder] {
        folders.map { workspaceFolder in
            let folderName = URL(fileURLWithPath: workspaceFolder.path).lastPathComponent
            return Folder(
                name: folderName,
                path: workspaceFolder.path,
                displayName: workspaceFolder.name
            )
        }
    }
    
    /// Get all folder paths
    var folderPaths: [String] {
        folders.map { $0.path }
    }
    
    /// Add a folder to the workspace
    mutating func addFolder(path: String, name: String? = nil) {
        let newFolder = WorkspaceFolder(path: path, name: name)
        folders.append(newFolder)
    }
    
    /// Remove a folder from the workspace
    mutating func removeFolder(path: String) {
        folders.removeAll { $0.path == path }
    }
    
    /// Update folders from Folder array
    mutating func updateFolders(from folderArray: [Folder]) {
        folders = folderArray.map { folder in
            WorkspaceFolder(path: folder.path, name: folder.displayName)
        }
    }
}

