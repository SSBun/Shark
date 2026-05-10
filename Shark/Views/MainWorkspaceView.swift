//
//  MainWorkspaceView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI

struct MainWorkspaceView: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @State private var selectedWorkspace: Workspace? = nil
    @State private var folders: [Folder] = []
    @State private var isLoadingFolders = false
    @State private var showComponentSelector = false
    @State private var isRefreshingVenomfiles = false
    @EnvironmentObject var authManager: AuthorizationManager

    private var workspaces: Binding<[Workspace]> {
        Binding(
            get: { workspaceManager.workspaces },
            set: { workspaceManager.workspaces = $0; workspaceManager.saveWorkspaces() }
        )
    }

    var body: some View {
        HSplitView {
            // Left area: Workspace list
            WorkspaceListView(
                workspaces: workspaces,
                selectedWorkspace: $selectedWorkspace,
                isRefreshingVenomfiles: $isRefreshingVenomfiles,
                onRefreshAllVenomfiles: { refreshAllVenomfilesStatus() }
            )
            .environmentObject(authManager)
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)

            // Right area: Folder list
            FolderListView(
                folders: $folders,
                onAddFolder: {
                    addFolder()
                },
                onUpdateFolder: { _ in
                    saveFoldersToWorkspace()
                },
                onSelectComponents: {
                    showComponentSelector = true
                },
                onDropFolders: { droppedFolders in
                    handleDroppedFolders(droppedFolders)
                }
            )
            .frame(minWidth: 250, idealWidth: 300)
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showComponentSelector) {
            ComponentSelectorView(
                searchPath: SettingsManager.shared.componentsSearchPath,
                onAdd: { selectedFolders in
                    addSelectedFolders(selectedFolders)
                }
            )
        }
        .onChange(of: selectedWorkspace) { oldValue, newValue in
            loadFoldersForWorkspace(newValue)
        }
        .onChange(of: folders) { oldValue, newValue in
            if !isLoadingFolders {
                saveFoldersToWorkspace()
            }
        }
        .onAppear {
            workspaceManager.refreshWorkspaces()
            loadFoldersForWorkspace(selectedWorkspace)
        }
        .onChange(of: workspaceManager.workspaces) { oldValue, newValue in
            if let selected = selectedWorkspace,
               !newValue.contains(where: { $0.id == selected.id }) {
                selectedWorkspace = nil
            }
        }
    }

    private func loadFoldersForWorkspace(_ workspace: Workspace?) {
        guard let workspace = workspace else {
            folders = []
            return
        }

        isLoadingFolders = true

        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                await MainActor.run {
                    folders = []
                    isLoadingFolders = false
                }
                return
            }

            do {
                if workspace.type == .claude {
                    let dirURL = URL(fileURLWithPath: workspace.filePath)
                    let claudeFile = try ClaudeWorkspaceFile.parse(fromDirectory: dirURL)
                    await MainActor.run {
                        folders = claudeFile.toFolders()
                        isLoadingFolders = false
                    }
                } else {
                    let fileURL = URL(fileURLWithPath: workspace.filePath)
                    let workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                    await MainActor.run {
                        folders = workspaceFile.toFolders()
                        isLoadingFolders = false
                    }
                }
            } catch {
                await MainActor.run {
                    folders = []
                    isLoadingFolders = false
                }
            }
        }
    }

    private func addFolder() {
        guard selectedWorkspace != nil else {
            return
        }

        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }

            let selectedURLs = FileDialogHelper.selectFolders()
            guard !selectedURLs.isEmpty else {
                return
            }

            var newFolders: [Folder] = []

            for folderURL in selectedURLs {
                let folderPath = folderURL.path
                let folderName = folderURL.lastPathComponent

                var bookmarkData: Data? = nil
                do {
                    bookmarkData = try folderURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } catch {
                    print("Failed to create bookmark for \(folderPath): \(error)")
                }

                if folders.contains(where: { $0.path == folderPath }) {
                    continue
                }

                let hasVenomfiles = await Task.detached(priority: .userInitiated) {
                    Folder.checkHasVenomfiles(path: folderPath, bookmarkData: bookmarkData)
                }.value

                let newFolder = Folder(
                    name: folderName,
                    path: folderPath,
                    displayName: nil,
                    bookmarkData: bookmarkData,
                    hasVenomfiles: hasVenomfiles
                )

                newFolders.append(newFolder)
            }

            await MainActor.run {
                folders.append(contentsOf: newFolders)
            }
        }
    }

    private func addSelectedFolders(_ selectedFolders: [Folder]) {
        guard selectedWorkspace != nil else { return }

        Task {
            var newFolders: [Folder] = []
            for folder in selectedFolders {
                if !folders.contains(where: { $0.path == folder.path }) {
                    let hasVenomfiles = await Task.detached(priority: .userInitiated) {
                        Folder.checkHasVenomfiles(path: folder.path, bookmarkData: folder.bookmarkData)
                    }.value
                    var newFolder = folder
                    newFolder.hasVenomfiles = hasVenomfiles
                    newFolders.append(newFolder)
                }
            }

            await MainActor.run {
                folders.append(contentsOf: newFolders)
            }
        }
    }

    private func handleDroppedFolders(_ droppedFolders: [Folder]) {
        guard selectedWorkspace != nil else { return }

        Task {
            var newFolders: [Folder] = []
            for folder in droppedFolders {
                if !folders.contains(where: { $0.path == folder.path }) {
                    let hasVenomfiles = await Task.detached(priority: .userInitiated) {
                        Folder.checkHasVenomfiles(path: folder.path, bookmarkData: folder.bookmarkData)
                    }.value
                    var newFolder = folder
                    newFolder.hasVenomfiles = hasVenomfiles
                    newFolders.append(newFolder)
                }
            }

            if !newFolders.isEmpty {
                await MainActor.run {
                    folders.append(contentsOf: newFolders)
                }
            }
        }
    }

    private func saveFoldersToWorkspace() {
        guard let workspace = selectedWorkspace else {
            return
        }

        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }

            do {
                if workspace.type == .claude {
                    try saveClaudeWorkspace(workspace)
                } else {
                    try saveCursorWorkspace(workspace)
                }
            } catch {
                print("Failed to save workspace: \(error)")
            }
        }
    }

    private func saveCursorWorkspace(_ workspace: Workspace) throws {
        let fileURL = URL(fileURLWithPath: workspace.filePath)

        var workspaceFile: CursorWorkspaceFile
        if FileManager.default.fileExists(atPath: workspace.filePath) {
            workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
        } else {
            workspaceFile = CursorWorkspaceFile.createEmpty()
        }

        workspaceFile.updateFolders(from: folders)
        try workspaceFile.save(to: fileURL)
    }

    private func saveClaudeWorkspace(_ workspace: Workspace) throws {
        let dirURL = URL(fileURLWithPath: workspace.filePath)

        // Build links from current folders
        var links: [ClaudeWorkspaceFile.LinkedFolder] = []
        var existingNames = Set<String>()

        for folder in folders {
            let preferredName = folder.name
            let parentFolder = URL(fileURLWithPath: folder.path).deletingLastPathComponent().lastPathComponent

            let symlinkName = SymlinkManager.resolveSymlinkName(
                preferredName: preferredName,
                parentFolder: parentFolder,
                existingNames: existingNames
            )
            existingNames.insert(symlinkName)

            // Store bookmark data
            if let bookmarkData = folder.bookmarkData {
                let bookmarkKey = "folderBookmark_\(folder.path)"
                UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            }

            links.append(ClaudeWorkspaceFile.LinkedFolder(
                originalPath: folder.path,
                symlinkName: symlinkName,
                parentFolder: parentFolder
            ))
        }

        // Recreate symlinks on disk
        let updatedLinks = try SymlinkManager.recreateAllSymlinks(links: links, in: workspace.filePath)

        // Save metadata
        let metadataURL = dirURL.appendingPathComponent(ClaudeWorkspaceFile.metadataFileName)
        var claudeFile: ClaudeWorkspaceFile
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            claudeFile = try ClaudeWorkspaceFile.parse(from: metadataURL)
            claudeFile.links = updatedLinks
        } else {
            claudeFile = ClaudeWorkspaceFile(name: workspace.name, links: updatedLinks, createdAt: Date())
        }
        try claudeFile.save(to: metadataURL)
    }

    private func refreshAllVenomfilesStatus() {
        isRefreshingVenomfiles = true

        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                await MainActor.run {
                    isRefreshingVenomfiles = false
                }
                return
            }

            func checkAndCacheVenomfiles(path: String, bookmarkData: Data?) -> Bool {
                let result = Folder.checkHasVenomfiles(path: path, bookmarkData: bookmarkData)
                let venomfilesKey = "hasVenomfiles_\(path)"
                UserDefaults.standard.set(result, forKey: venomfilesKey)
                return result
            }

            // Refresh for current workspace's folders
            await MainActor.run {
                for i in 0..<folders.count {
                    folders[i].hasVenomfiles = checkAndCacheVenomfiles(
                        path: folders[i].path,
                        bookmarkData: folders[i].bookmarkData
                    )
                }
                isRefreshingVenomfiles = false
            }

            // Also refresh for all other workspaces
            for workspace in workspaceManager.workspaces {
                if workspace.id == selectedWorkspace?.id {
                    continue
                }

                do {
                    let otherFolders: [Folder]
                    if workspace.type == .claude {
                        let dirURL = URL(fileURLWithPath: workspace.filePath)
                        let claudeFile = try ClaudeWorkspaceFile.parse(fromDirectory: dirURL)
                        otherFolders = claudeFile.toFolders()
                    } else {
                        let fileURL = URL(fileURLWithPath: workspace.filePath)
                        var workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                        otherFolders = workspaceFile.toFolders()
                    }

                    var updatedFolders = otherFolders
                    for i in 0..<updatedFolders.count {
                        updatedFolders[i].hasVenomfiles = checkAndCacheVenomfiles(
                            path: updatedFolders[i].path,
                            bookmarkData: updatedFolders[i].bookmarkData
                        )
                    }

                    // Save updated status back to workspace file
                    if workspace.type == .cursor {
                        let fileURL = URL(fileURLWithPath: workspace.filePath)
                        var workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                        workspaceFile.updateFolders(from: updatedFolders)
                        try workspaceFile.save(to: fileURL)
                    }
                    // Claude workspaces: bookmarks are already cached in UserDefaults
                } catch {
                    print("Failed to refresh Venomfiles for workspace \(workspace.name): \(error)")
                }
            }
        }
    }
}

#Preview {
    MainWorkspaceView()
        .environmentObject(AuthorizationManager.shared)
        .frame(width: 800, height: 600)
}
