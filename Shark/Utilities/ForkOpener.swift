//
//  ForkOpener.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import Foundation

struct ForkOpener {
    /// Open a git repository in Fork using the command line tool
    static func openRepository(at path: String) {
        // Check if folder exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("Repository path does not exist: \(path)")
            return
        }
        
        // Execute 'fork project_path' command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/fork")
        process.arguments = [path]
        
        // Alternative: try /opt/homebrew/bin/fork for Apple Silicon Macs
        if !FileManager.default.fileExists(atPath: "/usr/local/bin/fork") {
            if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/fork") {
                process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/fork")
            } else {
                // Try to find fork in PATH
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["fork", path]
            }
        }
        
        do {
            try process.run()
        } catch {
            print("Failed to open repository with Fork: \(error)")
            // TODO: Show error alert
        }
    }
}

