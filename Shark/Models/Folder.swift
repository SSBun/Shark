//
//  Folder.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

struct Folder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var path: String
    var displayName: String? // Optional display name from workspace file
    var bookmarkData: Data? // Security-scoped bookmark data for sandboxed access
    
    init(id: UUID = UUID(), name: String, path: String, displayName: String? = nil, bookmarkData: Data? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.displayName = displayName
        self.bookmarkData = bookmarkData
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
        
        // Try to use bookmark data if available
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) && isDirectory.boolValue
            }
        }
        
        // Try global authorized folders from SettingsManager
        if let globalBookmarkData = SettingsManager.shared.bookmarkData(for: path) {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: globalBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               bookmarkedURL.startAccessingSecurityScopedResource() {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                
                // CRITICAL: When using a parent bookmark, we MUST check the original path
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) && isDirectory.boolValue
            }
        }
        
        let url = URL(fileURLWithPath: path)
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    /// Check if the folder contains an Xcode project or workspace
    var xcodeProjectPath: String? {
        guard existsOnDisk else { return nil }
        
        let url = URL(fileURLWithPath: path)
        
        // Helper to scan directory
        func scanDirectory(at scanURL: URL) -> String? {
            do {
                // Use resource values to avoid unnecessary disk access if possible
                let contents = try FileManager.default.contentsOfDirectory(at: scanURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                
                // Sort to prefer workspace over project
                let workspaces = contents.filter { $0.pathExtension == "xcworkspace" }
                if let workspace = workspaces.first {
                    return workspace.path
                }
                
                let projects = contents.filter { $0.pathExtension == "xcodeproj" }
                if let project = projects.first {
                    return project.path
                }
            } catch {
                print("Failed to list directory contents for Xcode project check at \(scanURL.path): \(error)")
            }
            return nil
        }
        
        // Try to use bookmark data if available
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               bookmarkedURL.startAccessingSecurityScopedResource() {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                return scanDirectory(at: bookmarkedURL)
            }
        }
        
        // Try global authorized folders from SettingsManager
        if let globalBookmarkData = SettingsManager.shared.bookmarkData(for: path) {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: globalBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               bookmarkedURL.startAccessingSecurityScopedResource() {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                
                // CRITICAL: When using a parent bookmark, we MUST use the original path URL
                // but it is now "unlocked" because the parent bookmark is active.
                return scanDirectory(at: url)
            }
        }
        
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return scanDirectory(at: url)
    }
}

