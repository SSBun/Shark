//
//  SymlinkManager.swift
//  Shark
//

import Foundation
import os

struct SymlinkManager {
    private static let logger = Logger(subsystem: "com.shark.app", category: "SymlinkManager")
    /// Resolve symlink name collision by prefixing with parent folder name.
    /// "src" → "src" if available, → "ProjectA-src" if taken, → "ProjectA-src-2" if also taken.
    static func resolveSymlinkName(
        preferredName: String,
        parentFolder: String?,
        existingNames: Set<String>
    ) -> String {
        logger.debug("resolveSymlinkName: preferredName=\(preferredName), parentFolder=\(parentFolder ?? "nil"), existingNames=\(existingNames)")
        if !existingNames.contains(preferredName) {
            logger.debug("resolveSymlinkName: using preferred name \(preferredName)")
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
        logger.debug("createSymlink: symlinkPath=\(symlinkPath) → originalPath=\(originalPath)")
        try FileManager.default.createSymbolicLink(
            atPath: symlinkPath,
            withDestinationPath: originalPath
        )
        logger.info("createSymlink: created \(resolvedName) in \(workspaceDirectory)")
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
        logger.debug("removeAllSymlinks: workspaceDirectory=\(workspaceDirectory)")
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: workspaceDirectory)
        logger.debug("removeAllSymlinks: found \(contents.count) items in directory")
        for item in contents {
            guard !item.hasPrefix(".") else { continue }
            let itemPath = (workspaceDirectory as NSString).appendingPathComponent(item)
            // destinationOfSymbolicLink only succeeds for symlinks (doesn't follow them)
            if (try? fileManager.destinationOfSymbolicLink(atPath: itemPath)) != nil {
                logger.debug("removeAllSymlinks: removing symlink \(item)")
                try fileManager.removeItem(atPath: itemPath)
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
        logger.debug("recreateAllSymlinks: workspaceDirectory=\(workspaceDirectory), links.count=\(links.count)")
        // Remove existing symlinks
        try removeAllSymlinks(in: workspaceDirectory)

        var existingNames = Set<String>()
        var updatedLinks: [ClaudeWorkspaceFile.LinkedFolder] = []

        for link in links {
            logger.debug("recreateAllSymlinks: processing link originalPath=\(link.originalPath), folderName=\(link.folderName), parentFolder=\(link.parentFolder ?? "nil")")
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
                logger.info("recreateAllSymlinks: created \(symlinkName) → \(link.originalPath)")
                existingNames.insert(symlinkName)
                updatedLinks.append(ClaudeWorkspaceFile.LinkedFolder(
                    originalPath: link.originalPath,
                    symlinkName: symlinkName,
                    parentFolder: link.parentFolder
                ))
            } else {
                logger.warning("recreateAllSymlinks: skipping \(link.folderName), originalPath does not exist: \(link.originalPath)")
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
