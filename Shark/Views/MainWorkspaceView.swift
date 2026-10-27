//
//  MainWorkspaceView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

struct MainWorkspaceView: View {
    @State private var store = WorkspaceStore()
    @State private var showComponentSelector = false
    @EnvironmentObject var authManager: AuthorizationManager
    @Environment(CodexSessionPreviewStore.self) private var sessionPreviewStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var store = store

        HSplitView {
            WorkspaceListView(store: store)
                .environmentObject(authManager)
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)

            VSplitView {
                if store.selectedWorkspace?.kind != .project {
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
                }

                CodexSessionListView(
                    sessions: store.codexSessions,
                    isLoading: store.isLoadingCodexSessions,
                    canRename: store.selectedWorkspace?.kind == .workspace,
                    onRefresh: {
                        Task { await store.loadCodexSessions() }
                    },
                    onPreview: previewCodexSession,
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
                    onArchive: { sessions, archived in
                        Task { await store.setCodexSessions(sessions, archived: archived) }
                    },
                    onDelete: { sessions in
                        Task { await store.deleteCodexSessions(sessions) }
                    },
                    onCleanArchived: {
                        Task { await store.deleteAllArchivedCodexSessions() }
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await store.loadCodexSessions() }
        }
        .onReceive(NotificationCenter.default.publisher(for: SettingsManager.codexSessionFilterChangedNotification)) { _ in
            Task { await store.loadCodexSessions() }
        }
    }

    private func previewCodexSession(_ session: CodexSession) {
        sessionPreviewStore.loadPreview(for: session)
        openWindow(id: CodexSessionPreviewView.windowID)
    }
}

#Preview {
    MainWorkspaceView()
        .environmentObject(AuthorizationManager.shared)
        .environment(CodexSessionPreviewStore())
        .frame(width: 800, height: 600)
}
