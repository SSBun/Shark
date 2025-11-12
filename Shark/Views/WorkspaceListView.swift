//
//  WorkspaceListView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

struct WorkspaceListView: View {
    @Binding var workspaces: [Workspace]
    @Binding var selectedWorkspace: Workspace?
    @EnvironmentObject var authManager: AuthorizationManager
    @State private var renameWorkspace: Workspace?
    @State private var showRenameDialog = false
    @State private var lastSelectedWorkspace: Workspace?
    @State private var lastSelectionTime: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add and Import buttons
            HStack {
                Text("Workspaces")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                
                // Import button
                Button(action: {
                    importWorkspace()
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Import existing Cursor workspace file")
                
                // Add button
                Button(action: {
                    createNewWorkspace()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Create new workspace file")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 36)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Workspace list
            List(selection: $selectedWorkspace) {
                ForEach(workspaces) { workspace in
                    WorkspaceRow(
                        workspace: workspace,
                        onOpen: {
                            WorkspaceOpener.openWorkspace(workspace)
                        },
                        onShowInFinder: {
                            showWorkspaceInFinder(workspace)
                        },
                        onRename: {
                            renameWorkspace = workspace
                            showRenameDialog = true
                        },
                        onRemove: {
                            removeWorkspace(workspace)
                        }
                    )
                    .tag(workspace)
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedWorkspace) { oldValue, newValue in
                // Handle double-click detection
                if let newValue = newValue {
                    let now = Date()
                    if let lastTime = lastSelectionTime,
                       let lastSelected = lastSelectedWorkspace,
                       lastSelected.id == newValue.id,
                       now.timeIntervalSince(lastTime) < 0.5 { // Double-click threshold (500ms)
                        // Double-click detected - open workspace
                        WorkspaceOpener.openWorkspace(newValue)
                    }
                    lastSelectedWorkspace = newValue
                    lastSelectionTime = now
                }
            }
        }
        .sheet(isPresented: $showRenameDialog) {
            if let workspace = renameWorkspace {
                RenameWorkspaceView(
                    isPresented: $showRenameDialog,
                    currentName: workspace.name
                ) { newName in
                    renameWorkspace(workspace, to: newName)
                }
            }
        }
    }
    
    private func createNewWorkspace() {
        Task {
            // Check authorization before accessing file system
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }
            
            let settingsManager = SettingsManager.shared
            
            do {
                // Get the URL for the new workspace file in settings folder
                let url = try settingsManager.getNewWorkspaceURL()
                
                // Create empty workspace file
                let emptyWorkspace = CursorWorkspaceFile.createEmpty()
                try emptyWorkspace.save(to: url)
                
                // Add to workspaces list
                let filePath = url.path
                let newWorkspace = emptyWorkspace.toWorkspace(filePath: filePath)
                await MainActor.run {
                    workspaces.append(newWorkspace)
                    selectedWorkspace = newWorkspace
                    // Save workspace list
                    WorkspaceManager.shared.addWorkspace(newWorkspace)
                }
            } catch {
                // TODO: Show error alert
                print("Failed to create workspace file: \(error)")
            }
        }
    }
    
    private func importWorkspace() {
        Task {
            // Check authorization before accessing file system
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }
            
            guard let url = FileDialogHelper.selectWorkspaceFile() else {
                return
            }
            
            do {
                let workspaceFile = try CursorWorkspaceFile.parse(from: url)
                let filePath = url.path
                let workspace = workspaceFile.toWorkspace(filePath: filePath)
                
                // Check if workspace already exists
                await MainActor.run {
                    if workspaces.contains(where: { $0.filePath == workspace.filePath }) {
                        // TODO: Show alert that workspace already exists
                        return
                    }
                    
                    workspaces.append(workspace)
                    selectedWorkspace = workspace
                    // Save workspace list
                    WorkspaceManager.shared.addWorkspace(workspace)
                }
            } catch {
                // TODO: Show error alert
                print("Failed to import workspace file: \(error)")
            }
        }
    }
    
    private func renameWorkspace(_ workspace: Workspace, to newName: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else {
            return
        }
        
        // Update workspace name
        workspaces[index].name = newName
        
        // Update in WorkspaceManager
        WorkspaceManager.shared.updateWorkspace(workspaces[index])
        
        // If this is the selected workspace, update the selection
        if selectedWorkspace?.id == workspace.id {
            selectedWorkspace = workspaces[index]
        }
    }
    
    private func showWorkspaceInFinder(_ workspace: Workspace) {
        let fileURL = URL(fileURLWithPath: workspace.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
    
    private func removeWorkspace(_ workspace: Workspace) {
        Task {
            // Remove from list
            workspaces.removeAll { $0.id == workspace.id }
            WorkspaceManager.shared.removeWorkspace(workspace)
            
            // Clear selection if this was the selected workspace
            if selectedWorkspace?.id == workspace.id {
                selectedWorkspace = nil
            }
            
            // Optionally delete the workspace file from disk if it's in the settings folder
            let settingsManager = SettingsManager.shared
            let settingsFolderPath = settingsManager.settingsFolderPath
            
            if workspace.filePath.hasPrefix(settingsFolderPath) {
                // Only delete if it's in the settings folder (user-created workspaces)
                do {
                    try FileManager.default.removeItem(atPath: workspace.filePath)
                } catch {
                    // File might not exist or can't be deleted - that's okay
                    print("Could not delete workspace file: \(error)")
                }
            }
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    let onOpen: () -> Void
    let onShowInFinder: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.name)
                    .font(.system(size: 14, weight: .medium))
                Text(workspace.filePath)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Open button on the right
            Button(action: onOpen) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1.0 : 0.6)
            .help("Open workspace in Cursor")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: onShowInFinder) {
                Label("Show in Finder", systemImage: "folder")
            }
            
            Divider()
            
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

#Preview {
    @Previewable @State var workspaces: [Workspace] = []
    @Previewable @State var selectedWorkspace: Workspace? = nil
    
    WorkspaceListView(workspaces: $workspaces, selectedWorkspace: $selectedWorkspace)
        .environmentObject(AuthorizationManager.shared)
        .frame(width: 300, height: 600)
}

