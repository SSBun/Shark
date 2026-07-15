//
//  GitStatusValueView.swift
//  Shark
//

import SwiftUI

struct GitStatusValueView: View {
    enum Kind {
        /// Displays the latest known Git tag.
        case version
        /// Displays staged, unstaged, untracked, and conflict state.
        case workingTree
        /// Displays the current branch's relationship with its upstream branch.
        case upstream
    }

    let status: GitRepositoryStatus?
    let kind: Kind
    let isLoading: Bool
    let showsDetails: Bool

    var body: some View {
        Label(text, systemImage: icon)
            .foregroundStyle(color)
            .lineLimit(1)
            .help(helpText)
            .accessibilityLabel("\(title): \(text)")
    }

    private var title: String {
        switch kind {
        case .version:
            "Version"
        case .workingTree:
            "Working Tree"
        case .upstream:
            "Remote"
        }
    }

    private var text: String {
        guard let status else {
            return isLoading ? "Checking…" : "Unknown"
        }
        guard status.isAvailable else { return "Unavailable" }

        switch kind {
        case .version:
            return status.latestTag ?? "No Tag"
        case .workingTree:
            return workingTreeText(for: status)
        case .upstream:
            return upstreamText(for: status)
        }
    }

    private var icon: String {
        guard let status else {
            return isLoading ? "arrow.triangle.2.circlepath" : "questionmark.circle"
        }
        guard status.isAvailable else { return "exclamationmark.triangle" }

        switch kind {
        case .version:
            return "tag"
        case .workingTree:
            if status.hasConflicts {
                return "exclamationmark.triangle.fill"
            }
            return status.isClean ? "checkmark.circle" : "pencil.circle"
        case .upstream:
            if case .failed = status.remoteFreshness {
                return "wifi.exclamationmark"
            }
            switch status.upstreamState {
            case .synced:
                return "checkmark.circle"
            case .ahead:
                return "arrow.up.circle"
            case .behind:
                return "arrow.down.circle"
            case .diverged:
                return "arrow.up.arrow.down.circle"
            case .noUpstream:
                return "link.badge.plus"
            case .detachedHead:
                return "arrow.triangle.branch"
            case .unavailable:
                return "exclamationmark.triangle"
            }
        }
    }

    private var color: Color {
        guard let status, status.isAvailable else { return .secondary }

        switch kind {
        case .version:
            return .secondary
        case .workingTree:
            if status.hasConflicts {
                return .red
            }
            return status.isClean ? .green : .orange
        case .upstream:
            if case .failed = status.remoteFreshness {
                return .red
            }
            switch status.upstreamState {
            case .synced:
                return .green
            case .ahead:
                return .blue
            case .behind:
                return .purple
            case .diverged:
                return .orange
            case .noUpstream, .detachedHead, .unavailable:
                return .secondary
            }
        }
    }

    private var helpText: String {
        guard let status else { return "Git status has not been loaded" }
        if let errorMessage = status.errorMessage {
            return errorMessage
        }

        switch kind {
        case .version:
            return "Latest known Git tag"
        case .workingTree:
            return workingTreeDetails(for: status)
        case .upstream:
            switch status.remoteFreshness {
            case .cached:
                return "Based on the repository's existing remote-tracking refs"
            case .fetched:
                return "Remote refs were fetched before this status check"
            case .failed(let message):
                return message
            }
        }
    }

    private func workingTreeText(for status: GitRepositoryStatus) -> String {
        if status.hasConflicts {
            return showsDetails ? workingTreeDetails(for: status) : "\(status.conflictFiles) conflicts"
        }
        if status.isClean {
            return "Clean"
        }
        return showsDetails ? workingTreeDetails(for: status) : "\(status.changeCount) changes"
    }

    private func workingTreeDetails(for status: GitRepositoryStatus) -> String {
        var parts: [String] = []
        if status.stagedFiles > 0 {
            parts.append("\(status.stagedFiles) staged")
        }
        if status.modifiedFiles > 0 {
            parts.append("\(status.modifiedFiles) modified")
        }
        if status.untrackedFiles > 0 {
            parts.append("\(status.untrackedFiles) untracked")
        }
        if status.conflictFiles > 0 {
            parts.append("\(status.conflictFiles) conflicts")
        }
        return parts.isEmpty ? "Clean" : parts.joined(separator: " · ")
    }

    private func upstreamText(for status: GitRepositoryStatus) -> String {
        if case .failed = status.remoteFreshness {
            return "Fetch Failed"
        }

        let value = switch status.upstreamState {
        case .synced:
            "Synced"
        case .ahead(let count):
            "\(count) unpushed"
        case .behind(let count):
            "\(count) behind"
        case .diverged(let ahead, let behind):
            "\(ahead) ahead · \(behind) behind"
        case .noUpstream:
            "No Upstream"
        case .detachedHead:
            "Detached HEAD"
        case .unavailable:
            "Unavailable"
        }

        if showsDetails, status.remoteFreshness == .cached,
           status.upstreamState != .noUpstream,
           status.upstreamState != .detachedHead {
            return "\(value) · Cached"
        }
        return value
    }
}
