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
            Task { await store.saveFoldersToWorkspace(authManager: authManager) }
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
