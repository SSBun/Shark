import Foundation

@main
enum CodexSessionPreviewLoaderCheck {
    static func main() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directoryURL.appending(path: "session.jsonl")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        var lines = [
            try jsonLine(type: "event_msg", payload: ["type": "user_message", "message": "Initial prompt"]),
            try jsonLine(type: "response_item", payload: ["type": "message", "role": "user", "content": []]),
            try jsonLine(type: "event_msg", payload: ["type": "agent_reasoning", "text": "Ignore reasoning"]),
            "{ malformed json"
        ]

        for index in 1...10 {
            lines.append(try jsonLine(
                type: "event_msg",
                payload: ["type": index.isMultiple(of: 2) ? "user_message" : "agent_message", "message": "Message \(index)"]
            ))
        }

        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        let preview = try await CodexSessionPreviewLoader.load(from: fileURL)

        precondition(preview.initialPrompt?.text == "Initial prompt")
        precondition(preview.recentMessages.map(\.text) == (3...10).map { "Message \($0)" })
        precondition(preview.recentMessages.map(\.role) == [
            .assistant, .user, .assistant, .user, .assistant, .user, .assistant, .user
        ])

        print("codex session preview loader verified")
    }

    private static func jsonLine(type: String, payload: [String: Any]) throws -> String {
        let object: [String: Any] = [
            "timestamp": "2026-07-15T08:30:12.123Z",
            "type": type,
            "payload": payload
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}
