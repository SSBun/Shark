//
//  CodexSessionListView.swift
//  Shark
//

import SwiftUI

struct CodexSessionListView: View {
    let sessions: [CodexSession]
    let isLoading: Bool
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
                            Label("Archived Sessions (\(archivedSessions.count))", systemImage: "archivebox")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
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
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded { onPreview() }
            )
            .accessibilityAction(named: Text("Preview Session"), onPreview)
            .help("Double-click to preview session")

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
        .contextMenu {
            Button(action: onResumeInTerminal) {
                Label("Resume in Terminal", systemImage: "terminal")
            }
            Button(action: onRename) {
                Label("Rename Display Name", systemImage: "pencil")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
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
        [
            formattedDate(session.updatedAt),
            session.isArchived ? "Archived" : "Active",
            runtimeSummary,
            session.source,
            session.model,
            session.cwd
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "  ")
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
