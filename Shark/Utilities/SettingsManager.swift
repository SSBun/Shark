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
    private let componentsSearchPathsKey = "componentsSearchPaths"
    private let componentsSearchPathBookmarksKey = "componentsSearchPathBookmarks"
    // Legacy keys for migration
    private let legacyComponentsSearchPathKey = "componentsSearchPath"
    private let legacyComponentsSearchPathBookmarkKey = "componentsSearchPathBookmark"
    private let authorizedFoldersKey = "authorizedFolders"
    private let defaultTerminalAppKey = "defaultTerminalApp"
    private let defaultIDEAppKey = "defaultIDEApp"

    private init() {
        migrateLegacySearchPath()
        restoreSecurityScopedAccess()
    }

    private func migrateLegacySearchPath() {
        guard UserDefaults.standard.object(forKey: componentsSearchPathsKey) == nil else { return }
        if let oldPath = UserDefaults.standard.string(forKey: legacyComponentsSearchPathKey), !oldPath.isEmpty {
            UserDefaults.standard.set([oldPath], forKey: componentsSearchPathsKey)
            if let oldBookmark = UserDefaults.standard.data(forKey: legacyComponentsSearchPathBookmarkKey) {
                var bookmarks: [String: Data] = [oldPath: oldBookmark]
                UserDefaults.standard.set(bookmarks, forKey: componentsSearchPathBookmarksKey)
            }
        }
    }

    private func restoreSecurityScopedAccess() {
        // Restore component search path bookmarks
        if let bookmarks = UserDefaults.standard.dictionary(forKey: componentsSearchPathBookmarksKey) as? [String: Data] {
            for (_, data) in bookmarks {
                restoreURL(from: data, for: "componentsSearchPath")
            }
        }
        restoreURL(for: settingsFolderBookmarkKey)

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

    // MARK: - Components Search Paths (Multiple)

    var componentsSearchPaths: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: componentsSearchPathsKey) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: componentsSearchPathsKey)
        }
    }

    func addComponentsSearchPath(_ url: URL) {
        var paths = componentsSearchPaths
        guard !paths.contains(url.path) else { return }
        paths.append(url.path)
        componentsSearchPaths = paths

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = UserDefaults.standard.dictionary(forKey: componentsSearchPathBookmarksKey) as? [String: Data] ?? [:]
            bookmarks[url.path] = bookmarkData
            UserDefaults.standard.set(bookmarks, forKey: componentsSearchPathBookmarksKey)
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("Failed to create security-scoped bookmark for components path: \(error)")
        }
    }

    func removeComponentsSearchPath(at path: String) {
        var paths = componentsSearchPaths
        paths.removeAll { $0 == path }
        componentsSearchPaths = paths

        var bookmarks = UserDefaults.standard.dictionary(forKey: componentsSearchPathBookmarksKey) as? [String: Data] ?? [:]
        bookmarks.removeValue(forKey: path)
        UserDefaults.standard.set(bookmarks, forKey: componentsSearchPathBookmarksKey)
    }

    // MARK: - Settings Folder

    /// Get the default settings folder path (SharkSpace in Documents)
    var defaultSettingsFolderPath: String {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to home directory if documents directory is not available
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("SharkSpace").path
        }
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

    /// Get the full URL for a new Claude workspace directory
    func getNewClaudeWorkspaceURL(baseName: String = "claude-workspace") throws -> URL {
        let folderURL = try getSettingsFolderURL()
        var dirName = baseName
        var counter = 1

        while FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(dirName).path) {
            dirName = "\(baseName)-\(counter)"
            counter += 1
        }

        let url = folderURL.appendingPathComponent(dirName)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Terminal App Preference

    /// Get the default terminal app, defaults to system default
    var defaultTerminalApp: TerminalApp {
        get {
            if let savedValue = UserDefaults.standard.string(forKey: defaultTerminalAppKey),
               let terminalApp = TerminalApp(rawValue: savedValue) {
                return terminalApp
            }
            return .systemDefault
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultTerminalAppKey)
        }
    }

    /// Get the default IDE app, defaults to Cursor
    var defaultIDEApp: IDEApp {
        get {
            if let savedValue = UserDefaults.standard.string(forKey: defaultIDEAppKey),
               let ideApp = IDEApp(rawValue: savedValue) {
                return ideApp
            }
            return .cursor
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultIDEAppKey)
        }
    }
}
