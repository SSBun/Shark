//
//  WorkspaceListView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

struct WorkspaceListView: View {
    @Bindable var store: WorkspaceStore
    @EnvironmentObject var authManager: AuthorizationManager
    @State private var lastSelectedWorkspace: Workspace?
    @State private var lastSelectionTime: Date?
    @State private var searchText: String = ""
    @State private var isSearchFocused: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var workspaceToRemove: Workspace?
    @State private var healthReport: WorkspaceHealthReport?

    private var filteredWorkspaces: [Workspace] {
        if searchText.isEmpty {
            return store.workspaces
        }
        let lowercased = searchText.lowercased()
        return store.workspaces.filter {
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
                    Task { await store.refreshAllVenomfilesStatus(authManager: authManager) }
                }) {
                    if store.isRefreshingVenomfiles {
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
                .disabled(store.isRefreshingVenomfiles)

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
                    Task { await store.createWorkspace(authManager: authManager) }
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
                List(selection: $store.selectedWorkspace) {
                    ForEach(filteredWorkspaces) { workspace in
                        makeWorkspaceRow(workspace, isPinned: workspace.isPinned)
                            .tag(workspace)
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: store.selectedWorkspace) { oldValue, newValue in
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
                    store.removeWorkspace(workspace)
                    workspaceToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) {
                workspaceToRemove = nil
            }
        } message: {
            Text("Are you sure you want to remove \"\(workspaceToRemove?.name ?? "")\"?")
        }
        .sheet(item: $healthReport) { report in
            WorkspaceHealthView(
                report: report,
                onRevealWorkspace: {
                    showWorkspaceInFinder(report.workspace)
                },
                onRecreateSymlinks: {
                    repairSymlinks(for: report.workspace, removingMissingLinks: false)
                },
                onRemoveMissingLinks: {
                    guard confirmRemoveMissingLinks(count: report.missingLinkCount) else { return }
                    repairSymlinks(for: report.workspace, removingMissingLinks: true)
                }
            )
        }
    }

    @ViewBuilder
    private func makeWorkspaceRow(_ workspace: Workspace, isPinned: Bool) -> some View {
        WorkspaceRow(
            workspace: workspace,
            isPinned: isPinned,
            onTogglePin: { store.togglePin(workspace) },
            onOpen: {
                WorkspaceOpener.openWorkspace(workspace)
            },
            onShowInFinder: {
                store.showWorkspaceInFinder(workspace)
            },
            onRename: { newName in
                store.renameWorkspace(workspace, to: newName)
            },
            onRemove: {
                workspaceToRemove = workspace
            },
            onCheckHealth: {
                healthReport = WorkspaceHealthReport.inspect(workspace)
            },
            onOpenInForkWorkspace: {
                Task { await store.openInForkWorkspace(workspace, authManager: authManager) }
            },
            onOpenInSourceTree: {
                Task { await store.openGitFoldersInSourceTree(workspace, authManager: authManager) }
            }
        )
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

    private func showWorkspaceInFinder(_ workspace: Workspace) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: workspace.filePath)])
    }

    private func repairSymlinks(for workspace: Workspace, removingMissingLinks: Bool) {
        do {
            let dirURL = URL(fileURLWithPath: workspace.filePath)
            var workspaceFile = try VirtualWorkspaceFile.parse(fromDirectory: dirURL)
            if removingMissingLinks {
                workspaceFile.links.removeAll { !FileManager.default.fileExists(atPath: $0.originalPath) }
            }
            workspaceFile.links = try SymlinkManager.recreateAllSymlinks(links: workspaceFile.links, in: workspace.filePath)
            try workspaceFile.save(toDirectory: dirURL)
            healthReport = WorkspaceHealthReport.inspect(workspace)
            if store.selectedWorkspace?.id == workspace.id {
                Task { await store.loadFoldersForSelectedWorkspace(authManager: authManager) }
            }
        } catch {
            print("Failed to repair workspace health: \(error)")
        }
    }

    private func confirmRemoveMissingLinks(count: Int) -> Bool {
        guard count > 0 else { return false }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove \(count) missing folder link\(count == 1 ? "" : "s")?"
        alert.informativeText = "This updates the workspace metadata and recreates symlinks."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
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
    let onCheckHealth: () -> Void
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

            Button(action: onCheckHealth) {
                HStack {
                    Image(systemName: "stethoscope")
                    Text("Check Health...")
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

private struct WorkspaceHealthView: View {
    let report: WorkspaceHealthReport
    let onRevealWorkspace: () -> Void
    let onRecreateSymlinks: () -> Void
    let onRemoveMissingLinks: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workspace Health")
                    .font(.headline)
                Spacer()
            }

            Text(report.workspaceName)
                .font(.subheadline)
                .foregroundColor(.secondary)

            List(report.items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.status.systemImage)
                        .foregroundColor(item.status.color)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                        if !item.detail.isEmpty {
                            Text(item.detail)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)

            HStack {
                Button("Reveal", systemImage: "folder", action: onRevealWorkspace)
                Spacer()
                Button("Recreate Symlinks", systemImage: "arrow.triangle.2.circlepath", action: onRecreateSymlinks)
                    .disabled(!report.canRepairSymlinks)
                Button("Remove Missing Links", systemImage: "minus.circle", action: onRemoveMissingLinks)
                    .disabled(report.missingLinkCount == 0)
            }
        }
        .padding(16)
        .frame(width: 560, height: 400)
    }
}

private struct WorkspaceHealthReport: Identifiable {
    let id = UUID()
    let workspace: Workspace
    let workspaceName: String
    let missingLinkCount: Int
    let canRepairSymlinks: Bool
    let items: [WorkspaceHealthItem]

    static func inspect(_ workspace: Workspace) -> WorkspaceHealthReport {
        let fileManager = FileManager.default
        let workspaceExists = fileManager.fileExists(atPath: workspace.filePath)
        let metadataURL = VirtualWorkspaceFile.metadataURL(in: URL(fileURLWithPath: workspace.filePath))
        let workspaceFile = metadataURL.flatMap { try? VirtualWorkspaceFile.parse(from: $0) }
        let links = workspaceFile?.links ?? []
        let missingLinks = links.filter { !fileManager.fileExists(atPath: $0.originalPath) }
        let brokenSymlinks = workspaceExists ? SymlinkManager.validateSymlinks(in: workspace.filePath) : []
        let unexpectedSymlinks = workspaceExists ? symlinkNames(in: workspace.filePath).subtracting(links.map(\.symlinkName)) : []

        return WorkspaceHealthReport(
            workspace: workspace,
            workspaceName: workspace.name,
            missingLinkCount: missingLinks.count,
            canRepairSymlinks: workspaceExists && workspaceFile != nil,
            items: [
            WorkspaceHealthItem(
                title: "Workspace Directory",
                detail: workspace.filePath,
                status: workspaceExists ? .ok : .error
            ),
            WorkspaceHealthItem(
                title: "Metadata",
                detail: metadataURL?.path ?? "Missing .shark-workspace.json",
                status: workspaceFile == nil ? .error : .ok
            ),
            WorkspaceHealthItem(
                title: "Linked Folders",
                detail: missingLinks.isEmpty ? "\(links.count) configured" : "\(missingLinks.count) missing",
                status: missingLinks.isEmpty ? .ok : .warning
            ),
            WorkspaceHealthItem(
                title: "Symlinks",
                detail: brokenSymlinks.isEmpty ? "No broken symlinks" : "\(brokenSymlinks.count) broken",
                status: brokenSymlinks.isEmpty ? .ok : .warning
            ),
            WorkspaceHealthItem(
                title: "Unexpected Symlinks",
                detail: unexpectedSymlinks.isEmpty ? "None" : unexpectedSymlinks.sorted().joined(separator: ", "),
                status: unexpectedSymlinks.isEmpty ? .ok : .warning
            ),
            WorkspaceHealthItem(
                title: "Codex Hooks",
                detail: CodexHookInstaller.isInstalled ? "Installed" : "Not installed",
                status: CodexHookInstaller.isInstalled ? .ok : .warning
            )
        ])
    }

    private static func symlinkNames(in workspacePath: String) -> Set<String> {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: workspacePath) else { return [] }
        return Set(contents.compactMap { item in
            guard !item.hasPrefix(".") else { return nil }
            let path = (workspacePath as NSString).appendingPathComponent(item)
            return (try? fileManager.destinationOfSymbolicLink(atPath: path)) == nil ? nil : item
        })
    }
}

private struct WorkspaceHealthItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let status: WorkspaceHealthStatus
}

private enum WorkspaceHealthStatus {
    case ok
    case warning
    case error

    var systemImage: String {
        switch self {
        case .ok:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
