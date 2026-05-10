//
//  WorkspaceOpener.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import Foundation

struct WorkspaceOpener {
    /// Open a workspace with the configured IDE or terminal
    static func openWorkspace(_ workspace: Workspace, ide: IDEApp? = nil) {
        switch workspace.type {
        case .cursor:
            openCursorWorkspace(workspace, ide: ide)
        case .claude:
            openClaudeWorkspace(workspace)
        }
    }

    // MARK: - Cursor

    private static func openCursorWorkspace(_ workspace: Workspace, ide: IDEApp? = nil) {
        let fileURL = URL(fileURLWithPath: workspace.filePath)

        guard FileManager.default.fileExists(atPath: workspace.filePath) else {
            Log.debug("Workspace file does not exist: \(workspace.filePath)", category: .workspace)
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

    private static func openWithCursor(fileURL: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Cursor", fileURL.path]

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                Log.error("Failed to open workspace with Cursor (exit code: \(task.terminationStatus))", category: .workspace)
                NSWorkspace.shared.open(fileURL)
            }
        } catch {
            Log.error("Failed to open workspace with Cursor: \(error)", category: .workspace)
            NSWorkspace.shared.open(fileURL)
        }
    }

    private static func openWithTrae(fileURL: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Trae", fileURL.path]

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                Log.error("Failed to open workspace with Trae (exit code: \(task.terminationStatus))", category: .workspace)
                NSWorkspace.shared.open(fileURL)
            }
        } catch {
            Log.error("Failed to open workspace with Trae: \(error)", category: .workspace)
            NSWorkspace.shared.open(fileURL)
        }
    }

    // MARK: - Claude

    private static func openClaudeWorkspace(_ workspace: Workspace) {
        guard FileManager.default.fileExists(atPath: workspace.filePath) else {
            Log.debug("Claude workspace directory does not exist: \(workspace.filePath)", category: .workspace)
            return
        }

        let terminalApp = SettingsManager.shared.defaultTerminalApp

        // Use NSWorkspace to open the folder with the selected terminal app
        if let bundleId = terminalApp.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let folderURL = URL(fileURLWithPath: workspace.filePath)
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = [workspace.filePath]
            NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: config) { _, error in
                if let error = error {
                    Log.error("Failed to open \(terminalApp.displayName): \(error)", category: .workspace)
                    // Fallback to TerminalOpener
                    TerminalOpener.openFolder(workspace.filePath)
                }
            }
        } else {
            // System default or unknown — use TerminalOpener
            TerminalOpener.openFolder(workspace.filePath)
        }
    }
}
