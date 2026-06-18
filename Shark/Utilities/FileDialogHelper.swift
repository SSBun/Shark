//
//  FileDialogHelper.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import SwiftUI

struct FileDialogHelper {
    /// Open a folder picker to select a folder
    static func selectFolder(title: String = "Select Folder", message: String = "Choose a folder", initialPath: String? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.title = title
        panel.message = message
        
        if let initialPath = initialPath {
            panel.directoryURL = URL(fileURLWithPath: initialPath)
        }
        
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
