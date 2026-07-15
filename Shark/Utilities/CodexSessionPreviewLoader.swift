//
//  CodexSessionPreviewLoader.swift
//  Shark
//

import Foundation

enum CodexSessionPreviewLoader {
    private static let recentMessageLimit = 8

    /// Loads the user-visible conversation excerpt from a Codex JSONL file.
    static func load(from fileURL: URL) async throws -> CodexSessionPreview {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let decoder = JSONDecoder()
        var initialPrompt: CodexSessionPreview.Message?
        var recentMessages: [CodexSessionPreview.Message] = []
        var lineNumber = 0

        for try await line in handle.bytes.lines {
            try Task.checkCancellation()
            lineNumber += 1

            guard isMessageEvent(line),
                  let data = line.data(using: .utf8),
                  let record = try? decoder.decode(Record.self, from: data),
                  record.type == "event_msg",
                  let role = role(for: record.payload.type),
                  let text = record.payload.message,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let message = CodexSessionPreview.Message(
                id: lineNumber,
                role: role,
                text: text,
                timestamp: record.timestamp.flatMap { try? Date($0, strategy: .iso8601) }
            )

            if role == .user, initialPrompt == nil {
                initialPrompt = message
                continue
            }

            recentMessages.append(message)
            if recentMessages.count > recentMessageLimit {
                recentMessages.removeFirst(recentMessages.count - recentMessageLimit)
            }
        }

        return CodexSessionPreview(
            initialPrompt: initialPrompt,
            recentMessages: recentMessages
        )
    }

    private static func isMessageEvent(_ line: String) -> Bool {
        line.contains("\"event_msg\"") &&
            (line.contains("\"user_message\"") || line.contains("\"agent_message\""))
    }

    private static func role(for payloadType: String) -> CodexSessionPreview.Message.Role? {
        switch payloadType {
        case "user_message":
            .user
        case "agent_message":
            .assistant
        default:
            nil
        }
    }

    private struct Record: Decodable {
        let timestamp: String?
        let type: String
        let payload: Payload

        struct Payload: Decodable {
            let type: String
            let message: String?
        }
    }
}
