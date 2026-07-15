import Darwin
import Foundation

@main
struct CodexSessionRefreshCheck {
    static func main() {
        verifyBatchLsofKeepsPartialOutput()
        verifySQLiteFirstWithJSONLFallback()

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let start = ContinuousClock.now
        let sessions = CodexSessionManager.sessions(matching: homePath, folderPaths: [])
        let metadataElapsed = start.duration(to: .now)

        guard metadataElapsed < .milliseconds(250) else {
            fail("metadata load took \(metadataElapsed); expected under 0.25 seconds")
        }

        let runtimeStart = ContinuousClock.now
        _ = CodexSessionRuntimeDetector.terminalStates()
        let runtimeElapsed = runtimeStart.duration(to: .now)
        guard runtimeElapsed < .milliseconds(500) else {
            fail("runtime detection took \(runtimeElapsed); expected under 0.5 seconds")
        }
        guard metadataElapsed + runtimeElapsed < .milliseconds(750) else {
            fail("full refresh took \(metadataElapsed + runtimeElapsed); expected under 0.75 seconds")
        }

        print(
            "codex session refresh verified: sessions=\(sessions.count) "
                + "metadata=\(metadataElapsed) runtime=\(runtimeElapsed)"
        )
    }

    private static func verifyBatchLsofKeepsPartialOutput() {
        let sessionID = "11111111-2222-3333-4444-555555555555"
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionURL = fixtureRoot
            .appendingPathComponent(".codex/sessions/2026/07/15", isDirectory: true)
            .appendingPathComponent("rollout-2026-07-15T00-00-00-\(sessionID).jsonl")
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        do {
            try FileManager.default.createDirectory(
                at: sessionURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("fixture\n".utf8).write(to: sessionURL)
            let handle = try FileHandle(forReadingFrom: sessionURL)
            defer { try? handle.close() }

            let processID = getpid()
            let sessionsByPID = CodexSessionRuntimeDetector.sessionIDs(
                openedBy: [processID, Int32.max]
            )
            guard sessionsByPID[processID] == [sessionID] else {
                fail("batch lsof discarded valid stdout when another PID was missing")
            }
        } catch {
            fail("batch lsof fixture failed: \(error)")
        }
    }

    private static func verifySQLiteFirstWithJSONLFallback() {
        let indexedID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        let fallbackID = "11111111-2222-3333-4444-555555555555"
        let staleID = "99999999-8888-7777-6666-555555555555"
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionsDirectory = fixtureRoot
            .appendingPathComponent("sessions/2026/07/15", isDirectory: true)
        let indexedURL = sessionsDirectory
            .appendingPathComponent("rollout-2026-07-15T00-00-00-\(indexedID).jsonl")
        let fallbackURL = sessionsDirectory
            .appendingPathComponent("rollout-2026-07-15T00-00-01-\(fallbackID).jsonl")
        let staleURL = sessionsDirectory
            .appendingPathComponent("rollout-2026-07-15T00-00-02-\(staleID).jsonl")
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        do {
            try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
            try Data("invalid metadata proves SQLite was used\n".utf8).write(to: indexedURL)
            let fallbackMetadata = """
            {"type":"session_meta","payload":{"id":"\(fallbackID)","timestamp":"2026-07-15T00:00:01Z","cwd":"/workspace/fallback"}}
            """
            try Data("\(fallbackMetadata)\n".utf8).write(to: fallbackURL)
            try createThreadDatabase(
                at: fixtureRoot.appendingPathComponent("state_5.sqlite"),
                indexedID: indexedID,
                indexedPath: indexedURL.path,
                staleID: staleID,
                stalePath: staleURL.path
            )

            let sessions = CodexSessionManager.sessions(
                matching: "/workspace",
                folderPaths: [],
                codexURL: fixtureRoot
            )
            guard sessions.map(\.id) == [indexedID, fallbackID],
                  sessions.allSatisfy({ !$0.runtimeState.isRunningInTerminal }) else {
                fail("SQLite-first metadata did not preserve JSONL fallback or exclude stale paths")
            }
        } catch {
            fail("SQLite-first fixture failed: \(error)")
        }
    }

    private static func createThreadDatabase(
        at databaseURL: URL,
        indexedID: String,
        indexedPath: String,
        staleID: String,
        stalePath: String
    ) throws {
        let query = """
        create table threads (
          id text, title text, first_user_message text, preview text,
          updated_at_ms integer, archived integer, source text, model text,
          rollout_path text, cwd text
        );
        insert into threads values (
          '\(indexedID)', 'Indexed', '', '', 1800000000000, 0, 'cli', 'gpt',
          '\(indexedPath)', '/workspace/indexed'
        );
        insert into threads values (
          '\(staleID)', 'Stale', '', '', 1900000000000, 0, 'cli', 'gpt',
          '\(stalePath)', '/workspace/stale'
        );
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databaseURL.path, query]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "CodexSessionRefreshCheck", code: Int(process.terminationStatus))
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }
}
