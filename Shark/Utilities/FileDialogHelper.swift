//
//  FileDialogHelper.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import SwiftUI

struct FileDialogHelper {
    /// Open a file picker to select a .code-workspace file
    static func selectWorkspaceFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Import Cursor Workspace File"
        panel.message = "Select a .code-workspace file to import"
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
    
    /// Open a save dialog to create a new workspace file
    static func saveWorkspaceFile(defaultName: String = "workspace") -> URL? {
        let panel = NSSavePanel()
        // Use JSON content type, but we'll enforce .code-workspace extension
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(defaultName).code-workspace"
        panel.title = "Create New Workspace File"
        panel.message = "Choose where to save the new workspace file"
        // Allow all file types since .code-workspace is not a standard UTType
        panel.allowsOtherFileTypes = true
        
        if panel.runModal() == .OK {
            guard var url = panel.url else { return nil }
            // Ensure .code-workspace extension
            if url.pathExtension != "code-workspace" {
                url = url.deletingPathExtension().appendingPathExtension("code-workspace")
            }
            return url
        }
        return nil
    }
    
    /// Open a folder picker to select a folder
    static func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.title = "Select Folder"
        panel.message = "Choose a folder to add to the workspace"
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
    
    /// Open a folder picker to select multiple folders
    static func selectFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.title = "Select Folders"
        panel.message = "Choose folders to add to the workspace"
        
        if panel.runModal() == .OK {
            return panel.urls
        }
        return []
    }
}

