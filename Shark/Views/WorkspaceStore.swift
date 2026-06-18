//
//  WorkspaceStore.swift
//  Shark
//

import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class WorkspaceStore {
    private static let logger = Logger(subsystem: "com.shark.app", category: "WorkspaceStore")

    var workspaces: [Workspace]
    var selectedWorkspace: Workspace?
    var folders: [Folder] = []
    var isLoadingFolders = false
    var isRefreshingVenomfiles = false

    @ObservationIgnored private let workspaceManager: WorkspaceManager
    @ObservationIgnored private let settingsManager: SettingsManager

    init(workspaceManager: WorkspaceManager = .shared, settingsManager: SettingsManager = .shared) {
        self.workspaceManager = workspaceManager
        self.settingsManager = settingsManager
        self.workspaces = workspaceManager.workspaces
    }

    var componentSearchPaths: [String] {
        settingsManager.componentsSearchPaths
    }

    func refreshWorkspaces() {
        workspaceManager.refreshWorkspaces()
        syncWorkspaces()
    }

    func createWorkspace(authManager: AuthorizationManager) async {
        let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
        guard authorized else { return }

        do {
            let workspace = try workspaceManager.createWorkspace()
            workspaceManager.addWorkspace(workspace)
            syncWorkspaces()
            selectedWorkspace = workspace
        } catch {
            print("Failed to create workspace: \(error)")
        }
    }

    func renameWorkspace(_ workspace: Workspace, to newName: String) {
        do {
            let updatedWorkspace = try workspaceManager.renameWorkspace(workspace, to: newName)
            syncWorkspaces()
            if selectedWorkspace?.id == workspace.id {
                selectedWorkspace = updatedWorkspace
            }
        } catch {
            print("Failed to rename workspace: \(error)")
        }
    }

    func removeWorkspace(_ workspace: Workspace) {
        workspaceManager.removeWorkspace(workspace)
        workspaces.removeAll { $0.id == workspace.id }

        if selectedWorkspace?.id == workspace.id {
            selectedWorkspace = nil
            folders = []
        }

        if workspace.filePath.hasPrefix(settingsManager.settingsFolderPath) {
            do {
                try FileManager.default.removeItem(atPath: workspace.filePath)
            } catch {
                print("Could not delete workspace: \(error)")
            }
        }
    }

    func togglePin(_ workspace: Workspace) {
        workspaceManager.togglePin(workspace)
        syncWorkspaces()
    }

    func showWorkspaceInFinder(_ workspace: Workspace) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: workspace.filePath)])
    }

    func openInForkWorkspace(_ workspace: Workspace, authManager: AuthorizationManager) async {
        Log.info("openInForkWorkspace called: \(workspace.name)", category: .workspace)

        let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
        guard authorized else {
            Log.error("Authorization denied for Fork workspace open", category: .workspace)
            return
        }

        do {
            let repoPaths = try workspaceManager.gitRepoPaths(for: workspace)

            Log.info("Found \(repoPaths.count) git repo paths", category: .workspace)
            guard !repoPaths.isEmpty else {
                AlertManager.shared.show(type: .warning, title: "No Git Repos", message: "No git repositories found in this workspace.")
                return
            }

            let result = try await ForkWorkspaceManager.findOrCreateAndOpen(named: workspace.name, repoPaths: repoPaths)
            let message = result.created
                ? "Created Fork workspace '\(workspace.name)' with \(repoPaths.count) repos."
                : "Switched to Fork workspace '\(workspace.name)' with \(repoPaths.count) repos."
            AlertManager.shared.show(type: .info, title: "Fork Workspace", message: message)
        } catch {
            Log.error("openInForkWorkspace error: \(error)", category: .workspace)
            AlertManager.shared.show(type: .error, title: "Error", message: "Failed to open Fork workspace: \(error.localizedDescription)")
        }
    }

    func openGitFoldersInSourceTree(_ workspace: Workspace, authManager: AuthorizationManager) async {
        let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
        guard authorized else { return }

        do {
            for path in try workspaceManager.gitRepoPaths(for: workspace) {
                SourceTreeOpener.openRepository(at: path)
            }
        } catch {
            print("Failed to load workspace: \(error)")
        }
    }

    func loadFoldersForSelectedWorkspace(authManager: AuthorizationManager) async {
        guard let workspace = selectedWorkspace else {
            folders = []
            return
        }

        isLoadingFolders = true
        defer { isLoadingFolders = false }

        let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
        guard authorized else {
            folders = []
            return
        }

        do {
            let workspaceFile = try VirtualWorkspaceFile.parse(fromDirectory: URL(fileURLWithPath: workspace.filePath))
            folders = workspaceFile.toFolders()
        } catch {
            folders = []
        }
    }

    func addFolder(authManager: AuthorizationManager) async {
        guard selectedWorkspace != nil else { return }

        let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
        guard authorized else { return }

        let selectedURLs = FileDialogHelper.selectFolders()
        guard !selectedURLs.isEmpty else { return }

        let newFolders = await folders(from: selectedURLs)
        folders.append(contentsOf: newFolders)
    }

    func addSelectedFolders(_ selectedFolders: [Folder]) async {
        var newFolders: [Folder] = []
        for folder in selectedFolders where !folders.contains(where: { $0.path == folder.path }) {
            let hasVenomfiles = await Task.detached(priority: .userInitiated) {
                Folder.checkHasVenomfiles(path: folder.path, bookmarkData: folder.bookmarkData)
            }.value
            var newFolder = folder
            newFolder.hasVenomfiles = hasVenomfiles
            newFolders.append(newFolder)
        }
        folders.append(contentsOf: newFolders)
    }

    func handleDroppedFolders(_ droppedFolders: [Folder]) async {
        await addSelectedFolders(droppedFolders)
    }

    func saveFoldersToWorkspace(authManager: AuthorizationManager) async {
        guard let workspace = selectedWorkspace else { return }

        let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
        guard authorized else { return }

        do {
            try saveVirtualWorkspace(workspace)
        } catch {
            print("Failed to save workspace: \(error)")
        }
    }

    func refreshAllVenomfilesStatus(authManager: AuthorizationManager) async {
        isRefreshingVenomfiles = true
        defer { isRefreshingVenomfiles = false }

        let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
        guard authorized else { return }

        func checkAndCacheVenomfiles(path: String, bookmarkData: Data?) -> Bool {
            let result = Folder.checkHasVenomfiles(path: path, bookmarkData: bookmarkData)
            UserDefaults.standard.set(result, forKey: "hasVenomfiles_\(path)")
            return result
        }

        for i in 0..<folders.count {
            folders[i].hasVenomfiles = checkAndCacheVenomfiles(
                path: folders[i].path,
                bookmarkData: folders[i].bookmarkData
            )
        }

        for workspace in workspaces where workspace.id != selectedWorkspace?.id {
            do {
                let workspaceFile = try VirtualWorkspaceFile.parse(fromDirectory: URL(fileURLWithPath: workspace.filePath))
                for folder in workspaceFile.toFolders() {
                    _ = checkAndCacheVenomfiles(path: folder.path, bookmarkData: folder.bookmarkData)
                }
            } catch {
                print("Failed to refresh Venomfiles for workspace \(workspace.name): \(error)")
            }
        }
    }

    private func folders(from urls: [URL]) async -> [Folder] {
        var newFolders: [Folder] = []

        for folderURL in urls {
            let folderPath = folderURL.path
            guard !folders.contains(where: { $0.path == folderPath }) else { continue }

            var bookmarkData: Data?
            do {
                bookmarkData = try folderURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                print("Failed to create bookmark for \(folderPath): \(error)")
            }

            let hasVenomfiles = await Task.detached(priority: .userInitiated) {
                Folder.checkHasVenomfiles(path: folderPath, bookmarkData: bookmarkData)
            }.value

            newFolders.append(Folder(
                name: folderURL.lastPathComponent,
                path: folderPath,
                displayName: nil,
                bookmarkData: bookmarkData,
                hasVenomfiles: hasVenomfiles
            ))
        }

        return newFolders
    }

    private func saveVirtualWorkspace(_ workspace: Workspace) throws {
        Self.logger.debug("saveVirtualWorkspace: workspace.filePath=\(workspace.filePath), folders.count=\(self.folders.count)")

        var links: [VirtualWorkspaceFile.LinkedFolder] = []
        var existingNames = Set<String>()

        for folder in folders {
            let parentFolder = URL(fileURLWithPath: folder.path).deletingLastPathComponent().lastPathComponent
            let symlinkName = SymlinkManager.resolveSymlinkName(
                preferredName: folder.name,
                parentFolder: parentFolder,
                existingNames: existingNames
            )
            existingNames.insert(symlinkName)

            if let bookmarkData = folder.bookmarkData {
                UserDefaults.standard.set(bookmarkData, forKey: "folderBookmark_\(folder.path)")
            }

            links.append(VirtualWorkspaceFile.LinkedFolder(
                originalPath: folder.path,
                symlinkName: symlinkName,
                parentFolder: parentFolder
            ))
        }

        let updatedLinks = try SymlinkManager.recreateAllSymlinks(links: links, in: workspace.filePath)
        let dirURL = URL(fileURLWithPath: workspace.filePath)
        var workspaceFile = (try? VirtualWorkspaceFile.parse(fromDirectory: dirURL))
            ?? VirtualWorkspaceFile(name: workspace.name, links: [], createdAt: Date())
        workspaceFile.links = updatedLinks
        try workspaceFile.save(toDirectory: dirURL)
    }

    private func syncWorkspaces() {
        workspaces = workspaceManager.workspaces

        guard let selectedWorkspace else { return }
        if let updated = workspaces.first(where: { $0.id == selectedWorkspace.id }) {
            self.selectedWorkspace = updated
        } else {
            self.selectedWorkspace = nil
            folders = []
        }
    }
}
