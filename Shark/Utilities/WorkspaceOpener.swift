//
//  WorkspaceOpener.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import Foundation

struct WorkspaceOpener {
    /// Open a workspace file with Cursor
    static func openWorkspace(_ workspace: Workspace) {
        let fileURL = URL(fileURLWithPath: workspace.filePath)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: workspace.filePath) else {
            print("Workspace file does not exist: \(workspace.filePath)")
            // TODO: Show error alert
            return
        }
        
        // Try to open with Cursor
        // Cursor's bundle identifier is typically "com.todesktop.230313mzl4w4u92"
        // But we can also try opening with the default app for .code-workspace files
        let cursorBundleID = "com.todesktop.230313mzl4w4u92"
        
        // First, try to open with Cursor specifically
        if let cursorApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: cursorBundleID) {
            do {
                try NSWorkspace.shared.open([fileURL], withApplicationAt: cursorApp, configuration: NSWorkspace.OpenConfiguration())
            } catch {
                print("Failed to open workspace with Cursor: \(error)")
                // Fallback to opening with default app
                NSWorkspace.shared.open(fileURL)
            }
        } else {
            // Cursor not found, try opening with default app for .code-workspace files
            NSWorkspace.shared.open(fileURL)
        }
    }
}

