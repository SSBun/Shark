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

    /// Scan settings folder for virtual workspace directories.
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
                guard isDir.boolValue else { continue }

                guard let metadataURL = VirtualWorkspaceFile.metadataURL(in: itemURL) else { continue }

                do {
                    let workspaceFile = try VirtualWorkspaceFile.parse(from: metadataURL)
                    let attributes = try fileManager.attributesOfItem(atPath: itemURL.path)
                    let creationDate = attributes[.creationDate] as? Date ?? Date()

                    foundWorkspaces.append(Workspace(
                        name: workspaceFile.name,
                        filePath: itemURL.path,
                        createdAt: creationDate
                    ))
                } catch {
                    continue
                }
            }

            workspaces = foundWorkspaces.sorted(by: workspaceSort)
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
            var ws = workspace
            let unpinned = workspaces.filter { !$0.isPinned }
            ws.sortOrder = unpinned.count
            workspaces.append(ws)
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

    /// Create a new virtual workspace directory with metadata.
    func createWorkspace(name: String = "workspace") throws -> Workspace {
        let dirURL = try settingsManager.getNewWorkspaceDirectoryURL(baseName: name)
        let workspaceFile = VirtualWorkspaceFile.createEmpty(name: name)
        try workspaceFile.save(toDirectory: dirURL)
        return workspaceFile.toWorkspace(directoryPath: dirURL.path)
    }

    /// Get git repo paths for a workspace.
    func gitRepoPaths(for workspace: Workspace) throws -> [String] {
        let dirURL = URL(fileURLWithPath: workspace.filePath)
        let workspaceFile = try VirtualWorkspaceFile.parse(fromDirectory: dirURL)
        return workspaceFile.toFolders()
            .filter { $0.isGitRepository }
            .map { $0.path }
    }

    /// Rename a workspace and its corresponding file/directory on disk
    func renameWorkspace(_ workspace: Workspace, to newName: String) throws -> Workspace {
        let oldURL = URL(fileURLWithPath: workspace.filePath)
        let parentURL = oldURL.deletingLastPathComponent()
        let newURL = parentURL.appendingPathComponent(newName)

        if oldURL.path == newURL.path {
            var updated = workspace
            updated.name = newName
            updateWorkspace(updated)
            return updated
        }

        if FileManager.default.fileExists(atPath: newURL.path) {
            throw NSError(domain: "WorkspaceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "A workspace directory with this name already exists."])
        }

        try FileManager.default.moveItem(at: oldURL, to: newURL)

        var workspaceFile = try VirtualWorkspaceFile.parse(fromDirectory: newURL)
        workspaceFile.name = newName
        try workspaceFile.save(toDirectory: newURL)

        var updated = workspace
        updated.name = newName
        updated.filePath = newURL.path
        updateWorkspace(updated)
        return updated
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
                guard isDir.boolValue else { continue }

                guard let metadataURL = VirtualWorkspaceFile.metadataURL(in: itemURL) else { continue }

                do {
                    let workspaceFile = try VirtualWorkspaceFile.parse(from: metadataURL)
                    let attributes = try fileManager.attributesOfItem(atPath: itemURL.path)
                    let creationDate = attributes[.creationDate] as? Date ?? Date()

                    scannedWorkspaces.append(Workspace(
                        name: workspaceFile.name,
                        filePath: itemURL.path,
                        createdAt: creationDate
                    ))
                } catch {
                    continue
                }
            }
        } catch {
            // Settings folder doesn't exist
        }

        // Merge: add new workspaces from disk, keep existing ones
        var mergedWorkspaces = workspaces

        for scanned in scannedWorkspaces {
            if !mergedWorkspaces.contains(where: { $0.filePath == scanned.filePath }) {
                var ws = scanned
                let unpinned = mergedWorkspaces.filter { !$0.isPinned }
                ws.sortOrder = unpinned.count
                mergedWorkspaces.append(ws)
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

        workspaces = mergedWorkspaces.sorted(by: workspaceSort)
        saveWorkspaces()
    }

    // MARK: - Pin & Reorder

    private func workspaceSort(lhs: Workspace, rhs: Workspace) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.createdAt > rhs.createdAt
    }

    func togglePin(_ workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index].isPinned.toggle()

        reassignSortOrders()
        workspaces.sort(by: workspaceSort)
        saveWorkspaces()
    }

    func applyReorder(_ reordered: [Workspace]) {
        for (i, ws) in reordered.enumerated() {
            if let index = workspaces.firstIndex(where: { $0.id == ws.id }) {
                workspaces[index].sortOrder = i
            }
        }
        workspaces.sort(by: workspaceSort)
        saveWorkspaces()
    }

    private func reassignSortOrders() {
        let pinned = workspaces.filter { $0.isPinned }.sorted(by: workspaceSort)
        let unpinned = workspaces.filter { !$0.isPinned }.sorted(by: workspaceSort)

        for (i, ws) in pinned.enumerated() {
            if let index = workspaces.firstIndex(where: { $0.id == ws.id }) {
                workspaces[index].sortOrder = i
            }
        }
        for (i, ws) in unpinned.enumerated() {
            if let index = workspaces.firstIndex(where: { $0.id == ws.id }) {
                workspaces[index].sortOrder = i
            }
        }
    }
}
