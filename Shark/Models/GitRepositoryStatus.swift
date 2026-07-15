//
//  GitRepositoryStatus.swift
//  Shark
//

import Foundation

struct GitRepositoryStatus: Equatable, Sendable {
    enum UpstreamState: Equatable, Sendable {
        /// The current branch matches its upstream branch.
        case synced
        /// The current branch has local commits that have not been pushed.
        case ahead(Int)
        /// The upstream branch has commits that are not available locally.
        case behind(Int)
        /// The local and upstream branches both contain unique commits.
        case diverged(ahead: Int, behind: Int)
        /// The current branch does not track a remote branch.
        case noUpstream
        /// HEAD is not attached to a local branch.
        case detachedHead
        /// Git status could not be determined.
        case unavailable
    }

    enum RemoteFreshness: Equatable, Sendable {
        /// The upstream result uses the repository's existing remote-tracking refs.
        case cached
        /// Remote refs were fetched immediately before the status check.
        case fetched
        /// The latest fetch failed, so the upstream result is not trustworthy.
        case failed(String)
    }

    var latestTag: String?
    var currentBranch: String
    var stagedFiles: Int
    var modifiedFiles: Int
    var untrackedFiles: Int
    var conflictFiles: Int
    var changeCount: Int
    var upstreamState: UpstreamState
    var remoteFreshness: RemoteFreshness
    var errorMessage: String?

    var isAvailable: Bool {
        errorMessage == nil
    }

    var isClean: Bool {
        isAvailable && changeCount == 0
    }

    var hasConflicts: Bool {
        conflictFiles > 0
    }

    var aheadCount: Int {
        switch upstreamState {
        case .ahead(let count), .diverged(ahead: let count, behind: _):
            count
        default:
            0
        }
    }

    var behindCount: Int {
        switch upstreamState {
        case .behind(let count), .diverged(ahead: _, behind: let count):
            count
        default:
            0
        }
    }

    init() {
        latestTag = nil
        currentBranch = ""
        stagedFiles = 0
        modifiedFiles = 0
        untrackedFiles = 0
        conflictFiles = 0
        changeCount = 0
        upstreamState = .noUpstream
        remoteFreshness = .cached
        errorMessage = nil
    }

    /// Creates repository status by parsing `git status --porcelain=v2 --branch` output.
    init(porcelainV2 output: String, latestTag: String?) {
        self.init()
        self.latestTag = latestTag

        var hasUpstream = false
        var isDetachedHead = false
        var ahead = 0
        var behind = 0

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)

            if line.hasPrefix("# branch.head ") {
                let head = String(line.dropFirst("# branch.head ".count))
                isDetachedHead = head == "(detached)"
                currentBranch = isDetachedHead ? "Detached HEAD" : head
                continue
            }

            if line.hasPrefix("# branch.upstream ") {
                hasUpstream = true
                continue
            }

            if line.hasPrefix("# branch.ab ") {
                let counts = line.dropFirst("# branch.ab ".count).split(separator: " ")
                if counts.count == 2 {
                    ahead = Int(counts[0].dropFirst()) ?? 0
                    behind = Int(counts[1].dropFirst()) ?? 0
                }
                continue
            }

            switch line.first {
            case "?":
                untrackedFiles += 1
                changeCount += 1
            case "u":
                conflictFiles += 1
                changeCount += 1
            case "1", "2":
                let fields = line.split(separator: " ", maxSplits: 2)
                guard fields.count >= 2, fields[1].count == 2 else { continue }
                let indexStatus = fields[1].first
                let workTreeStatus = fields[1].last
                if indexStatus != "." {
                    stagedFiles += 1
                }
                if workTreeStatus != "." {
                    modifiedFiles += 1
                }
                changeCount += 1
            default:
                continue
            }
        }

        if isDetachedHead {
            upstreamState = .detachedHead
        } else if !hasUpstream {
            upstreamState = .noUpstream
        } else if ahead > 0, behind > 0 {
            upstreamState = .diverged(ahead: ahead, behind: behind)
        } else if ahead > 0 {
            upstreamState = .ahead(ahead)
        } else if behind > 0 {
            upstreamState = .behind(behind)
        } else {
            upstreamState = .synced
        }
    }

    /// Creates an unavailable status with a user-displayable failure reason.
    static func unavailable(_ message: String) -> GitRepositoryStatus {
        var status = GitRepositoryStatus()
        status.upstreamState = .unavailable
        status.errorMessage = message
        return status
    }
}
