//
//  WorkspaceManager.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()

    @Published var workspaces: [Workspace] = []

    private let workspacesKey = "savedWorkspaces"
    private let settingsManager = SettingsManager.shared

    private init() {
        loadWorkspaces()
    }

    /// Load workspaces from disk
    func loadWorkspaces() {
        // First, try to load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: workspacesKey),
           let decoded = try? JSONDecoder().decode([Workspace].self, from: data) {
            workspaces = decoded
            return
        }

        // If no saved workspaces, scan the settings folder for workspace files
        scanSettingsFolderForWorkspaces()
    }

    /// Scan settings folder for workspace files
    func scanSettingsFolderForWorkspaces() {
        do {
            let folderURL = try settingsManager.getSettingsFolderURL()
            let fileManager = FileManager.default

            guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: []) else {
                return
            }

            var foundWorkspaces: [Workspace] = []

            for itemURL in contents {
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir)

                if !isDir.boolValue, itemURL.pathExtension == "code-workspace" {
                    // Cursor workspace file
                    do {
                        let workspaceFile = try CursorWorkspaceFile.parse(from: itemURL)
                        let workspace = workspaceFile.toWorkspace(filePath: itemURL.path)
                        let attributes = try fileManager.attributesOfItem(atPath: itemURL.path)
                        let creationDate = attributes[.creationDate] as? Date ?? Date()

                        foundWorkspaces.append(Workspace(
                            id: workspace.id,
                            name: workspace.name,
                            filePath: workspace.filePath,
                            createdAt: creationDate,
                            type: .cursor
                        ))
                    } catch {
                        continue
                    }
                } else if isDir.boolValue {
                    // Check for Claude workspace directory
                    let metadataURL = itemURL.appendingPathComponent(ClaudeWorkspaceFile.metadataFileName)
                    guard fileManager.fileExists(atPath: metadataURL.path) else { continue }

                    do {
                        let claudeFile = try ClaudeWorkspaceFile.parse(from: metadataURL)
                        let attributes = try fileManager.attributesOfItem(atPath: itemURL.path)
                        let creationDate = attributes[.creationDate] as? Date ?? Date()

                        foundWorkspaces.append(Workspace(
                            name: claudeFile.name,
                            filePath: itemURL.path,
                            createdAt: creationDate,
                            type: .claude
                        ))
                    } catch {
                        continue
                    }
                }
            }

            workspaces = foundWorkspaces.sorted { $0.createdAt > $1.createdAt }
            saveWorkspaces()
        } catch {
            workspaces = []
        }
    }

    /// Save workspaces to UserDefaults
    func saveWorkspaces() {
        if let encoded = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(encoded, forKey: workspacesKey)
        }
    }

    /// Clear all workspaces from the list
    func clearWorkspaces() {
        workspaces = []
        saveWorkspaces()
    }

    /// Add a workspace
    func addWorkspace(_ workspace: Workspace) {
        if !workspaces.contains(where: { $0.filePath == workspace.filePath }) {
            workspaces.append(workspace)
            saveWorkspaces()
        }
    }

    /// Remove a workspace
    func removeWorkspace(_ workspace: Workspace) {
        workspaces.removeAll { $0.id == workspace.id }
        saveWorkspaces()
    }

    /// Update a workspace
    func updateWorkspace(_ workspace: Workspace) {
        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces[index] = workspace
            saveWorkspaces()
        }
    }

    /// Create a new Claude workspace directory with metadata
    func createClaudeWorkspace(name: String = "claude-workspace") throws -> Workspace {
        let dirURL = try settingsManager.getNewClaudeWorkspaceURL(baseName: name)
        var claudeFile = ClaudeWorkspaceFile.createEmpty(name: name)
        try claudeFile.save(toDirectory: dirURL)
        return claudeFile.toWorkspace(directoryPath: dirURL.path)
    }

    /// Get git repo paths for a workspace (works for both Cursor and Claude types)
    func gitRepoPaths(for workspace: Workspace) throws -> [String] {
        switch workspace.type {
        case .cursor:
            let fileURL = URL(fileURLWithPath: workspace.filePath)
            let workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
            return workspaceFile.toFolders()
                .filter { $0.isGitRepository }
                .map { $0.path }
        case .claude:
            let dirURL = URL(fileURLWithPath: workspace.filePath)
            let claudeFile = try ClaudeWorkspaceFile.parse(fromDirectory: dirURL)
            return claudeFile.toFolders()
                .filter { $0.isGitRepository }
                .map { $0.path }
        }
    }

    /// Rename a workspace and its corresponding file/directory on disk
    func renameWorkspace(_ workspace: Workspace, to newName: String) throws -> Workspace {
        let oldURL = URL(fileURLWithPath: workspace.filePath)
        let parentURL = oldURL.deletingLastPathComponent()

        if workspace.type == .claude {
            let newURL = parentURL.appendingPathComponent(newName)

            if oldURL.path == newURL.path {
                // Just update name in metadata
                var updated = workspace
                updated.name = newName
                updateWorkspace(updated)
                return updated
            }

            if FileManager.default.fileExists(atPath: newURL.path) {
                throw NSError(domain: "WorkspaceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "A workspace directory with this name already exists."])
            }

            try FileManager.default.moveItem(at: oldURL, to: newURL)

            // Update name in metadata file
            let metadataURL = newURL.appendingPathComponent(ClaudeWorkspaceFile.metadataFileName)
            var claudeFile = try ClaudeWorkspaceFile.parse(from: metadataURL)
            claudeFile.name = newName
            try claudeFile.save(to: metadataURL)

            var updated = workspace
            updated.name = newName
            updated.filePath = newURL.path
            updateWorkspace(updated)
            return updated
        } else {
            // Cursor workspace
            let newURL = parentURL.appendingPathComponent("\(newName).code-workspace")

            if oldURL.path == newURL.path {
                var updated = workspace
                updated.name = newName
                updateWorkspace(updated)
                return updated
            }

            if FileManager.default.fileExists(atPath: newURL.path) {
                throw NSError(domain: "WorkspaceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "A workspace file with this name already exists."])
            }

            try FileManager.default.moveItem(at: oldURL, to: newURL)

            var updated = workspace
            updated.name = newName
            updated.filePath = newURL.path
            updateWorkspace(updated)
            return updated
        }
    }

    /// Duplicate a Cursor workspace as a new Claude workspace
    func duplicateAsClaude(_ workspace: Workspace) throws -> Workspace {
        guard workspace.type == .cursor else {
            throw NSError(domain: "WorkspaceManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Only Cursor workspaces can be duplicated as Claude workspaces."])
        }

        let fileURL = URL(fileURLWithPath: workspace.filePath)
        let cursorFile = try CursorWorkspaceFile.parse(from: fileURL)

        let dirURL = try settingsManager.getNewClaudeWorkspaceURL(baseName: workspace.name)
        var claudeFile = ClaudeWorkspaceFile.createEmpty(name: workspace.name)

        var existingNames = Set<String>()
        for folder in cursorFile.folders {
            let folderName = URL(fileURLWithPath: folder.path).lastPathComponent
            let parentFolder = folder.name != nil ? URL(fileURLWithPath: folder.path).deletingLastPathComponent().lastPathComponent : nil
            let symlinkName = SymlinkManager.resolveSymlinkName(
                preferredName: folderName,
                parentFolder: parentFolder,
                existingNames: existingNames
            )
            existingNames.insert(symlinkName)
            claudeFile.addLink(originalPath: folder.path, symlinkName: symlinkName, parentFolder: parentFolder)
        }

        try claudeFile.save(toDirectory: dirURL)
        try SymlinkManager.recreateAllSymlinks(links: claudeFile.links, in: dirURL.path)

        return claudeFile.toWorkspace(directoryPath: dirURL.path)
    }

    /// Duplicate a Claude workspace as a new Cursor workspace
    func duplicateAsCursor(_ workspace: Workspace) throws -> Workspace {
        guard workspace.type == .claude else {
            throw NSError(domain: "WorkspaceManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Only Claude workspaces can be duplicated as Cursor workspaces."])
        }

        let dirURL = URL(fileURLWithPath: workspace.filePath)
        let claudeFile = try ClaudeWorkspaceFile.parse(fromDirectory: dirURL)

        let fileURL = try settingsManager.getNewWorkspaceURL(baseName: workspace.name)
        var cursorFile = CursorWorkspaceFile.createEmpty()

        for link in claudeFile.links {
            cursorFile.addFolder(path: link.originalPath)
        }

        try cursorFile.save(to: fileURL)
        return cursorFile.toWorkspace(filePath: fileURL.path)
    }

    /// Refresh workspaces from disk
    func refreshWorkspaces() {
        workspaces = []

        var scannedWorkspaces: [Workspace] = []

        do {
            let folderURL = try settingsManager.getSettingsFolderURL()
            let fileManager = FileManager.default

            guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: []) else {
                return
            }

            for itemURL in contents {
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir)

                if !isDir.boolValue, itemURL.pathExtension == "code-workspace" {
                    do {
                        let workspaceFile = try CursorWorkspaceFile.parse(from: itemURL)
                        let workspace = workspaceFile.toWorkspace(filePath: itemURL.path)
                        let attributes = try fileManager.attributesOfItem(atPath: itemURL.path)
                        let creationDate = attributes[.creationDate] as? Date ?? Date()

                        scannedWorkspaces.append(Workspace(
                            id: workspace.id,
                            name: workspace.name,
                            filePath: workspace.filePath,
                            createdAt: creationDate,
                            type: .cursor
                        ))
                    } catch {
                        continue
                    }
                } else if isDir.boolValue {
                    let metadataURL = itemURL.appendingPathComponent(ClaudeWorkspaceFile.metadataFileName)
                    guard fileManager.fileExists(atPath: metadataURL.path) else { continue }

                    do {
                        let claudeFile = try ClaudeWorkspaceFile.parse(from: metadataURL)
                        let attributes = try fileManager.attributesOfItem(atPath: itemURL.path)
                        let creationDate = attributes[.creationDate] as? Date ?? Date()

                        scannedWorkspaces.append(Workspace(
                            name: claudeFile.name,
                            filePath: itemURL.path,
                            createdAt: creationDate,
                            type: .claude
                        ))
                    } catch {
                        continue
                    }
                }
            }
        } catch {
            // Settings folder doesn't exist
        }

        // Merge: add new workspaces from disk, keep existing ones
        var mergedWorkspaces = workspaces

        for scanned in scannedWorkspaces {
            if !mergedWorkspaces.contains(where: { $0.filePath == scanned.filePath }) {
                mergedWorkspaces.append(scanned)
            }
        }

        // Remove workspaces that no longer exist on disk (if they were in settings folder)
        let settingsFolderPath = settingsManager.settingsFolderPath
        mergedWorkspaces = mergedWorkspaces.filter { workspace in
            if FileManager.default.fileExists(atPath: workspace.filePath) {
                return true
            }
            return !workspace.filePath.hasPrefix(settingsFolderPath)
        }

        workspaces = mergedWorkspaces.sorted { $0.createdAt > $1.createdAt }
        saveWorkspaces()
    }
}
