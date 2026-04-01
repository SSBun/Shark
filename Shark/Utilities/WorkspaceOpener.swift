//
//  WorkspaceOpener.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import Foundation

struct WorkspaceOpener {
    /// Open a workspace file with the configured IDE
    static func openWorkspace(_ workspace: Workspace, ide: IDEApp? = nil) {
        let fileURL = URL(fileURLWithPath: workspace.filePath)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: workspace.filePath) else {
            print("Workspace file does not exist: \(workspace.filePath)")
            return
        }

        let selectedIDE = ide ?? SettingsManager.shared.defaultIDEApp
        Log.debug("Opening workspace with IDE: \(selectedIDE.displayName)", category: .workspace)

        switch selectedIDE {
        case .cursor:
            openWithCursor(fileURL: fileURL)
        case .trae:
            openWithTrae(fileURL: fileURL)
        }
    }

    // MARK: - Private Methods

    private static func openWithCursor(fileURL: URL) {
        // Use command line to open with Cursor so it properly loads the workspace
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Cursor", fileURL.path]

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                Log.error("Failed to open workspace with Cursor (exit code: \(task.terminationStatus))", category: .workspace)
                // Fallback to opening with default app
                NSWorkspace.shared.open(fileURL)
            }
        } catch {
            Log.error("Failed to open workspace with Cursor: \(error)", category: .workspace)
            // Fallback to opening with default app
            NSWorkspace.shared.open(fileURL)
        }
    }

    private static func openWithTrae(fileURL: URL) {
        // Try using command line first for Trae
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Trae", fileURL.path]

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                Log.error("Failed to open workspace with Trae (exit code: \(task.terminationStatus))", category: .workspace)
                // Fallback to opening with default app
                NSWorkspace.shared.open(fileURL)
            }
        } catch {
            Log.error("Failed to open workspace with Trae: \(error)", category: .workspace)
            // Fallback to opening with default app
            NSWorkspace.shared.open(fileURL)
        }
    }
}

