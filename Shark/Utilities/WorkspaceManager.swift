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
            
            guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: []) else {
                return
            }
            
            var foundWorkspaces: [Workspace] = []
            
            for fileURL in files {
                guard fileURL.pathExtension == "code-workspace" else { continue }
                
                do {
                    let workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                    let workspace = workspaceFile.toWorkspace(filePath: fileURL.path)
                    
                    // Get file creation date
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let creationDate = attributes[.creationDate] as? Date ?? Date()
                    
                    var workspaceWithDate = workspace
                    // Create a new workspace with the creation date
                    foundWorkspaces.append(Workspace(
                        id: workspace.id,
                        name: workspace.name,
                        filePath: workspace.filePath,
                        createdAt: creationDate
                    ))
                } catch {
                    // Skip invalid workspace files
                    continue
                }
            }
            
            workspaces = foundWorkspaces.sorted { $0.createdAt > $1.createdAt }
            saveWorkspaces()
        } catch {
            // Settings folder doesn't exist or can't be accessed
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
    
    /// Rename a workspace and its corresponding file on disk
    func renameWorkspace(_ workspace: Workspace, to newName: String) throws -> Workspace {
        let oldURL = URL(fileURLWithPath: workspace.filePath)
        let folderURL = oldURL.deletingLastPathComponent()
        let newURL = folderURL.appendingPathComponent("\(newName).code-workspace")
        
        // If the filename is already correct, just update the name in the model
        if oldURL.path == newURL.path {
            var updatedWorkspace = workspace
            updatedWorkspace.name = newName
            updateWorkspace(updatedWorkspace)
            return updatedWorkspace
        }
        
        // Check if destination already exists
        if FileManager.default.fileExists(atPath: newURL.path) {
            // If it exists, we might want to generate a unique name or throw error
            // For now, let's throw an error to be safe
            throw NSError(domain: "WorkspaceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "A workspace file with this name already exists."])
        }
        
        // Perform the file rename
        try FileManager.default.moveItem(at: oldURL, to: newURL)
        
        // Update the workspace model with new name and path
        var updatedWorkspace = workspace
        updatedWorkspace.name = newName
        updatedWorkspace.filePath = newURL.path
        
        updateWorkspace(updatedWorkspace)
        return updatedWorkspace
    }
    
    /// Refresh workspaces from disk
    func refreshWorkspaces() {
        // Clear existing workspaces before scanning the new folder
        workspaces = []
        
        // Merge scanned workspaces with existing ones
        var scannedWorkspaces: [Workspace] = []
        
        do {
            let folderURL = try settingsManager.getSettingsFolderURL()
            let fileManager = FileManager.default
            
            guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: []) else {
                return
            }
            
            for fileURL in files {
                guard fileURL.pathExtension == "code-workspace" else { continue }
                
                do {
                    let workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                    let workspace = workspaceFile.toWorkspace(filePath: fileURL.path)
                    
                    // Get file creation date
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let creationDate = attributes[.creationDate] as? Date ?? Date()
                    
                    scannedWorkspaces.append(Workspace(
                        id: workspace.id,
                        name: workspace.name,
                        filePath: workspace.filePath,
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
                mergedWorkspaces.append(scanned)
            }
        }
        
        // Remove workspaces that no longer exist on disk (if they were in settings folder)
        let settingsFolderPath = settingsManager.settingsFolderPath
        mergedWorkspaces = mergedWorkspaces.filter { workspace in
            // Keep if file exists OR if it's not in settings folder (imported workspaces)
            if FileManager.default.fileExists(atPath: workspace.filePath) {
                return true
            }
            // Remove if it was in settings folder but file is gone
            return !workspace.filePath.hasPrefix(settingsFolderPath)
        }
        
        workspaces = mergedWorkspaces.sorted { $0.createdAt > $1.createdAt }
        saveWorkspaces()
    }
}

