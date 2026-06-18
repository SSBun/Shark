//
//  WorkspaceOpener.swift
//  Shark
//

import AppKit
import Foundation

struct WorkspaceOpener {
    static func openWorkspace(_ workspace: Workspace) {
        guard FileManager.default.fileExists(atPath: workspace.filePath) else {
            Log.debug("Workspace directory does not exist: \(workspace.filePath)", category: .workspace)
            return
        }

        TerminalOpener.openFolder(workspace.filePath)
    }
}
