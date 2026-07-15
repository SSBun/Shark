//
//  CodexSessionPreview.swift
//  Shark
//

import Foundation

/// The user-visible conversation excerpt shown for a Codex session.
struct CodexSessionPreview: Equatable, Sendable {
    let initialPrompt: Message?
    let recentMessages: [Message]

    struct Message: Identifiable, Equatable, Sendable {
        enum Role: Equatable, Sendable {
            case user
            case assistant
        }

        let id: Int
        let role: Role
        let text: String
        let timestamp: Date?
    }
}
