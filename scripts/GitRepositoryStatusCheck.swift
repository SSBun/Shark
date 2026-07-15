import Darwin
import Foundation

struct Folder: Identifiable {
    let id: UUID
    let path: String
    let existsOnDisk: Bool
    let isGitRepository: Bool

    init(
        id: UUID = UUID(),
        path: String,
        existsOnDisk: Bool = true,
        isGitRepository: Bool = true
    ) {
        self.id = id
        self.path = path
        self.existsOnDisk = existsOnDisk
        self.isGitRepository = isGitRepository
    }
}

@MainActor
final class GitManager {
    static let shared = GitManager()

    private(set) var statusRequestCounts: [String: Int] = [:]
    private(set) var fetchRequestCounts: [String: Int] = [:]
    var unavailablePaths: Set<String> = []

    func reset() {
        statusRequestCounts = [:]
        fetchRequestCounts = [:]
        unavailablePaths = []
    }

    func repositoryStatus(at repoPath: String) async -> GitRepositoryStatus {
        let requestCount = statusRequestCounts[repoPath, default: 0] + 1
        statusRequestCounts[repoPath] = requestCount

        if unavailablePaths.contains(repoPath) {
            return .unavailable("unavailable")
        }

        return GitRepositoryStatus(
            porcelainV2: "# branch.head main",
            latestTag: "scan-\(requestCount)"
        )
    }

    func fetchRemoteReferences(at repoPath: String) async throws {
        fetchRequestCounts[repoPath, default: 0] += 1
    }
}

@main
@MainActor
struct GitRepositoryStatusCheck {
    static func main() async {
        verifyCleanAndSynced()
        verifyDirtyAndAhead()
        verifyBehindAndDiverged()
        verifyNoUpstreamAndDetachedHead()
        verifyUnavailable()
        await verifyWorkspaceStatusCache()
        print("git repository status and workspace cache verified")
    }

    private static func verifyWorkspaceStatusCache() async {
        let manager = GitManager.shared
        manager.reset()

        let store = WorkspaceGitStatusStore()
        let firstA = Folder(path: "/repositories/a")
        let repositoryB = Folder(path: "/repositories/b")
        let revisitedA = Folder(path: "/repositories/a")

        await store.load(folders: [firstA])
        await store.load(folders: [repositoryB])
        await store.load(folders: [revisitedA])

        guard manager.statusRequestCounts[firstA.path] == 1,
              store.status(for: revisitedA)?.latestTag == "scan-1" else {
            fail("revisiting a repository did not reuse its path cache")
        }

        await store.refresh(folders: [revisitedA])
        guard manager.statusRequestCounts[firstA.path] == 2,
              store.status(for: revisitedA)?.latestTag == "scan-2" else {
            fail("explicit local refresh did not bypass the path cache")
        }

        await store.fetchAndRefresh(folders: [revisitedA])
        guard manager.statusRequestCounts[firstA.path] == 3,
              manager.fetchRequestCounts[firstA.path] == 1,
              store.status(for: revisitedA)?.remoteFreshness == .fetched else {
            fail("fetch refresh did not bypass the path cache")
        }

        let unavailable = Folder(path: "/repositories/unavailable")
        manager.unavailablePaths.insert(unavailable.path)
        await store.load(folders: [unavailable])
        await store.load(folders: [repositoryB])
        await store.load(folders: [unavailable])

        guard manager.statusRequestCounts[unavailable.path] == 2 else {
            fail("an unavailable repository was cached")
        }
    }

    private static func verifyCleanAndSynced() {
        let status = GitRepositoryStatus(
            porcelainV2: """
            # branch.oid 1111111111111111111111111111111111111111
            # branch.head main
            # branch.upstream origin/main
            # branch.ab +0 -0
            """,
            latestTag: "v1.12.1"
        )

        guard status.latestTag == "v1.12.1",
              status.currentBranch == "main",
              status.isClean,
              status.upstreamState == .synced else {
            fail("clean synced repository was parsed incorrectly")
        }
    }

    private static func verifyDirtyAndAhead() {
        let status = GitRepositoryStatus(
            porcelainV2: """
            # branch.head feature/overview
            # branch.upstream origin/feature/overview
            # branch.ab +3 -0
            1 M. N... 100644 100644 100644 aaaaaaa bbbbbbb staged.swift
            1 .M N... 100644 100644 100644 aaaaaaa bbbbbbb modified.swift
            1 MM N... 100644 100644 100644 aaaaaaa bbbbbbb both.swift
            ? untracked.swift
            u UU N... 100644 100644 100644 100644 aaaaaaa bbbbbbb ccccccc conflicted.swift
            """,
            latestTag: nil
        )

        guard status.latestTag == nil,
              !status.isClean,
              status.changeCount == 5,
              status.stagedFiles == 2,
              status.modifiedFiles == 2,
              status.untrackedFiles == 1,
              status.conflictFiles == 1,
              status.upstreamState == .ahead(3) else {
            fail("dirty ahead repository was parsed incorrectly")
        }
    }

    private static func verifyBehindAndDiverged() {
        let behind = GitRepositoryStatus(
            porcelainV2: """
            # branch.head main
            # branch.upstream origin/main
            # branch.ab +0 -2
            """,
            latestTag: "2.0.0"
        )
        let diverged = GitRepositoryStatus(
            porcelainV2: """
            # branch.head main
            # branch.upstream origin/main
            # branch.ab +4 -2
            """,
            latestTag: "2.0.0"
        )

        guard behind.upstreamState == .behind(2),
              diverged.upstreamState == .diverged(ahead: 4, behind: 2) else {
            fail("behind or diverged repository was parsed incorrectly")
        }
    }

    private static func verifyNoUpstreamAndDetachedHead() {
        let noUpstream = GitRepositoryStatus(
            porcelainV2: "# branch.head local-only",
            latestTag: nil
        )
        let detached = GitRepositoryStatus(
            porcelainV2: "# branch.head (detached)",
            latestTag: "v1.0.0"
        )

        guard noUpstream.upstreamState == .noUpstream,
              detached.currentBranch == "Detached HEAD",
              detached.upstreamState == .detachedHead else {
            fail("no-upstream or detached repository was parsed incorrectly")
        }
    }

    private static func verifyUnavailable() {
        let status = GitRepositoryStatus.unavailable("permission denied")
        guard !status.isAvailable,
              !status.isClean,
              status.upstreamState == .unavailable else {
            fail("unavailable repository was reported as healthy")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }
}
