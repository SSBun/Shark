//
//  WorkspaceListView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

struct WorkspaceListView: View {
    @Binding var workspaces: [Workspace]
    @Binding var selectedWorkspace: Workspace?
    @EnvironmentObject var authManager: AuthorizationManager
    @State private var lastSelectedWorkspace: Workspace?
    @State private var lastSelectionTime: Date?
    @State private var searchText: String = ""
    @State private var isSearchFocused: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @Binding var isRefreshingVenomfiles: Bool
    @State private var workspaceToRemove: Workspace?

    let onRefreshAllVenomfiles: (() -> Void)?

    private var filteredWorkspaces: [Workspace] {
        if searchText.isEmpty {
            return workspaces
        }
        let lowercased = searchText.lowercased()
        return workspaces.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.filePath.lowercased().contains(lowercased)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Add and Import buttons
            HStack {
                Text("Workspaces")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()

                // Refresh button
                Button(action: {
                    onRefreshAllVenomfiles?()
                }) {
                    if isRefreshingVenomfiles {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .help("Refresh Venomfiles status for all components")
                .disabled(isRefreshingVenomfiles)

                // Search button (⌘F)
                Button(action: {
                    isSearchFocused = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Search workspaces (⌘F)")

                Button(action: {
                    createWorkspace()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Create virtual workspace")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 36)
            .background(Color(NSColor.controlBackgroundColor))

            // Search bar (shown when ⌘F pressed)
            if isSearchFocused {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    TextField("Search workspaces...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            isSearchFocused = false
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Cancel") {
                        searchText = ""
                        isSearchFocused = false
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .onAppear {
                    isTextFieldFocused = true
                }
            }

            Divider()

            // Workspace list
            if filteredWorkspaces.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedWorkspace) {
                    ForEach(filteredWorkspaces) { workspace in
                        makeWorkspaceRow(workspace, isPinned: workspace.isPinned)
                            .tag(workspace)
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedWorkspace) { oldValue, newValue in
                    // Handle double-click detection
                    if let newValue = newValue {
                        let now = Date()
                        if let lastTime = lastSelectionTime,
                           let lastSelected = lastSelectedWorkspace,
                           lastSelected.id == newValue.id,
                           now.timeIntervalSince(lastTime) < 0.5 {
                            WorkspaceOpener.openWorkspace(newValue)
                        }
                        lastSelectedWorkspace = newValue
                        lastSelectionTime = now
                    }
                }
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .confirmationDialog(
            "Remove Workspace",
            isPresented: Binding(
                get: { workspaceToRemove != nil },
                set: { if !$0 { workspaceToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let workspace = workspaceToRemove {
                    removeWorkspace(workspace)
                    workspaceToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) {
                workspaceToRemove = nil
            }
        } message: {
            Text("Are you sure you want to remove \"\(workspaceToRemove?.name ?? "")\"?")
        }
    }

    @ViewBuilder
    private func makeWorkspaceRow(_ workspace: Workspace, isPinned: Bool) -> some View {
        WorkspaceRow(
            workspace: workspace,
            isPinned: isPinned,
            onTogglePin: { togglePin(workspace) },
            onOpen: {
                WorkspaceOpener.openWorkspace(workspace)
            },
            onShowInFinder: {
                showWorkspaceInFinder(workspace)
            },
            onRename: { newName in
                renameWorkspace(workspace, to: newName)
            },
            onRemove: {
                workspaceToRemove = workspace
            },
            onOpenInForkWorkspace: {
                openInForkWorkspace(workspace)
            },
            onOpenInSourceTree: {
                openGitFoldersInSourceTree(workspace)
            }
        )
    }

    private func togglePin(_ workspace: Workspace) {
        WorkspaceManager.shared.togglePin(workspace)
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.keyCode == 3 {
                DispatchQueue.main.async {
                    isSearchFocused = true
                }
                return nil
            }
            return event
        }
    }

    private func createWorkspace() {
        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else { return }

            do {
                let workspace = try WorkspaceManager.shared.createWorkspace()
                await MainActor.run {
                    workspaces.append(workspace)
                    selectedWorkspace = workspace
                    WorkspaceManager.shared.addWorkspace(workspace)
                }
            } catch {
                print("Failed to create workspace: \(error)")
            }
        }
    }

    private func renameWorkspace(_ workspace: Workspace, to newName: String) {
        do {
            let updatedWorkspace = try WorkspaceManager.shared.renameWorkspace(workspace, to: newName)

            if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[index] = updatedWorkspace

                if selectedWorkspace?.id == workspace.id {
                    selectedWorkspace = updatedWorkspace
                }
            }
        } catch {
            print("Failed to rename workspace: \(error)")
        }
    }

    private func showWorkspaceInFinder(_ workspace: Workspace) {
        let fileURL = URL(fileURLWithPath: workspace.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func removeWorkspace(_ workspace: Workspace) {
        Task {
            workspaces.removeAll { $0.id == workspace.id }
            WorkspaceManager.shared.removeWorkspace(workspace)

            if selectedWorkspace?.id == workspace.id {
                selectedWorkspace = nil
            }

            let settingsManager = SettingsManager.shared
            let settingsFolderPath = settingsManager.settingsFolderPath

            if workspace.filePath.hasPrefix(settingsFolderPath) {
                do {
                    try FileManager.default.removeItem(atPath: workspace.filePath)
                } catch {
                    print("Could not delete workspace: \(error)")
                }
            }
        }
    }

    private func openInForkWorkspace(_ workspace: Workspace) {
        Log.info("openInForkWorkspace called: \(workspace.name)", category: .workspace)
        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                Log.error("Authorization denied for Fork workspace open", category: .workspace)
                return
            }

            do {
                let repoPaths = try WorkspaceManager.shared.gitRepoPaths(for: workspace)

                Log.info("Found \(repoPaths.count) git repo paths", category: .workspace)
                guard !repoPaths.isEmpty else {
                    await MainActor.run {
                        AlertManager.shared.show(type: .warning, title: "No Git Repos", message: "No git repositories found in this workspace.")
                    }
                    return
                }

                let result = try await ForkWorkspaceManager.findOrCreateAndOpen(named: workspace.name, repoPaths: repoPaths)

                await MainActor.run {
                    let message = result.created
                        ? "Created Fork workspace '\(workspace.name)' with \(repoPaths.count) repos."
                        : "Switched to Fork workspace '\(workspace.name)' with \(repoPaths.count) repos."
                    AlertManager.shared.show(type: .info, title: "Fork Workspace", message: message)
                }
            } catch {
                Log.error("openInForkWorkspace error: \(error)", category: .workspace)
                await MainActor.run {
                    AlertManager.shared.show(type: .error, title: "Error", message: "Failed to open Fork workspace: \(error.localizedDescription)")
                }
            }
        }
    }

    private func openGitFoldersInSourceTree(_ workspace: Workspace) {
        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }

            do {
                for path in try WorkspaceManager.shared.gitRepoPaths(for: workspace) {
                    SourceTreeOpener.openRepository(at: path)
                }
            } catch {
                print("Failed to load workspace: \(error)")
            }
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)? = nil
    let onOpen: () -> Void
    let onShowInFinder: () -> Void
    let onRename: (String) -> Void
    let onRemove: () -> Void
    let onOpenInForkWorkspace: (() -> Void)?
    let onOpenInSourceTree: (() -> Void)?

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Workspace name", text: $editedName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(2)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            cancelRename()
                        }
                } else {
                    HStack(spacing: 4) {
                        Text(workspace.name)
                            .font(.system(size: 14, weight: .medium))
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                }
                Text(workspace.filePath)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Open button on the right
            Button(action: onOpen) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1.0 : 0.6)
            .help(openActionLabel)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onChange(of: isTextFieldFocused) { oldValue, newValue in
            if !newValue && isEditing {
                commitRename()
            }
        }
        .contextMenu {
            if let onTogglePin {
                Button(action: onTogglePin) {
                    HStack {
                        Image(systemName: isPinned ? "pin.slash" : "pin")
                        Text(isPinned ? "Unpin" : "Pin to Top")
                    }
                }
            }

            if let onOpenInForkWorkspace {
                Button(action: onOpenInForkWorkspace) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                        Text("Open In Fork Workspace")
                    }
                }
            }

            Button(action: onShowInFinder) {
                HStack {
                    Image(systemName: "folder")
                    Text("Show in Finder")
                }
            }

            Button(action: {
                startEditing()
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Rename")
                }
            }

            Divider()

            if let onOpenInSourceTree {
                Button(action: {
                    onOpenInSourceTree()
                }) {
                    HStack {
                        if let icon = SourceTreeOpener.appIcon { Image(nsImage: icon).resizable().frame(width: 14, height: 14) } else { Image(systemName: "arrow.triangle.branch") }
                        Text("Open in SourceTree")
                    }
                }
            }

            Button(role: .destructive, action: onRemove) {
                HStack {
                    Image(systemName: "trash")
                    Text("Remove")
                }
            }
        }
    }

    private var openActionLabel: String {
        "Open virtual workspace"
    }

    private func startEditing() {
        editedName = workspace.name
        isEditing = true
        isTextFieldFocused = true
    }

    private func commitRename() {
        guard isEditing else { return }
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != workspace.name {
            onRename(trimmedName)
        }
        isEditing = false
        isTextFieldFocused = false
    }

    private func cancelRename() {
        isEditing = false
        isTextFieldFocused = false
        editedName = workspace.name
    }

}
