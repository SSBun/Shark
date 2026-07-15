//
//  WorkspaceGitOverviewView.swift
//  Shark
//

import SwiftUI

struct WorkspaceGitOverviewView: View {
    let folders: [Folder]
    let store: WorkspaceGitStatusStore

    @State private var fetchRequest = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workspace Git Overview")
                        .font(.headline)
                    Text("Version, working tree, and upstream status for every repository")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Fetch & Refresh", systemImage: "arrow.triangle.2.circlepath", action: requestFetch)
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(store.isFetchingRemotes || !store.hasRepositories)

                Button("Done", action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if store.hasRepositories {
                Table(repositoryFolders) {
                    TableColumn("Repository") { folder in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.displayName ?? folder.name)
                            if let branch = store.status(for: folder)?.currentBranch, !branch.isEmpty {
                                Text(branch)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .width(min: 160, ideal: 220)

                    TableColumn("Version") { folder in
                        GitStatusValueView(
                            status: store.status(for: folder),
                            kind: .version,
                            isLoading: store.isLoading,
                            showsDetails: true
                        )
                    }
                    .width(min: 90, ideal: 120)

                    TableColumn("Working Tree") { folder in
                        GitStatusValueView(
                            status: store.status(for: folder),
                            kind: .workingTree,
                            isLoading: store.isLoading,
                            showsDetails: true
                        )
                    }
                    .width(min: 150, ideal: 220)

                    TableColumn("Remote") { folder in
                        GitStatusValueView(
                            status: store.status(for: folder),
                            kind: .upstream,
                            isLoading: store.isLoading,
                            showsDetails: true
                        )
                    }
                    .width(min: 130, ideal: 180)
                }
            } else if store.isLoading {
                ProgressView("Checking repositories…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Git Repositories",
                    systemImage: "folder.badge.questionmark",
                    description: Text("This workspace does not contain any Git repositories.")
                )
            }
        }
        .frame(minWidth: 680, idealWidth: 780, minHeight: 320, idealHeight: 440)
        .task(id: fetchRequest) {
            guard fetchRequest > 0 else { return }
            await store.fetchAndRefresh(folders: folders)
        }
    }

    /// Filters the workspace folders to the repositories found by the latest scan.
    ///
    /// - Complexity: O(n), where n is the number of workspace folders.
    private var repositoryFolders: [Folder] {
        folders.filter(store.isRepository)
    }

    private func requestFetch() {
        fetchRequest += 1
    }
}
