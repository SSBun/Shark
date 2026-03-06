//
//  SourceTreeOpener.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import Foundation

struct SourceTreeOpener {
    /// Open a git repository in SourceTree
    static func openRepository(at path: String) {
        // Check if folder exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("Repository path does not exist: \(path)")
            return
        }

        // Try common SourceTree installation paths
        let possiblePaths = [
            "/Applications/SourceTree.app",
            "/Applications/Sourcetree.app",
            "/System/Applications/SourceTree.app",
            "/System/Applications/Sourcetree.app"
        ]

        var sourceTreePath: String?
        for possiblePath in possiblePaths {
            if FileManager.default.fileExists(atPath: possiblePath) {
                sourceTreePath = possiblePath
                break
            }
        }

        // Try using 'stree' command line tool if available
        let streePaths = ["/usr/local/bin/stree", "/opt/homebrew/bin/stree"]
        for streePath in streePaths {
            if FileManager.default.fileExists(atPath: streePath) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: streePath)
                process.arguments = ["open", path]
                do {
                    try process.run()
                    return
                } catch {
                    print("Failed to open with stree: \(error)")
                }
            }
        }

        // Fallback: open the app directly with the path
        if let appPath = sourceTreePath {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", appPath, path]
            do {
                try process.run()
            } catch {
                print("Failed to open repository with SourceTree: \(error)")
            }
        } else {
            print("SourceTree not found")
        }
    }
}
