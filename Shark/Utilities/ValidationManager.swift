//
//  ValidationManager.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/26.
//

import Foundation

enum ValidationError: LocalizedError, Equatable {
    case emptyField(fieldName: String)
    case invalidName(fieldName: String, reason: String)
    case pathNotFound(path: String)
    case pathAlreadyExists(path: String)
    case fileNotWritable(path: String)
    case duplicateWorkspace(name: String)
    case invalidCharacters(name: String)
    case nameTooLong(length: Int, maxLength: Int)
    
    var errorDescription: String? {
        switch self {
        case .emptyField(let fieldName):
            return "\(fieldName) cannot be empty"
        case .invalidName(let fieldName, let reason):
            return "\(fieldName) is invalid: \(reason)"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .pathAlreadyExists(let path):
            return "Path already exists: \(path)"
        case .fileNotWritable(let path):
            return "Cannot write to path: \(path)"
        case .duplicateWorkspace(let name):
            return "Workspace '\(name)' already exists"
        case .invalidCharacters(let name):
            return "Name contains invalid characters: \(name)"
        case .nameTooLong(let length, let maxLength):
            return "Name is \(length) characters, maximum allowed is \(maxLength)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyField:
            return "Please enter a valid name"
        case .invalidName:
            return "Please enter a valid name without special characters"
        case .pathNotFound:
            return "Please select a valid folder path"
        case .pathAlreadyExists:
            return "Please choose a different path"
        case .fileNotWritable:
            return "Please check folder permissions or choose a different location"
        case .duplicateWorkspace:
            return "Please choose a different workspace name"
        case .invalidCharacters:
            return "Use only letters, numbers, spaces, hyphens, and underscores"
        case .nameTooLong:
            return "Please shorten the name"
        }
    }
}

struct ValidationManager {
    static let shared = ValidationManager()
    
    private let maxWorkspaceNameLength = 100
    private let maxFolderPathLength = 4096
    
    private let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
    
    private init() {}
    
    func validateWorkspaceName(_ name: String) -> ValidationError? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .emptyField(fieldName: "Workspace name")
        }
        
        if trimmedName.count > maxWorkspaceNameLength {
            return .nameTooLong(length: trimmedName.count, maxLength: maxWorkspaceNameLength)
        }
        
        if let _ = trimmedName.rangeOfCharacter(from: invalidCharacters) {
            return .invalidCharacters(name: trimmedName)
        }
        
        return nil
    }
    
    func validateFolderPath(_ path: String) -> ValidationError? {
        if path.isEmpty {
            return .emptyField(fieldName: "Folder path")
        }
        
        if path.count > maxFolderPathLength {
            return .pathNotFound(path: path)
        }
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            return .pathNotFound(path: path)
        }
        
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            return .pathNotFound(path: path)
        }
        
        return nil
    }
    
    func checkWorkspaceDuplicate(name: String, existingNames: [String]) -> ValidationError? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for existingName in existingNames {
            if existingName.lowercased() == trimmedName {
                return .duplicateWorkspace(name: trimmedName)
            }
        }
        return nil
    }
    
    func canWriteToPath(_ path: String) -> Bool {
        let fileManager = FileManager.default
        let parentURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: parentURL.path, isDirectory: &isDirectory) else {
            return false
        }
        
        return fileManager.isWritableFile(atPath: parentURL.path)
    }
}
