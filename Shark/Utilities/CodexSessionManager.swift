//
//  CodexSessionManager.swift
//  Shark
//

import Foundation

enum CodexSessionManager {
    /// Loads Codex session metadata matching the supplied workspace roots.
    static func sessions(
        matching workspacePath: String,
        folderPaths: [String],
        displayNames: [String: String] = [:],
        codexURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    ) -> [CodexSession] {
        let matchRoots = ([workspacePath] + folderPaths).map(normalizedPath)
        guard !matchRoots.isEmpty else { return [] }

        let threads = threadIndex(in: codexURL)
        let threadsByPath = threads.values.reduce(into: [String: ThreadRecord]()) { result, thread in
            result[normalizedPath(thread.filePath)] = thread
        }
        let titles = sessionIndex(in: codexURL)
        let files = sessionFiles(in: codexURL)

        return files.compactMap { url in
            if let thread = threadsByPath[normalizedPath(url.path)] {
                guard matches(cwd: thread.cwd, roots: matchRoots) else { return nil }
                let indexed = titles[thread.id]
                return CodexSession(
                    id: thread.id,
                    title: bestTitle(displayNames[thread.id], thread.title, thread.firstUserMessage, thread.preview, indexed?.title, fallback: thread.id),
                    cwd: thread.cwd,
                    filePath: thread.filePath,
                    updatedAt: thread.updatedAt,
                    isArchived: thread.isArchived,
                    source: thread.source,
                    model: thread.model,
                    runtimeState: .inactive
                )
            }

            guard let meta = sessionMeta(from: url),
                  matches(cwd: meta.cwd, roots: matchRoots) else {
                return nil
            }

            let thread = threads[meta.id]
            let indexed = titles[meta.id]
            return CodexSession(
                id: meta.id,
                title: bestTitle(displayNames[meta.id], thread?.title, thread?.firstUserMessage, thread?.preview, indexed?.title, fallback: meta.id),
                cwd: meta.cwd,
                filePath: url.path,
                updatedAt: thread?.updatedAt ?? indexed?.updatedAt ?? meta.updatedAt,
                isArchived: isArchivedSessionFile(url),
                source: thread?.source,
                model: thread?.model,
                runtimeState: .inactive
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private struct SessionMeta {
        let id: String
        let cwd: String
        let updatedAt: Date
    }

    private struct IndexedSession {
        let title: String
        let updatedAt: Date
    }

    private struct ThreadRecord: Decodable {
        let id: String
        let title: String
        let firstUserMessage: String
        let preview: String
        let updatedAtMs: Int64?
        let archived: Int
        let source: String
        let model: String?
        let rolloutPath: String
        let cwd: String

        var updatedAt: Date {
            guard let updatedAtMs else { return .distantPast }
            return Date(timeIntervalSince1970: TimeInterval(updatedAtMs) / 1000)
        }

        var isArchived: Bool {
            archived != 0
        }

        var filePath: String {
            rolloutPath
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case firstUserMessage = "first_user_message"
            case preview
            case updatedAtMs = "updated_at_ms"
            case archived
            case source
            case model
            case rolloutPath = "rollout_path"
            case cwd
        }
    }

    private struct IndexRecord: Decodable {
        let id: String
        let threadName: String?
        let updatedAt: String

        private enum CodingKeys: String, CodingKey {
            case id
            case threadName = "thread_name"
            case updatedAt = "updated_at"
        }
    }

    private struct MetaRecord: Decodable {
        let type: String
        let payload: Payload

        struct Payload: Decodable {
            let id: String
            let timestamp: String
            let cwd: String
        }
    }

    private static func threadIndex(in codexURL: URL) -> [String: ThreadRecord] {
        guard let dbURL = threadDatabaseURL(in: codexURL),
              let data = sqliteJSON(
                dbURL: dbURL,
                query: "select id,title,first_user_message,preview,updated_at_ms,archived,source,model,rollout_path,cwd from threads"
              ),
              let records = try? JSONDecoder().decode([ThreadRecord].self, from: data) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    private static func threadDatabaseURL(in codexURL: URL) -> URL? {
        let candidates = [
            codexURL.appendingPathComponent("state_5.sqlite"),
            codexURL.appendingPathComponent("sqlite/state_5.sqlite")
        ]
        return candidates
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .max { modificationDate($0) < modificationDate($1) }
    }

    private static func modificationDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }

    private static func sqliteJSON(dbURL: URL, query: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-json", dbURL.path, query]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    private static func sessionIndex(in codexURL: URL) -> [String: IndexedSession] {
        let url = codexURL.appendingPathComponent("session_index.jsonl")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }

        var result: [String: IndexedSession] = [:]
        for line in text.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let record = try? JSONDecoder().decode(IndexRecord.self, from: data) else {
                continue
            }

            result[record.id] = IndexedSession(
                title: record.threadName ?? record.id,
                updatedAt: parseDate(record.updatedAt) ?? Date.distantPast
            )
        }
        return result
    }

    private static func sessionFiles(in codexURL: URL) -> [URL] {
        let roots = [
            codexURL.appendingPathComponent("sessions"),
            codexURL.appendingPathComponent("archived_sessions")
        ]

        return roots.flatMap { root in
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return [URL]()
            }

            return enumerator.compactMap { item -> URL? in
                guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
                return url
            }
        }
    }

    private static func sessionMeta(from url: URL) -> SessionMeta? {
        guard let line = firstLine(from: url),
              let data = line.data(using: .utf8),
              let record = try? JSONDecoder().decode(MetaRecord.self, from: data),
              record.type == "session_meta" else {
            return nil
        }

        return SessionMeta(
            id: record.payload.id,
            cwd: normalizedPath(record.payload.cwd),
            updatedAt: parseDate(record.payload.timestamp) ?? Date.distantPast
        )
    }

    private static func firstLine(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var data = Data()
        while data.count < 2_000_000 {
            let chunk = handle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { break }
            data.append(chunk)
            if let newline = data.firstIndex(of: 10) {
                data = data.prefix(upTo: newline)
                break
            }
        }
        return String(data: data, encoding: .utf8)
    }

    private static func matches(cwd: String, roots: [String]) -> Bool {
        let cwd = normalizedPath(cwd)
        return roots.contains { root in
            cwd == root || cwd.hasPrefix(root + "/")
        }
    }

    private static func normalizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private static func isArchivedSessionFile(_ url: URL) -> Bool {
        url.path.contains("/archived_sessions/")
    }

    private static func bestTitle(_ candidates: String?..., fallback: String) -> String {
        for candidate in candidates {
            let title = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !title.isEmpty {
                return title
            }
        }
        return fallback
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}
