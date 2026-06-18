//
//  TerminalOpener.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/03.
//

import AppKit
import Foundation

enum TerminalApp: String, CaseIterable, Identifiable {
    case systemDefault = "system_default"
    case terminal = "Terminal"
    case iterm2 = "iTerm"
    case warp = "dev.warp.Warp"
    case warpTerminal = "Warp"
    case kitty = "net.kovidgoyal.kitty"
    case alacritty = "io.alacritty"
    case hyper = "co.zeit.hyper"
    case ghostty = "com.mitchellh.ghostty"
    case terminator = "net.sourceforge.Terminator"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .systemDefault:
            return "System Default"
        case .terminal:
            return "Terminal"
        case .iterm2:
            return "iTerm2"
        case .warp, .warpTerminal:
            return "Warp"
        case .kitty:
            return "Kitty"
        case .alacritty:
            return "Alacritty"
        case .hyper:
            return "Hyper"
        case .ghostty:
            return "Ghostty"
        case .terminator:
            return "Terminator"
        }
    }
    
    var bundleIdentifier: String? {
        switch self {
        case .systemDefault:
            return nil
        case .terminal:
            return "com.apple.Terminal"
        case .iterm2:
            return "com.googlecode.iterm2"
        case .warp:
            return "dev.warp.Warp"
        case .warpTerminal:
            return "com.warp.Warp"
        case .kitty:
            return "net.kovidgoyal.kitty"
        case .alacritty:
            return "io.alacritty"
        case .hyper:
            return "co.zeit.hyper"
        case .ghostty:
            return "com.mitchellh.ghostty"
        case .terminator:
            return "net.sourceforge.Terminator"
        }
    }
    
    /// Check if this terminal app is installed
    var isInstalled: Bool {
        guard let bundleId = bundleIdentifier else { return true } // System default is always "available"
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
}

struct TerminalOpener {
    
    /// Open a folder in the configured terminal application
    static func openFolder(_ path: String, terminalApp: TerminalApp? = nil) {
        let app = terminalApp ?? SettingsManager.shared.defaultTerminalApp
        Log.debug("Selected terminal app: \(app.displayName)", category: .terminal)
        
        switch app {
        case .systemDefault:
            Log.debug("Opening with system default", category: .terminal)
            openWithSystemDefault(path: path)
        case .terminal:
            Log.debug("Opening with Terminal", category: .terminal)
            openWithTerminal(path: path)
        case .iterm2:
            Log.debug("Opening with iTerm2", category: .terminal)
            openWithITerm2(path: path)
        case .warp, .warpTerminal:
            Log.debug("Opening with Warp", category: .terminal)
            openWithWarp(path: path)
        case .kitty:
            Log.debug("Opening with Kitty", category: .terminal)
            openWithKitty(path: path)
        case .alacritty:
            Log.debug("Opening with Alacritty", category: .terminal)
            openWithAlacritty(path: path)
        case .hyper:
            Log.debug("Opening with Hyper", category: .terminal)
            openWithHyper(path: path)
        case .ghostty:
            Log.debug("Opening with Ghostty", category: .terminal)
            openWithGhostty(path: path)
        case .terminator:
            Log.debug("Opening with Terminator", category: .terminal)
            openWithTerminator(path: path)
        }
    }

    static func runCommand(_ executable: String, arguments: [String], inFolder path: String, terminalApp: TerminalApp? = nil) {
        let command = ([executable] + arguments).map(shellEscaped).joined(separator: " ")
        let script = """
        #!/bin/zsh
        cd \(shellEscaped(path)) || exit 1
        \(command)
        """
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("shark-command-\(UUID().uuidString)")
            .appendingPathExtension("command")

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            openCommandFile(scriptURL, terminalApp: terminalApp ?? SettingsManager.shared.defaultTerminalApp)
        } catch {
            Log.error("Failed to run command in terminal: \(error)", category: .terminal)
        }
    }

    static func jumpToITermTab(tty: String) {
        let fullTTY = tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"
        jumpToITermTab(iTermSessionID: nil, tty: fullTTY)
    }

    static func jumpToITermTab(iTermSessionID: String?, tty: String?) {
        let fullTTY = tty.map { $0.hasPrefix("/dev/") ? $0 : "/dev/\($0)" } ?? ""
        let sessionID = iTermSessionID ?? ""
        let script = """
        tell application "iTerm2"
            if not running then return false
            repeat with terminalWindow in windows
                if miniaturized of terminalWindow then set miniaturized of terminalWindow to false
                repeat with terminalTab in tabs of terminalWindow
                    repeat with terminalSession in sessions of terminalTab
                        try
                            if "\(appleScriptEscaped(sessionID))" is not "" and unique ID of terminalSession is "\(appleScriptEscaped(sessionID))" then
                                try
                                    select terminalWindow
                                end try
                                select terminalTab
                                select terminalSession
                                set index of terminalWindow to 1
                                activate
                                return true
                            end if
                        end try
                        try
                            if "\(appleScriptEscaped(fullTTY))" is not "" and tty of terminalSession is "\(appleScriptEscaped(fullTTY))" then
                                try
                                    select terminalWindow
                                end try
                                select terminalTab
                                select terminalSession
                                set index of terminalWindow to 1
                                activate
                                return true
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
            activate
            return false
        end tell
        """
        runAppleScript(script, label: "iTermTTYJump")
    }

    // MARK: - Private Methods

    private static func openCommandFile(_ url: URL, terminalApp: TerminalApp) {
        guard let bundleId = terminalApp.bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            NSWorkspace.shared.open(url)
            return
        }

        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                Log.error("Failed to open command file with \(terminalApp.displayName): \(error)", category: .terminal)
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func runAppleScript(_ script: String, label: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
            let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            process.waitUntilExit()
            Log.info("[\(label)] status=\(process.terminationStatus) stdout=\(stdout.trimmingCharacters(in: .whitespacesAndNewlines)) stderr=\(stderr.trimmingCharacters(in: .whitespacesAndNewlines))", category: .terminal)
        } catch {
            Log.error("[\(label)] failed: \(error)", category: .terminal)
        }
    }

    private static func openWithSystemDefault(path: String) {
        let url = URL(fileURLWithPath: path)
        
        // Try to find the default terminal app
        if let terminalURL = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: ".command")) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [path]
            
            NSWorkspace.shared.open([url], withApplicationAt: terminalURL, configuration: configuration) { _, error in
                if let error = error {
                    Log.error("Failed to open with system default: \(error)", category: .terminal)
                    // Fallback to Terminal.app
                    openWithTerminal(path: path)
                }
            }
        } else {
            // Fallback to Terminal.app
            openWithTerminal(path: path)
        }
    }
    
    private static func openWithTerminal(path: String) {
        let script = """
        tell application "Terminal"
            if not running then
                activate
            end if
            do script "cd '\(path)'"
            activate
        end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
        
        if let error = error {
            Log.error("AppleScript error: \(error)", category: .terminal)
        }
    }
    
    private static func openWithITerm2(path: String) {
        // Use open command with iTerm2
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "iTerm2", path]
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw NSError(domain: "iTerm2Open", code: Int(task.terminationStatus), userInfo: nil)
            }
        } catch {
            Log.error("Failed to open with iTerm2: \(error)", category: .terminal)
            // Fallback to Terminal
            openWithTerminal(path: path)
        }
    }
    
    private static func openWithWarp(path: String) {
        // Warp supports opening with URL scheme or via CLI
        // First try using the 'warp' CLI command
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = [
            "-e",
            "do shell script \"cd '\(path)' && open -a Warp .\""
        ]
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw NSError(domain: "WarpOpen", code: 1, userInfo: nil)
            }
        } catch {
            Log.error("Failed to open with Warp: \(error)", category: .terminal)
            // Fallback: use 'open -a Warp' directly with the folder
            let url = URL(fileURLWithPath: path)
            if let warpAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.warp.Warp") {
                NSWorkspace.shared.open([url], withApplicationAt: warpAppURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                    // Callback not needed
                }
            } else if let warpAltURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.warp.Warp") {
                NSWorkspace.shared.open([url], withApplicationAt: warpAltURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                    // Callback not needed
                }
            } else {
                // Fallback to Terminal
                openWithTerminal(path: path)
            }
        }
    }
    
    private static func openWithKitty(path: String) {
        // Kitty uses 'kitty' command with the --directory option
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "kitty --directory '\(path)'"]
        
        do {
            try task.run()
        } catch {
            Log.error("Failed to open with Kitty: \(error)", category: .terminal)
            // Fallback to Terminal
            openWithTerminal(path: path)
        }
    }
    
    private static func openWithAlacritty(path: String) {
        // Alacritty uses '--working-directory' option
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "alacritty --working-directory '\(path)'"]
        
        do {
            try task.run()
        } catch {
            Log.error("Failed to open with Alacritty: \(error)", category: .terminal)
            // Fallback to Terminal
            openWithTerminal(path: path)
        }
    }
    
    private static func openWithHyper(path: String) {
        // Hyper opens by launching the app with a working directory
        let url = URL(fileURLWithPath: path)
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "co.zeit.hyper") else {
            Log.error("Hyper app not found", category: .terminal)
            openWithTerminal(path: path)
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = [path]
        
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
            if let error = error {
                Log.error("Failed to open with Hyper: \(error)", category: .terminal)
                // Fallback
                openWithTerminal(path: path)
            }
        }
    }
    
    private static func openWithGhostty(path: String) {
        // First try using the 'open' command with Ghostty app
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Ghostty", path]
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                return // Success
            }
        } catch {
            Log.error("Failed to open Ghostty with 'open' command: \(error)", category: .terminal)
        }
        
        // Fallback: Try using NSWorkspace directly
        let url = URL(fileURLWithPath: path)
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
                    if let error = error {
                        Log.error("Failed to open with Ghostty via NSWorkspace: \(error)", category: .terminal)
                        openWithTerminal(path: path)
                    }
                }
        } else {
            openWithTerminal(path: path)
        }
    }
    
    private static func openWithTerminator(path: String) {
        // Terminator uses Python script and supports --working-directory
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "terminator --working-directory='\(path)'"]
        
        do {
            try task.run()
        } catch {
            Log.error("Failed to open with Terminator: \(error)", category: .terminal)
            // Try using NSWorkspace
            let url = URL(fileURLWithPath: path)
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.sourceforge.Terminator") {
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = [path]
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
                    if let error = error {
                        Log.error("Failed to open with Terminator via NSWorkspace: \(error)", category: .terminal)
                        openWithTerminal(path: path)
                    }
                }
            } else {
                openWithTerminal(path: path)
            }
        }
    }
}
