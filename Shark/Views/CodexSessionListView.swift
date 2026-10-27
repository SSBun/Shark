//
//  CodexSessionListView.swift
//  Shark
//

import SwiftUI

struct CodexSessionListView: View {
    let sessions: [CodexSession]
    let isLoading: Bool
    let canRename: Bool
    let onRefresh: () -> Void
    let onPreview: (CodexSession) -> Void
    let onShowInFinder: ([CodexSession]) -> Void
    let onCopyPath: ([CodexSession]) -> Void
    let onResumeInTerminal: ([CodexSession]) -> Void
    let onJumpToITerm: (CodexSession) -> Void
    let onCopySessionID: ([CodexSession]) -> Void
    let onRename: (CodexSession) -> Void
    let onArchive: ([CodexSession]) -> Void
    let onDelete: ([CodexSession]) -> Void
    let onCleanArchived: () -> Void

    @State private var isArchivedExpanded = false
    @State private var selectedSessionIDs = Set<CodexSession.ID>()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Codex Sessions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onRefresh) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("Refresh Codex sessions")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 36)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if sessions.isEmpty {
                VStack {
                    Spacer()
                    Text(isLoading ? "Loading sessions..." : "No Codex sessions")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $selectedSessionIDs) {
                    ForEach(groupedActiveSessions) { group in
                        Section(group.title) {
                            ForEach(group.sessions) { session in
                                sessionRow(session)
                            }
                        }
                    }

                    if !archivedSessions.isEmpty {
                        DisclosureGroup(isExpanded: $isArchivedExpanded) {
                            ForEach(archivedSessions) { session in
                                sessionRow(session)
                            }
                        } label: {
                            HStack {
                                Label("Archived Sessions (\(archivedSessions.count))", systemImage: "archivebox")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(role: .destructive, action: onCleanArchived) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Delete all archived sessions")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: sessions.map(\.id)) { _, ids in
                    selectedSessionIDs.formIntersection(Set(ids))
                }
            }
        }
    }

    private var groupedActiveSessions: [CodexSessionDateGroup] {
        CodexSessionDateBucket.allCases.compactMap { bucket in
            let bucketSessions = sessions.filter { !$0.isArchived && bucket.contains($0.updatedAt) }
            return bucketSessions.isEmpty ? nil : CodexSessionDateGroup(bucket: bucket, sessions: bucketSessions)
        }
    }

    private var archivedSessions: [CodexSession] {
        sessions.filter(\.isArchived)
    }

    @ViewBuilder
    private func sessionRow(_ session: CodexSession) -> some View {
        CodexSessionRow(
            session: session,
            canRename: canRename,
            onPreview: { onPreview(session) },
            onShowInFinder: { onShowInFinder(targetSessions(for: session)) },
            onCopyPath: { onCopyPath(targetSessions(for: session)) },
            onResumeInTerminal: { onResumeInTerminal(targetSessions(for: session)) },
            onJumpToITerm: { onJumpToITerm(session) },
            onCopySessionID: { onCopySessionID(targetSessions(for: session)) },
            onRename: { onRename(session) },
            onArchive: { onArchive(targetSessions(for: session)) },
            onDelete: { onDelete(targetSessions(for: session)) }
        )
        .tag(session.id)
    }

    private func targetSessions(for session: CodexSession) -> [CodexSession] {
        guard selectedSessionIDs.contains(session.id) else { return [session] }
        return sessions.filter { selectedSessionIDs.contains($0.id) }
    }
}

private struct CodexSessionDateGroup: Identifiable {
    let bucket: CodexSessionDateBucket
    let sessions: [CodexSession]

    var id: CodexSessionDateBucket { bucket }
    var title: String { "\(bucket.title) (\(sessions.count))" }
}

private enum CodexSessionDateBucket: CaseIterable {
    case eightHours
    case twoDays
    case oneWeek
    case older

    var title: String {
        switch self {
        case .eightHours:
            return "Last 8 Hours"
        case .twoDays:
            return "Last 2 Days"
        case .oneWeek:
            return "Last Week"
        case .older:
            return "Older"
        }
    }

    func contains(_ date: Date, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(date)
        switch self {
        case .eightHours:
            return age <= 8 * 60 * 60
        case .twoDays:
            return age > 8 * 60 * 60 && age <= 2 * 24 * 60 * 60
        case .oneWeek:
            return age > 2 * 24 * 60 * 60 && age <= 7 * 24 * 60 * 60
        case .older:
            return age > 7 * 24 * 60 * 60
        }
    }
}

private struct CodexSessionRow: View {
    let session: CodexSession
    let canRename: Bool
    let onPreview: () -> Void
    let onShowInFinder: () -> Void
    let onCopyPath: () -> Void
    let onResumeInTerminal: () -> Void
    let onJumpToITerm: () -> Void
    let onCopySessionID: () -> Void
    let onRename: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(session.runtimeState.isRunningInTerminal ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .help(runtimeHelp)

                Image(systemName: session.isArchived ? "archivebox" : "text.bubble")
                    .font(.system(size: 13))
                    .foregroundColor(session.isArchived ? .secondary : .accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Text(sessionSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(.rect)
            .accessibilityAction(named: Text("Preview Session"), onPreview)
            .help("Right-click to preview session")

            if session.runtimeState.isRunningInTerminal {
                Button(action: onJumpToITerm) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Jump to iTerm tab")
            }
        }
        .padding(.vertical, 4)
        .help(tooltip)
        .contextMenu {
            Button(action: onPreview) {
                Label("Preview", systemImage: "eye")
            }
            Button(action: onResumeInTerminal) {
                Label("Resume in Terminal", systemImage: "terminal")
            }
            Button(action: onRename) {
                Label("Rename Display Name", systemImage: "pencil")
            }
            .disabled(!canRename)
            Button(action: onArchive) {
                Label(session.isArchived ? "Unarchive" : "Archive", systemImage: session.isArchived ? "archivebox.fill" : "archivebox")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Divider()
            Button(action: onShowInFinder) {
                Label("Show in Finder", systemImage: "folder")
            }
            Button(action: onCopyPath) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            Button(action: onCopySessionID) {
                Label("Copy Session ID", systemImage: "number")
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private var sessionSummary: String {
        let message = session.lastUserMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var parts: [String] = [formattedDate(session.updatedAt)]
        if !message.isEmpty { parts.append(message) }
        if let summary = runtimeSummary { parts.append(summary) }
        if session.isArchived { parts.append("Archived") }
        return parts.joined(separator: "  ")
    }

    private var tooltip: String {
        [
            session.source.map { "Source: \($0)" },
            session.model.map { "Model: \($0)" },
            "Cwd: \(session.cwd)",
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private var runtimeSummary: String? {
        guard let tty = session.runtimeState.terminalTTY else {
            return session.runtimeState.iTermSessionID == nil ? nil : "Running in iTerm"
        }
        return "Running in \(tty)"
    }

    private var runtimeHelp: String {
        guard let tty = session.runtimeState.terminalTTY else {
            return session.runtimeState.iTermSessionID == nil ? "Not running in terminal" : "Running in iTerm"
        }
        return "Running in terminal \(tty)"
    }
}
