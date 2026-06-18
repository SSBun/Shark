//
//  CodexSession.swift
//  Shark
//

import Foundation

struct CodexSession: Identifiable, Hashable {
    let id: String
    let title: String
    let cwd: String
    let filePath: String
    let updatedAt: Date
    let isArchived: Bool
    let source: String?
    let model: String?
    let runtimeState: CodexSessionRuntimeState
}
