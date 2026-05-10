//
//  SymlinkManager.swift
//  Shark
//

import Foundation

struct SymlinkManager {
    /// Resolve symlink name collision by prefixing with parent folder name.
    /// "src" → "src" if available, → "ProjectA-src" if taken, → "ProjectA-src-2" if also taken.
    static func resolveSymlinkName(
        preferredName: String,
        parentFolder: String?,
        existingNames: Set<String>
    ) -> String {
        if !existingNames.contains(preferredName) {
            return preferredName
        }

        if let parent = parentFolder, !parent.isEmpty {
            let prefixed = "\(parent)-\(preferredName)"
            if !existingNames.contains(prefixed) {
                return prefixed
            }
            var counter = 2
            while existingNames.contains("\(prefixed)-\(counter)") {
                counter += 1
            }
            return "\(prefixed)-\(counter)"
        }

        var counter = 2
        while existingNames.contains("\(preferredName)-\(counter)") {
            counter += 1
        }
        return "\(preferredName)-\(counter)"
    }

    /// Create a symlink in workspace directory. Returns the actual symlink name used.
    @discardableResult
    static func createSymlink(
        originalPath: String,
        in workspaceDirectory: String,
        preferredName: String,
        parentFolder: String?,
        existingNames: inout Set<String>
    ) throws -> String {
        let resolvedName = resolveSymlinkName(
            preferredName: preferredName,
            parentFolder: parentFolder,
            existingNames: existingNames
        )
        let symlinkPath = (workspaceDirectory as NSString).appendingPathComponent(resolvedName)
        try FileManager.default.createSymbolicLink(
            atPath: symlinkPath,
            withDestinationPath: originalPath
        )
        existingNames.insert(resolvedName)
        return resolvedName
    }

    /// Remove a symlink from workspace directory.
    static func removeSymlink(symlinkName: String, from workspaceDirectory: String) throws {
        let symlinkPath = (workspaceDirectory as NSString).appendingPathComponent(symlinkName)
        if FileManager.default.fileExists(atPath: symlinkPath) {
            try FileManager.default.removeItem(atPath: symlinkPath)
        }
    }

    /// Remove all symlinks in workspace directory (excluding .claude-workspace.json and other dotfiles).
    static func removeAllSymlinks(in workspaceDirectory: String) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: workspaceDirectory)
        for item in contents {
            let itemPath = (workspaceDirectory as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                // Skip directories and hidden files
                if isDir.boolValue || item.hasPrefix(".") { continue }
                // Only remove symbolic links
                let attrs = try fileManager.attributesOfItem(atPath: itemPath)
                if attrs[.systemFileNumber] as? mode_t != nil,
                   (try? fileManager.destinationOfSymbolicLink(atPath: itemPath)) != nil {
                    try fileManager.removeItem(atPath: itemPath)
                }
            }
        }
    }

    /// Recreate all symlinks in a workspace directory from the links list.
    /// Removes old symlinks first, then creates new ones.
    @discardableResult
    static func recreateAllSymlinks(
        links: [ClaudeWorkspaceFile.LinkedFolder],
        in workspaceDirectory: String
    ) throws -> [ClaudeWorkspaceFile.LinkedFolder] {
        // Remove existing symlinks
        try removeAllSymlinks(in: workspaceDirectory)

        var existingNames = Set<String>()
        var updatedLinks: [ClaudeWorkspaceFile.LinkedFolder] = []

        for link in links {
            let symlinkName = resolveSymlinkName(
                preferredName: link.folderName,
                parentFolder: link.parentFolder,
                existingNames: existingNames
            )
            let symlinkPath = (workspaceDirectory as NSString).appendingPathComponent(symlinkName)

            // Only create if original path still exists
            if FileManager.default.fileExists(atPath: link.originalPath) {
                try FileManager.default.createSymbolicLink(
                    atPath: symlinkPath,
                    withDestinationPath: link.originalPath
                )
                existingNames.insert(symlinkName)
                updatedLinks.append(ClaudeWorkspaceFile.LinkedFolder(
                    originalPath: link.originalPath,
                    symlinkName: symlinkName,
                    parentFolder: link.parentFolder
                ))
            }
        }

        return updatedLinks
    }

    /// Validate symlinks in workspace directory. Returns broken link paths.
    static func validateSymlinks(in workspaceDirectory: String) -> [String] {
        var broken: [String] = []
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: workspaceDirectory) else {
            return broken
        }

        for item in contents {
            if item.hasPrefix(".") { continue }
            let itemPath = (workspaceDirectory as NSString).appendingPathComponent(item)
            if let dest = try? fileManager.destinationOfSymbolicLink(atPath: itemPath) {
                if !fileManager.fileExists(atPath: dest) {
                    broken.append(itemPath)
                }
            }
        }

        return broken
    }
}
