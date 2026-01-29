//
//  SettingsManager.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let settingsFolderPathKey = "settingsFolderPath"
    private let settingsFolderBookmarkKey = "settingsFolderBookmark"
    private let componentsSearchPathKey = "componentsSearchPath"
    private let componentsSearchPathBookmarkKey = "componentsSearchPathBookmark"
    private let authorizedFoldersKey = "authorizedFolders"
    
    private init() {
        restoreSecurityScopedAccess()
    }
    
    private func restoreSecurityScopedAccess() {
        restoreURL(for: settingsFolderBookmarkKey)
        restoreURL(for: componentsSearchPathBookmarkKey)
        
        // Restore all authorized folders
        if let bookmarks = UserDefaults.standard.dictionary(forKey: authorizedFoldersKey) as? [String: Data] {
            for (path, data) in bookmarks {
                restoreURL(from: data, for: path)
            }
        }
    }
    
    private func restoreURL(for key: String) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
            return
        }
        restoreURL(from: bookmarkData, for: key)
    }
    
    private func restoreURL(from bookmarkData: Data, for identifier: String) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("Bookmark for \(identifier) is stale")
            }
            
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("Failed to resolve security-scoped bookmark for \(identifier): \(error)")
        }
    }
    
    /// Get all authorized folder paths
    var authorizedFolders: [String] {
        let bookmarks = UserDefaults.standard.dictionary(forKey: authorizedFoldersKey) as? [String: Data] ?? [:]
        return Array(bookmarks.keys).sorted()
    }
    
    /// Add an authorized folder
    func addAuthorizedFolder(_ url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            var bookmarks = UserDefaults.standard.dictionary(forKey: authorizedFoldersKey) as? [String: Data] ?? [:]
            bookmarks[url.path] = bookmarkData
            UserDefaults.standard.set(bookmarks, forKey: authorizedFoldersKey)
            
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("Failed to create security-scoped bookmark for folder: \(error)")
        }
    }
    
    /// Remove an authorized folder
    func removeAuthorizedFolder(at path: String) {
        var bookmarks = UserDefaults.standard.dictionary(forKey: authorizedFoldersKey) as? [String: Data] ?? [:]
        bookmarks.removeValue(forKey: path)
        UserDefaults.standard.set(bookmarks, forKey: authorizedFoldersKey)
    }
    
    /// Get bookmark data for a path if it's authorized or a subpath of an authorized folder
    func bookmarkData(for path: String) -> Data? {
        let bookmarks = UserDefaults.standard.dictionary(forKey: authorizedFoldersKey) as? [String: Data] ?? [:]
        
        // Check for exact match
        if let data = bookmarks[path] {
            return data
        }
        
        // Check if path is a subpath of any authorized folder
        // Sort keys by length descending to find the most specific parent
        let sortedPaths = bookmarks.keys.sorted { $0.count > $1.count }
        for parentPath in sortedPaths {
            if path.hasPrefix(parentPath) {
                return bookmarks[parentPath]
            }
        }
        
        return nil
    }
    
    /// Get the current components search path
    var componentsSearchPath: String {
        get {
            UserDefaults.standard.string(forKey: componentsSearchPathKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: componentsSearchPathKey)
        }
    }
    
    func saveComponentsSearchPathBookmark(_ url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: componentsSearchPathBookmarkKey)
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("Failed to create security-scoped bookmark for components path: \(error)")
        }
    }
    
    /// Get the default settings folder path (SharkSpace in Documents)
    var defaultSettingsFolderPath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("SharkSpace").path
    }
    
    /// Get the current settings folder path, or default if not set
    var settingsFolderPath: String {
        get {
            if let savedPath = UserDefaults.standard.string(forKey: settingsFolderPathKey), !savedPath.isEmpty {
                return savedPath
            }
            return defaultSettingsFolderPath
        }
        set {
            UserDefaults.standard.set(newValue, forKey: settingsFolderPathKey)
        }
    }
    
    /// Get the settings folder URL, creating it if necessary
    func getSettingsFolderURL() throws -> URL {
        let path = settingsFolderPath
        let url = URL(fileURLWithPath: path)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        return url
    }
    
    /// Generate a unique workspace filename
    func generateWorkspaceFilename(baseName: String = "workspace") -> String {
        let folderURL = URL(fileURLWithPath: settingsFolderPath)
        var filename = "\(baseName).code-workspace"
        var counter = 1
        
        while FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(filename).path) {
            filename = "\(baseName)-\(counter).code-workspace"
            counter += 1
        }
        
        return filename
    }
    
    /// Get the full URL for a new workspace file
    func getNewWorkspaceURL(baseName: String = "workspace") throws -> URL {
        let folderURL = try getSettingsFolderURL()
        let filename = generateWorkspaceFilename(baseName: baseName)
        return folderURL.appendingPathComponent(filename)
    }
}

