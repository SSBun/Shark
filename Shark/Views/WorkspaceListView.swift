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
    @State private var showWorkspaceTypePicker = false

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

                // Import button
                Button(action: {
                    importWorkspace()
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Import existing workspace")

                // Add button with type picker
                Button(action: {
                    showWorkspaceTypePicker = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Create new workspace (⌘N)")
                .popover(isPresented: $showWorkspaceTypePicker, arrowEdge: .bottom) {
                    VStack(spacing: 6) {
                        Button(action: {
                            showWorkspaceTypePicker = false
                            createNewWorkspace()
                        }) {
                            Label("Cursor Workspace", systemImage: "cursor.rays")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        Divider()

                        Button(action: {
                            showWorkspaceTypePicker = false
                            createClaudeWorkspace()
                        }) {
                            Label("Claude Code Workspace", systemImage: "terminal.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .padding(.vertical, 8)
                    .frame(width: 200)
                }
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
                        WorkspaceRow(
                            workspace: workspace,
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
                                removeWorkspace(workspace)
                            },
                            onOpenInFork: {
                                openGitFoldersInFork(workspace)
                            },
                            onDuplicate: {
                                duplicateWorkspace(workspace)
                            }
                        )
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

    private func createNewWorkspace() {
        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }

            let settingsManager = SettingsManager.shared

            do {
                let url = try settingsManager.getNewWorkspaceURL()
                let emptyWorkspace = CursorWorkspaceFile.createEmpty()
                try emptyWorkspace.save(to: url)

                let filePath = url.path
                let newWorkspace = emptyWorkspace.toWorkspace(filePath: filePath)
                await MainActor.run {
                    workspaces.append(newWorkspace)
                    selectedWorkspace = newWorkspace
                    WorkspaceManager.shared.addWorkspace(newWorkspace)
                }
            } catch {
                print("Failed to create workspace file: \(error)")
            }
        }
    }

    private func createClaudeWorkspace() {
        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else { return }

            do {
                let workspace = try WorkspaceManager.shared.createClaudeWorkspace()
                await MainActor.run {
                    workspaces.append(workspace)
                    selectedWorkspace = workspace
                    WorkspaceManager.shared.addWorkspace(workspace)
                }
            } catch {
                print("Failed to create Claude workspace: \(error)")
            }
        }
    }

    private func importWorkspace() {
        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }

            guard let url = FileDialogHelper.selectWorkspaceFile() else {
                return
            }

            // Check if it's a .code-workspace file
            if url.pathExtension == "code-workspace" {
                do {
                    let workspaceFile = try CursorWorkspaceFile.parse(from: url)
                    let filePath = url.path
                    let workspace = workspaceFile.toWorkspace(filePath: filePath)

                    await MainActor.run {
                        if workspaces.contains(where: { $0.filePath == workspace.filePath }) {
                            return
                        }
                        workspaces.append(workspace)
                        selectedWorkspace = workspace
                        WorkspaceManager.shared.addWorkspace(workspace)
                    }
                } catch {
                    print("Failed to import workspace file: \(error)")
                }
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

    private func duplicateWorkspace(_ workspace: Workspace) {
        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else { return }

            do {
                let newWorkspace: Workspace
                switch workspace.type {
                case .cursor:
                    newWorkspace = try WorkspaceManager.shared.duplicateAsClaude(workspace)
                case .claude:
                    newWorkspace = try WorkspaceManager.shared.duplicateAsCursor(workspace)
                }
                await MainActor.run {
                    workspaces.append(newWorkspace)
                    selectedWorkspace = newWorkspace
                    WorkspaceManager.shared.addWorkspace(newWorkspace)
                    AlertManager.shared.show(type: .success, title: "Duplicated", message: "Duplicated as \(newWorkspace.type.displayName) workspace")
                }
            } catch {
                AlertManager.shared.show(type: .error, title: "Error", message: "Failed to duplicate workspace: \(error.localizedDescription)")
            }
        }
    }

    private func openGitFoldersInFork(_ workspace: Workspace) {
        guard workspace.type == .cursor else { return }

        Task {
            let authorized = await authManager.requireAuthorization(for: .fileSystemAccess)
            guard authorized else {
                return
            }

            do {
                let fileURL = URL(fileURLWithPath: workspace.filePath)
                let workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                let folders = workspaceFile.toFolders()

                for folder in folders {
                    if folder.isGitRepository {
                        ForkOpener.openRepository(at: folder.path)
                    }
                }
            } catch {
                print("Failed to load workspace file: \(error)")
            }
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    let onOpen: () -> Void
    let onShowInFinder: () -> Void
    let onRename: (String) -> Void
    let onRemove: () -> Void
    let onOpenInFork: () -> Void
    let onDuplicate: (() -> Void)?

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Workspace type icon
            Image(systemName: workspace.type.systemImageName)
                .font(.system(size: 12))
                .foregroundColor(workspace.type == .cursor ? .blue : .orange)

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
                    Text(workspace.name)
                        .font(.system(size: 14, weight: .medium))
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
            Button(role: .destructive, action: onRemove) {
                HStack {
                    Image(systemName: "trash")
                    Text("Remove")
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

            if let onDuplicate {
                Button(action: onDuplicate) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text(workspace.type == .cursor ? "Duplicate as Claude Workspace" : "Duplicate as Cursor Workspace")
                    }
                }
            }

            if workspace.type == .cursor {
                // Git tools only for Cursor workspaces
                Button(action: onOpenInFork) {
                    HStack {
                        Image(systemName: "arrow.branch")
                        Text("Open in Fork")
                    }
                }

                Button(action: {
                    openGitFoldersInSourceTree()
                }) {
                    HStack {
                        if let icon = SourceTreeOpener.appIcon { Image(nsImage: icon).resizable().frame(width: 14, height: 14) } else { Image(systemName: "arrow.triangle.branch") }
                        Text("Open in SourceTree")
                    }
                }
            }
        }
    }

    private var openActionLabel: String {
        switch workspace.type {
        case .cursor:
            return "Open workspace in \(SettingsManager.shared.defaultIDEApp.displayName)"
        case .claude:
            return "Open workspace in Terminal with claude"
        }
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

    private func openGitFoldersInSourceTree() {
        guard workspace.type == .cursor else { return }

        Task {
            let fileURL = URL(fileURLWithPath: workspace.filePath)
            do {
                let workspaceFile = try CursorWorkspaceFile.parse(from: fileURL)
                let folders = workspaceFile.toFolders()

                for folder in folders {
                    if folder.isGitRepository {
                        SourceTreeOpener.openRepository(at: folder.path)
                    }
                }
            } catch {
                print("Failed to load workspace file: \(error)")
            }
        }
    }
}
