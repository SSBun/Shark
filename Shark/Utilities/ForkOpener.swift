//
//  ForkOpener.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import AppKit
import Foundation

// MARK: - Fork Session Model

struct ForkFrame: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct ForkWindowData: Codable {
    var isFullScreen: Bool
    var frame: ForkFrame
    var activeTabIndex: Int
    var tabs: [String]
}

struct ForkWorkspaceData: Codable {
    var name: String
    var activeWindowIndex: Int
    var windows: [ForkWindowData]
}

struct ForkSession: Codable {
    var workspaces: [ForkWorkspaceData]
    var activeWorkspaceIndex: Int
    var lastWindowFrame: ForkFrame?
}

// MARK: - Fork Workspace Manager

struct ForkWorkspaceManager {
    private static let forkBundleID = "com.DanPristupov.Fork"

    private static var sessionURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(forkBundleID)/session.json")
    }

    private static func loadSession() -> ForkSession? {
        guard let data = try? Data(contentsOf: sessionURL) else { return nil }
        return try? JSONDecoder().decode(ForkSession.self, from: data)
    }

    private static func saveSession(_ session: ForkSession) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(session)
        try data.write(to: sessionURL, options: .atomic)
    }

    private static func isForkRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == forkBundleID }
    }

    private static func quitFork() async -> Bool {
        let script = NSAppleScript(source: "quit app \"Fork\"")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if let error {
            let errNum = error[NSAppleScript.errorNumber] as? Int ?? 0
            if errNum == -600 { return true } // not running, that's fine
            Log.error("AppleScript quit failed: \(error)", category: .workspace)
            return false
        }

        // Wait for exit (up to 3s)
        for _ in 0..<30 {
            if !isForkRunning() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    struct ForkWorkspaceResult {
        let created: Bool
    }

    @discardableResult
    static func findOrCreateAndOpen(named name: String, repoPaths: [String]) async throws -> ForkWorkspaceResult {
        // 1. Quit Fork if running
        await quitFork()

        // 2. Load or create session
        var session = loadSession() ?? ForkSession(workspaces: [], activeWorkspaceIndex: 0, lastWindowFrame: nil)

        // 3. Find or create workspace
        let created: Bool
        if let index = session.workspaces.firstIndex(where: { $0.name == name }) {
            session.activeWorkspaceIndex = index
            created = false
        } else {
            session.workspaces.append(ForkWorkspaceData(
                name: name,
                activeWindowIndex: 0,
                windows: [ForkWindowData(
                    isFullScreen: false,
                    frame: ForkFrame(x: 0, y: 0, width: 1800, height: 1125),
                    activeTabIndex: 0,
                    tabs: repoPaths
                )]
            ))
            session.activeWorkspaceIndex = session.workspaces.count - 1
            created = true
        }

        // 4. Save session
        try saveSession(session)

        // 5. Launch Fork
        let forkURL = URL(fileURLWithPath: "/Applications/Fork.app")
        NSWorkspace.shared.openApplication(at: forkURL, configuration: .init()) { _, _ in }

        return ForkWorkspaceResult(created: created)
    }
}

// MARK: - Legacy repo opener

struct ForkOpener {
    static func openRepository(at path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["fork", path]
        try? process.run()
    }
}
