//
//  Folder.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

enum GitReference: Equatable {
    case branch(String)
    case tag(String)
}

struct Folder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var path: String
    var displayName: String? // Optional display name from workspace file
    var bookmarkData: Data? // Security-scoped bookmark data for sandboxed access
    var hasVenomfiles: Bool = false // Whether this folder contains Venomfiles (checked lazily on first add)

    init(id: UUID = UUID(), name: String, path: String, displayName: String? = nil, bookmarkData: Data? = nil, hasVenomfiles: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.hasVenomfiles = hasVenomfiles
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
    
    /// Get the current git branch name
    var gitBranch: String? {
        guard isGitRepository else { return nil }
        
        // Try to use bookmark data if available
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                // The bookmark can point to a parent directory; query using the folder path.
                return getGitBranch(at: path)
            }
        }
        
        // Try global authorized folders from SettingsManager
        if let globalBookmarkData = SettingsManager.shared.bookmarkData(for: path) {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: globalBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               bookmarkedURL.startAccessingSecurityScopedResource() {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                return getGitBranch(at: path)
            }
        }
        
        let url = URL(fileURLWithPath: path)
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return getGitBranch(at: path)
    }
    
    func getGitBranch(at repoPath: String) -> String? {
        if case let .branch(branch) = getGitReference(at: repoPath) {
            return branch
        }
        return nil
    }
    
    /// Get the current git reference (branch or exact tag when detached)
    func getGitReference(at repoPath: String) -> GitReference? {
        if let reference = getGitReferenceFromFiles(at: repoPath) {
            return reference
        }
        
        if let branch = runGitCommand(["branch", "--show-current"], at: repoPath), !branch.isEmpty {
            return .branch(branch)
        }
        
        // Detached HEAD might point to an exact tag.
        if let tag = runGitCommand(["describe", "--tags", "--exact-match"], at: repoPath), !tag.isEmpty {
            return .tag(tag)
        }
        
        return nil
    }
    
    private func getGitReferenceFromFiles(at repoPath: String) -> GitReference? {
        guard let gitDirURL = resolveGitDirectory(at: repoPath) else {
            Log.debug("Git badge: unable to resolve .git for \(repoPath)", category: .workspace)
            return nil
        }
        
        let headURL = gitDirURL.appendingPathComponent("HEAD")
        guard let head = try? String(contentsOf: headURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !head.isEmpty
        else {
            Log.debug("Git badge: missing HEAD at \(headURL.path)", category: .workspace)
            return nil
        }
        
        if head.hasPrefix("ref: ") {
            let ref = String(head.dropFirst(5))
            if ref.hasPrefix("refs/heads/") {
                return .branch(String(ref.dropFirst("refs/heads/".count)))
            }
            return .branch((ref as NSString).lastPathComponent)
        }
        
        if let tag = exactTag(for: head, gitDirURL: gitDirURL) {
            return .tag(tag)
        }
        
        return nil
    }
    
    private func resolveGitDirectory(at repoPath: String) -> URL? {
        let gitMetaURL = URL(fileURLWithPath: repoPath).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: gitMetaURL.path, isDirectory: &isDir), isDir.boolValue {
            return gitMetaURL
        }
        
        guard let content = try? String(contentsOf: gitMetaURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
            content.hasPrefix("gitdir:")
        else {
            return nil
        }
        
        let rawPath = content.replacingOccurrences(of: "gitdir:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if rawPath.hasPrefix("/") {
            return URL(fileURLWithPath: rawPath)
        }
        
        return URL(fileURLWithPath: repoPath).appendingPathComponent(rawPath)
    }
    
    private func exactTag(for commit: String, gitDirURL: URL) -> String? {
        let tagsDir = gitDirURL.appendingPathComponent("refs/tags")
        if let enumerator = FileManager.default.enumerator(at: tagsDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
                    continue
                }
                
                if let sha = try? String(contentsOf: fileURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    sha == commit
                {
                    return fileURL.path.replacingOccurrences(of: tagsDir.path + "/", with: "")
                }
            }
        }
        
        let packedRefsURL = gitDirURL.appendingPathComponent("packed-refs")
        if let packedRefs = try? String(contentsOf: packedRefsURL, encoding: .utf8) {
            for line in packedRefs.split(separator: "\n") {
                if line.hasPrefix("#") || line.hasPrefix("^") { continue }
                let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
                guard parts.count == 2, parts[0] == commit else { continue }
                let ref = parts[1]
                if ref.hasPrefix("refs/tags/") {
                    return String(ref.dropFirst("refs/tags/".count))
                }
            }
        }
        
        return nil
    }
    
    private func runGitCommand(_ arguments: [String], at repoPath: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath] + arguments
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        
        do {
            try task.run()
            let data = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0, let data = data {
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return output?.isEmpty == false ? output : nil
            }
        } catch {
            // Git command failed, return nil
        }
        
        return nil
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

    /// Check if a folder path contains a Venomfiles directory within 3 levels
    static func checkHasVenomfiles(path: String, bookmarkData: Data?, depth: Int = 0) -> Bool {
        guard depth < 3 else { return false }

        // Try to use bookmark data if available - use the resolved URL
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if checkVenomfilesAt(url: url, depth: depth, bookmarkData: bookmarkData) {
                    return true
                }
            }
        }

        // Try global authorized folders from SettingsManager
        if let globalBookmarkData = SettingsManager.shared.bookmarkData(for: path) {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: globalBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               bookmarkedURL.startAccessingSecurityScopedResource() {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                if checkVenomfilesAt(url: bookmarkedURL, depth: depth, bookmarkData: globalBookmarkData) {
                    return true
                }
            }
        }

        // Direct access
        let url = URL(fileURLWithPath: path)
        if checkVenomfilesAt(url: url, depth: depth, bookmarkData: bookmarkData) {
            return true
        }

        return false
    }

    private static func checkVenomfilesAt(url: URL, depth: Int, bookmarkData: Data?) -> Bool {
        var isDirectory: ObjCBool = false

        // Check current directory for Venomfiles
        let venomfilesURL = url.appendingPathComponent("Venomfiles")
        if FileManager.default.fileExists(atPath: venomfilesURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            return true
        }

        // Check subdirectories recursively (up to 3 levels total)
        if depth < 3 {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                for itemURL in contents {
                    if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        if checkVenomfilesAt(url: itemURL, depth: depth + 1, bookmarkData: bookmarkData) {
                            return true
                        }
                    }
                }
            } catch {
                // Ignore errors when scanning subdirectories
            }
        }

        return false
    }
}
