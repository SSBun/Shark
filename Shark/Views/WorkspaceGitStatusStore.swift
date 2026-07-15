//
//  WorkspaceGitStatusStore.swift
//  Shark
//

import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceGitStatusStore {
    private(set) var statuses: [Folder.ID: GitRepositoryStatus] = [:]
    private(set) var repositoryIDs: Set<Folder.ID> = []
    private(set) var isLoading = false
    private(set) var isFetchingRemotes = false

    private var cachedStatusesByPath: [String: GitRepositoryStatus] = [:]
    private var loadID = UUID()

    var hasRepositories: Bool {
        !repositoryIDs.isEmpty
    }

    /// Returns the latest loaded status for a folder.
    func status(for folder: Folder) -> GitRepositoryStatus? {
        statuses[folder.id]
    }

    /// Returns whether a folder was identified as a Git repository during the latest scan.
    func isRepository(_ folder: Folder) -> Bool {
        repositoryIDs.contains(folder.id)
    }

    /// Loads local status, reusing repositories already checked during this App session.
    func load(folders: [Folder]) async {
        await update(folders: folders, fetchRemotes: false, reuseCachedStatuses: true)
    }

    /// Reloads local status using the repository's existing remote-tracking refs.
    func refresh(folders: [Folder]) async {
        await update(folders: folders, fetchRemotes: false, reuseCachedStatuses: false)
    }

    /// Fetches remote refs and then reloads each repository's status.
    func fetchAndRefresh(folders: [Folder]) async {
        await update(folders: folders, fetchRemotes: true, reuseCachedStatuses: false)
    }

    private func update(
        folders: [Folder],
        fetchRemotes: Bool,
        reuseCachedStatuses: Bool
    ) async {
        let repositories = folders.filter { $0.existsOnDisk && $0.isGitRepository }
        let requestID = UUID()
        loadID = requestID

        statuses = Dictionary(uniqueKeysWithValues: repositories.compactMap { folder in
            cachedStatusesByPath[folder.path].map { (folder.id, $0) }
        })
        repositoryIDs = Set(repositories.map(\.id))

        let repositoriesToLoad: [Folder]
        if reuseCachedStatuses {
            repositoriesToLoad = repositories.filter { cachedStatusesByPath[$0.path] == nil }
        } else {
            repositoriesToLoad = repositories
        }

        isLoading = !repositoriesToLoad.isEmpty
        isFetchingRemotes = fetchRemotes

        defer {
            if loadID == requestID {
                isLoading = false
                isFetchingRemotes = false
            }
        }

        for folder in repositoriesToLoad {
            guard !Task.isCancelled, loadID == requestID else { return }

            var freshness = GitRepositoryStatus.RemoteFreshness.cached
            if fetchRemotes {
                do {
                    try await GitManager.shared.fetchRemoteReferences(at: folder.path)
                    freshness = .fetched
                } catch {
                    freshness = .failed(error.localizedDescription)
                }
            }

            var status = await GitManager.shared.repositoryStatus(at: folder.path)
            guard !Task.isCancelled, loadID == requestID else { return }

            if status.isAvailable {
                status.remoteFreshness = freshness
                cachedStatusesByPath[folder.path] = status
            } else {
                cachedStatusesByPath.removeValue(forKey: folder.path)
            }
            statuses[folder.id] = status
        }
    }
}
