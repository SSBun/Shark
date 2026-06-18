//
//  CodexSessionRuntimeDetector.swift
//  Shark
//

import Foundation

enum CodexSessionRuntimeDetector {
    static func terminalStates() -> [String: CodexSessionRuntimeState] {
        let rows = psRows()
        Log.info("[CodexRuntime] scanning terminal states, processRows=\(rows.count)", category: .terminal)

        var states = hookStates()
        for row in rows {
            guard row.tty != "??", row.command.contains("codex") else { continue }
            for sessionID in sessionIDs(openedBy: row.pid) {
                Log.info("[CodexRuntime] found running session id=\(sessionID) pid=\(row.pid) tty=\(row.tty)", category: .terminal)
                let existingITermID = states[sessionID]?.iTermSessionID
                states[sessionID] = .runningInTerminal(tty: row.tty, pid: row.pid, iTermSessionID: existingITermID)
            }
        }
        Log.info("[CodexRuntime] terminal states found=\(states.count)", category: .terminal)
        return states
    }

    private struct HookSnapshot: Decodable {
        let sessionID: String
        let active: Bool
        let tty: String?
        let pid: Int32?
        let iTermSessionID: String?
    }

    private struct ProcessRow {
        let pid: Int32
        let tty: String
        let command: String
    }

    private static func psRows() -> [ProcessRow] {
        guard let output = commandOutput("/bin/ps", arguments: ["-axo", "pid=,tt=,command="]) else { return [] }

        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = Int32(parts[0]) else { return nil }
            return ProcessRow(pid: pid, tty: String(parts[1]), command: String(parts[2]))
        }
    }

    private static func sessionIDs(openedBy pid: Int32) -> [String] {
        guard let output = commandOutput("/usr/sbin/lsof", arguments: ["-Fn", "-p", String(pid)]) else { return [] }

        return output.split(separator: "\n").compactMap { line in
            guard line.first == "n" else { return nil }
            let path = String(line.dropFirst())
            guard path.contains("/.codex/sessions/"), path.hasSuffix(".jsonl") else { return nil }
            return sessionID(fromRolloutPath: path)
        }
    }

    private static func sessionID(fromRolloutPath path: String) -> String? {
        let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let parts = stem.split(separator: "-")
        guard parts.count >= 7 else { return nil }
        return parts.suffix(5).joined(separator: "-")
    }

    private static func hookStates() -> [String: CodexSessionRuntimeState] {
        let directory = CodexHookInstaller.runtimeDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return [:]
        }

        return files.reduce(into: [String: CodexSessionRuntimeState]()) { result, url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let snapshot = try? JSONDecoder().decode(HookSnapshot.self, from: data),
                  snapshot.active else { return }
            result[snapshot.sessionID] = .runningInTerminal(
                tty: snapshot.tty,
                pid: snapshot.pid,
                iTermSessionID: snapshot.iTermSessionID
            )
        }
    }

    private static func commandOutput(_ executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                Log.error("[CodexRuntime] command failed executable=\(executable) status=\(process.terminationStatus)", category: .terminal)
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            Log.error("[CodexRuntime] command run error executable=\(executable) error=\(error)", category: .terminal)
            return nil
        }
    }
}
