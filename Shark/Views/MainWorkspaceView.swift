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
                selectedWorkspace: $selectedWorkspace
            )
            .environmentObject(authManager)
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
            
            // Right area: Folder list
            FolderListView(folders: $folders, onAddFolder: {
                addFolder()
            })
            .frame(minWidth: 250, idealWidth: 300)
        }
        .frame(minWidth: 500, minHeight: 400)
        .onChange(of: selectedWorkspace) { oldValue, newValue in
            // Update folders when workspace selection changes
            loadFoldersForWorkspace(newValue)
        }
        .onChange(of: folders) { oldValue, newValue in
            // Save workspace file when folders change (but not during initial load)
            if !isLoadingFolders {
                saveFoldersToWorkspace()
            }
        }
        .onAppear {
            // Refresh workspaces from disk on appear
            workspaceManager.refreshWorkspaces()
            // Initialize folders if a workspace is already selected
            loadFoldersForWorkspace(selectedWorkspace)
        }
        .onChange(of: workspaceManager.workspaces) { oldValue, newValue in
            // If selected workspace was removed, clear selection
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
                let fileURL = URL(fileURLWithPath: workspace.filePath)
                let workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                await MainActor.run {
                    folders = workspaceFile.toFolders()
                    isLoadingFolders = false
                }
            } catch {
                // If file doesn't exist or can't be parsed, show empty folders
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
                
                // Check if folder already exists
                if folders.contains(where: { $0.path == folderPath }) {
                    // Skip duplicate folders
                    continue
                }
                
                let newFolder = Folder(
                    name: folderName,
                    path: folderPath,
                    displayName: nil
                )
                
                newFolders.append(newFolder)
            }
            
            await MainActor.run {
                folders.append(contentsOf: newFolders)
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
                let fileURL = URL(fileURLWithPath: workspace.filePath)
                
                // Load existing workspace file or create new one
                var workspaceFile: CursorWorkspaceFile
                if FileManager.default.fileExists(atPath: workspace.filePath) {
                    workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                } else {
                    workspaceFile = CursorWorkspaceFile.createEmpty()
                }
                
                // Update folders
                workspaceFile.updateFolders(from: folders)
                
                // Save workspace file
                try workspaceFile.save(to: fileURL)
            } catch {
                // TODO: Show error alert
                print("Failed to save workspace file: \(error)")
            }
        }
    }
}

#Preview {
    MainWorkspaceView()
        .environmentObject(AuthorizationManager.shared)
        .frame(width: 800, height: 600)
}

