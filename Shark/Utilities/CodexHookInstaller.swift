//
//  CodexHookInstaller.swift
//  Shark
//

import Foundation

enum CodexHookInstaller {
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: hookScriptURL.path) && installedEvents().isSuperset(of: Set(events))
    }

    static var hooksPath: String {
        hooksJSONURL.path
    }

    static var runtimeDirectory: URL {
        applicationSupportURL.appendingPathComponent("CodexSessionRuntime", isDirectory: true)
    }

    static func install() throws {
        try FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
        try hookScript.write(to: hookScriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptURL.path)
        try FileManager.default.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
        try writeHooksJSON()
    }

    private static let events = ["SessionStart", "Stop", "PreToolUse", "PostToolUse"]

    private static var applicationSupportURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Shark", isDirectory: true)
    }

    private static var hookScriptURL: URL {
        applicationSupportURL.appendingPathComponent("codex-session-hook")
    }

    private static var codexHomeURL: URL {
        let raw = ProcessInfo.processInfo.environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else {
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        }
        if raw == "~" {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        if raw.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(raw.dropFirst(2)), isDirectory: true)
        }
        return URL(fileURLWithPath: raw, isDirectory: true)
    }

    private static var hooksJSONURL: URL {
        codexHomeURL.appendingPathComponent("hooks.json")
    }

    private static var hookCommandPrefix: String {
        "\"\(hookScriptURL.path)\""
    }

    private static func hookCommand(for event: String) -> String {
        "\(hookCommandPrefix) \(event)"
    }

    private static func installedEvents() -> Set<String> {
        guard let root = try? hooksRoot() else { return [] }
        let hooks = root["hooks"] as? [String: Any] ?? [:]
        return Set(events.filter { event in
            guard let entries = hooks[event] as? [[String: Any]] else { return false }
            return entries.contains { entry in
                guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { ($0["command"] as? String) == hookCommand(for: event) }
            }
        })
    }

    private static func writeHooksJSON() throws {
        var root = try hooksRoot()
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for event in events {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll { entry in
                guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { ($0["command"] as? String)?.contains("codex-session-hook") == true }
            }
            entries.append(entry(for: event))
            hooks[event] = entries
        }

        root["hooks"] = hooks
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: hooksJSONURL, options: .atomic)
    }

    private static func hooksRoot() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: hooksJSONURL.path) else { return [:] }
        let data = try Data(contentsOf: hooksJSONURL)
        guard !data.isEmpty else { return [:] }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "CodexHookInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid hooks.json"])
        }
        return root
    }

    private static func entry(for event: String) -> [String: Any] {
        var entry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": hookCommand(for: event),
                "timeout": 5
            ]]
        ]
        if event == "SessionStart" {
            entry["matcher"] = "startup|resume"
        } else if event == "PreToolUse" || event == "PostToolUse" {
            entry["matcher"] = "*"
        }
        return entry
    }

    private static let hookScript = """
#!/usr/bin/env python3
import datetime
import json
import os
import pathlib
import re
import sys

def read_payload():
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}

def first(*values):
    for value in values:
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None

def detect_tty():
    try:
        fd = os.open("/dev/tty", os.O_RDONLY | getattr(os, "O_NOCTTY", 0))
        try:
            return os.ttyname(fd)
        finally:
            os.close(fd)
    except Exception:
        return None

def normalize_iterm(value):
    if not value:
        return None
    return value.split(":", 1)[1] if ":" in value else value

payload = read_payload()
event = sys.argv[1] if len(sys.argv) > 1 else first(
    payload.get("hook_event_name"),
    payload.get("hookEventName"),
    payload.get("eventName"),
    payload.get("event"),
) or "Unknown"
session_id = first(payload.get("session_id"), payload.get("sessionId"))
if not session_id:
    sys.exit(0)

out_dir = pathlib.Path.home() / "Library/Application Support/Shark/CodexSessionRuntime"
out_dir.mkdir(parents=True, exist_ok=True)
safe_name = re.sub(r"[^A-Za-z0-9_.-]", "_", session_id) + ".json"
path = out_dir / safe_name
snapshot = {
    "sessionID": session_id,
    "event": event,
    "active": event != "Stop",
    "cwd": os.getcwd(),
    "pid": os.getppid(),
    "tty": detect_tty(),
    "iTermSessionID": normalize_iterm(os.environ.get("ITERM_SESSION_ID")),
    "termProgram": os.environ.get("TERM_PROGRAM"),
    "updatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
}
tmp = path.with_suffix(".tmp")
tmp.write_text(json.dumps(snapshot, separators=(",", ":")), encoding="utf-8")
tmp.replace(path)
"""
}
