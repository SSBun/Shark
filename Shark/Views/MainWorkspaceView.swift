//
//  MainWorkspaceView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import os

struct MainWorkspaceView: View {
    private static let logger = Logger(subsystem: "com.shark.app", category: "MainWorkspaceView")
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
                searchPaths: SettingsManager.shared.componentsSearchPaths,
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
                let dirURL = URL(fileURLWithPath: workspace.filePath)
                let workspaceFile = try VirtualWorkspaceFile.parse(fromDirectory: dirURL)
                await MainActor.run {
                    folders = workspaceFile.toFolders()
                    isLoadingFolders = false
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
                try saveVirtualWorkspace(workspace)
            } catch {
                print("Failed to save workspace: \(error)")
            }
        }
    }

    private func saveVirtualWorkspace(_ workspace: Workspace) throws {
        Self.logger.debug("saveVirtualWorkspace: workspace.filePath=\(workspace.filePath), folders.count=\(folders.count)")
        let dirURL = URL(fileURLWithPath: workspace.filePath)

        // Build links from current folders
        var links: [VirtualWorkspaceFile.LinkedFolder] = []
        var existingNames = Set<String>()

        for folder in folders {
            let preferredName = folder.name
            let parentFolder = URL(fileURLWithPath: folder.path).deletingLastPathComponent().lastPathComponent
            Self.logger.debug("saveVirtualWorkspace: folder name=\(folder.name), path=\(folder.path), preferredName=\(preferredName), parentFolder=\(parentFolder)")

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

            links.append(VirtualWorkspaceFile.LinkedFolder(
                originalPath: folder.path,
                symlinkName: symlinkName,
                parentFolder: parentFolder
            ))
            Self.logger.debug("saveVirtualWorkspace: resolved symlinkName=\(symlinkName)")
        }

        // Recreate symlinks on disk
        Self.logger.debug("saveVirtualWorkspace: recreating \(links.count) symlinks in \(workspace.filePath)")
        let updatedLinks = try SymlinkManager.recreateAllSymlinks(links: links, in: workspace.filePath)
        Self.logger.info("saveVirtualWorkspace: created \(updatedLinks.count) symlinks")

        // Save metadata
        let metadataURL = dirURL.appendingPathComponent(VirtualWorkspaceFile.metadataFileName)
        var workspaceFile: VirtualWorkspaceFile
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            workspaceFile = try VirtualWorkspaceFile.parse(from: metadataURL)
            workspaceFile.links = updatedLinks
        } else {
            workspaceFile = VirtualWorkspaceFile(name: workspace.name, links: updatedLinks, createdAt: Date())
        }
        try workspaceFile.save(to: metadataURL)
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
                    let dirURL = URL(fileURLWithPath: workspace.filePath)
                    let workspaceFile = try VirtualWorkspaceFile.parse(fromDirectory: dirURL)
                    otherFolders = workspaceFile.toFolders()

                    var updatedFolders = otherFolders
                    for i in 0..<updatedFolders.count {
                        updatedFolders[i].hasVenomfiles = checkAndCacheVenomfiles(
                            path: updatedFolders[i].path,
                            bookmarkData: updatedFolders[i].bookmarkData
                        )
                    }

                    // Virtual workspaces store Venomfiles status in UserDefaults.
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
