//
//  MainWorkspaceView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI

struct MainWorkspaceView: View {
    @State private var store = WorkspaceStore()
    @State private var showComponentSelector = false
    @EnvironmentObject var authManager: AuthorizationManager

    var body: some View {
        @Bindable var store = store

        HSplitView {
            WorkspaceListView(store: store)
                .environmentObject(authManager)
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)

            VSplitView {
                FolderListView(
                    folders: $store.folders,
                    onAddFolder: {
                        Task { await store.addFolder(authManager: authManager) }
                    },
                    onUpdateFolder: { _ in
                        Task { await store.saveFoldersToWorkspace(authManager: authManager) }
                    },
                    onSelectComponents: {
                        showComponentSelector = true
                    },
                    onDropFolders: { droppedFolders in
                        Task { await store.handleDroppedFolders(droppedFolders) }
                    }
                )
                .frame(minWidth: 250, idealWidth: 300, minHeight: 220)

                CodexSessionListView(
                    sessions: store.codexSessions,
                    isLoading: store.isLoadingCodexSessions,
                    onRefresh: {
                        Task { await store.loadCodexSessions() }
                    },
                    onShowInFinder: { sessions in
                        store.showCodexSessionsInFinder(sessions)
                    },
                    onCopyPath: { sessions in
                        store.copyCodexSessionPaths(sessions)
                    },
                    onResumeInTerminal: { sessions in
                        store.resumeCodexSessionsInTerminal(sessions)
                    },
                    onJumpToITerm: { session in
                        store.jumpToCodexSessionInITerm(session)
                    },
                    onCopySessionID: { sessions in
                        store.copyCodexSessionIDs(sessions)
                    },
                    onRename: { session in
                        Task { await store.renameCodexSessionDisplayName(session) }
                    },
                    onArchive: { sessions in
                        Task { await store.archiveCodexSessions(sessions) }
                    },
                    onDelete: { sessions in
                        Task { await store.deleteCodexSessions(sessions) }
                    }
                )
                .frame(minWidth: 250, minHeight: 120, idealHeight: 180)
            }
            .frame(minWidth: 250, idealWidth: 300)
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showComponentSelector) {
            ComponentSelectorView(
                searchPaths: store.componentSearchPaths,
                onAdd: { selectedFolders in
                    Task { await store.addSelectedFolders(selectedFolders) }
                }
            )
        }
        .onChange(of: store.selectedWorkspace) { _, _ in
            Task { await store.loadFoldersForSelectedWorkspace(authManager: authManager) }
        }
        .onChange(of: store.folders) { _, _ in
            guard !store.isLoadingFolders else { return }
            Task {
                await store.saveFoldersToWorkspace(authManager: authManager)
                await store.loadCodexSessions()
            }
        }
        .task {
            store.refreshWorkspaces()
            await store.loadFoldersForSelectedWorkspace(authManager: authManager)
        }
    }
}

#Preview {
    MainWorkspaceView()
        .environmentObject(AuthorizationManager.shared)
        .frame(width: 800, height: 600)
}
