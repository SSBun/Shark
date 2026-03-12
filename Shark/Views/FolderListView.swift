//
//  FolderListView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

struct FolderListView: View {
    @Binding var folders: [Folder]
    @State private var selectedFolderIDs: Set<Folder.ID> = []
    @State private var isTargeted = false
    let onAddFolder: (() -> Void)?
    let onUpdateFolder: ((Folder) -> Void)?
    let onSelectComponents: (() -> Void)?
    let onDropFolders: (([Folder]) -> Void)?

    init(folders: Binding<[Folder]>, onAddFolder: (() -> Void)? = nil, onUpdateFolder: ((Folder) -> Void)? = nil, onSelectComponents: (() -> Void)? = nil, onDropFolders: (([Folder]) -> Void)? = nil) {
        self._folders = folders
        self.onAddFolder = onAddFolder
        self.onUpdateFolder = onUpdateFolder
        self.onSelectComponents = onSelectComponents
        self.onDropFolders = onDropFolders
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add button
            HStack(spacing: 12) {
                Text("Folders")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()

                // Select Components button
                Button(action: {
                    onSelectComponents?()
                }) {
                    Image(systemName: "square.grid.3x1.below.line.grid.1x2")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Select components from search path")
                .disabled(onSelectComponents == nil)

                Button(action: {
                    onAddFolder?()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Add folder to workspace")
                .disabled(onAddFolder == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 36)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Folder list
            if folders.isEmpty {
                VStack {
                    Spacer()
                    Text("No folders")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $selectedFolderIDs) {
                    ForEach(folders) { folder in
                        FolderRow(
                            folder: folder,
                            selectedTargetsProvider: {
                                selectedTargets(for: folder)
                            },
                            onShowInFinder: {
                                showFolderInFinder(folder)
                            },
                            onDelete: {
                                if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                                    folders.remove(at: index)
                                }
                            },
                            onUpdate: { updatedFolder in
                                if let index = folders.firstIndex(where: { $0.id == updatedFolder.id }) {
                                    folders[index] = updatedFolder
                                    onUpdateFolder?(updatedFolder)
                                }
                            }
                        )
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                print("[FolderListView] Row clicked: \(folder.displayName ?? folder.name) (\(folder.path))")
                                Log.info("Folder row clicked: \(folder.displayName ?? folder.name)", category: .workspace)
                            }
                        )
                        .tag(folder.id)
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: folders) { _, newFolders in
                    let validIDs = Set(newFolders.map(\.id))
                    selectedFolderIDs = selectedFolderIDs.intersection(validIDs)
                }
            }
        }
        .overlay(
            Group {
                if isTargeted, onDropFolders != nil {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.1))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.accentColor)
                                Text("Drop folders here")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        )
                }
            }
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func showFolderInFinder(_ folder: Folder) {
        let folderURL = URL(fileURLWithPath: folder.path)
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
    }

    private func selectedTargets(for folder: Folder) -> [Folder] {
        if selectedFolderIDs.contains(folder.id), !selectedFolderIDs.isEmpty {
            return folders.filter { selectedFolderIDs.contains($0.id) }
        }
        return [folder]
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let onDropFolders = onDropFolders else { return }

        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard error == nil,
                      let data = item as? Data,
                      let urlString = String(data: data, encoding: .utf8),
                      let url = URL(string: urlString) else {
                    return
                }

                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    return
                }

                let folderPath = url.path
                let folderName = url.lastPathComponent

                // Check if folder already exists
                if folders.contains(where: { $0.path == folderPath }) {
                    return
                }

                // Create security-scoped bookmark
                var bookmarkData: Data? = nil
                do {
                    bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } catch {
                    print("Failed to create bookmark for \(folderPath): \(error)")
                }

                let newFolder = Folder(
                    name: folderName,
                    path: folderPath,
                    displayName: nil,
                    bookmarkData: bookmarkData
                )

                DispatchQueue.main.async {
                    onDropFolders([newFolder])
                }
            }
        }
    }
}

struct FolderRow: View {
    let folder: Folder
    let selectedTargetsProvider: (() -> [Folder])?
    let onShowInFinder: () -> Void
    let onDelete: () -> Void
    let onUpdate: (Folder) -> Void
    @State private var folderExists: Bool = true
    @State private var isGitRepo: Bool = false
    @State private var gitReference: GitReference? = nil
    @State private var xcodeProjectPath: String? = nil
    @State private var permissionDenied: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Folder icon with status indicators
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "folder.fill")
                    .foregroundColor(permissionDenied ? .orange : (folderExists ? .blue : .gray))
                    .font(.system(size: 14))
                
                // Permission badge indicator
                if permissionDenied {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 8))
                        .offset(x: 2, y: 2)
                        .background(
                            Circle()
                                .fill(Color(NSColor.windowBackgroundColor))
                                .frame(width: 10, height: 10)
                        )
                } else if isGitRepo && folderExists {
                    Image(systemName: "arrow.branch")
                        .foregroundColor(.blue)
                        .font(.system(size: 8))
                        .offset(x: 2, y: 2)
                        .background(
                            Circle()
                                .fill(Color(NSColor.windowBackgroundColor))
                                .frame(width: 10, height: 10)
                        )
                }
                
                // Warning indicator for missing folders
                if !folderExists {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 8))
                        .offset(x: 2, y: 2)
                }
            }
            .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(folder.displayName ?? folder.name)
                        .font(.system(size: 13))
                        .foregroundColor(permissionDenied ? .orange : (folderExists ? .primary : .secondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Git branch/tag badge
                    if let reference = gitReference, folderExists {
                        GitReferenceBadge(reference: reference)
                            .fixedSize()
                    }
                    
                    if permissionDenied {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                            .help("Permission denied. Click to grant access.")
                    } else if !folderExists {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                    }
                }
                
                Text(folder.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .strikethrough(!folderExists)
            }
            .allowsHitTesting(false)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Remove folder from workspace")
        }
        .padding(.vertical, 4)
        .opacity(folderExists ? 1.0 : 0.7)
        .contextMenu {
            // Top section - Actions
            Button(role: .destructive, action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text("Remove")
                }
            }

            if permissionDenied {
                Button(action: requestAccess) {
                    HStack {
                        Image(systemName: "lock.open")
                        Text("Grant Access...")
                    }
                }
                Divider()
            }

            Button(action: onShowInFinder) {
                HStack {
                    Image(systemName: "folder")
                    Text("Show in Finder")
                }
            }

            if folderExists {
                let targets = selectedTargetsProvider?() ?? [folder]
                let targetCount = targets.count

                Button(action: {
                    for target in targets {
                        TerminalOpener.openFolder(target.path)
                    }
                }) {
                    HStack {
                        Image(systemName: "terminal")
                        Text(targetCount > 1 ? "Open \(targetCount) in Terminal" : "Open in Terminal")
                    }
                }
            }

            if let xcodePath = xcodeProjectPath, folderExists {
                Button(action: {
                    XcodeOpener.openProject(at: xcodePath, bookmarkData: folder.bookmarkData)
                }) {
                    HStack {
                        Image(systemName: "hammer")
                        Text("Open with Xcode")
                    }
                }
            }

            // Bottom section - Git tools
            if isGitRepo && folderExists {
                Divider()
                let targets = selectedTargetsProvider?() ?? [folder]
                let targetCount = targets.count

                Button(action: {
                    for target in targets {
                        ForkOpener.openRepository(at: target.path)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.branch")
                        Text(targetCount > 1 ? "Open \(targetCount) in Fork" : "Open in Fork")
                    }
                }

                Button(action: {
                    for target in targets {
                        SourceTreeOpener.openRepository(at: target.path)
                    }
                }) {
                    HStack {
                        if let icon = SourceTreeOpener.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.triangle.branch")
                        }
                        Text(targetCount > 1 ? "Open \(targetCount) in SourceTree" : "Open in SourceTree")
                    }
                }
            }
        }
        .onAppear {
            checkFolderStatus()
        }
        .onChange(of: folder.path) { oldValue, newValue in
            checkFolderStatus()
        }
        .help(folderExists ? folder.path : "Folder not found on disk: \(folder.path)")
    }
    
    private func checkFolderStatus() {
        folderExists = folder.existsOnDisk
        isGitRepo = folder.isGitRepository
        xcodeProjectPath = folder.xcodeProjectPath
        
        // Get git reference in security context
        gitReference = getGitReferenceWithSecurityScope()
        
        // Check if we can actually read the directory
        let url = URL(fileURLWithPath: folder.path)
        var isAccessed = false
        
        // Try local bookmark first
        if let bookmarkData = folder.bookmarkData {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                isAccessed = bookmarkedURL.startAccessingSecurityScopedResource()
                if isAccessed {
                    defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                    permissionDenied = !(FileManager.default.isReadableFile(atPath: folder.path))
                }
            }
        }
        
        // Try global bookmark from SettingsManager if not already accessed
        if !isAccessed, let globalBookmarkData = SettingsManager.shared.bookmarkData(for: folder.path) {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: globalBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                isAccessed = bookmarkedURL.startAccessingSecurityScopedResource()
                if isAccessed {
                    defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                    permissionDenied = !(FileManager.default.isReadableFile(atPath: folder.path))
                }
            }
        }
        
        if !isAccessed {
            isAccessed = url.startAccessingSecurityScopedResource()
            if isAccessed {
                defer { url.stopAccessingSecurityScopedResource() }
                permissionDenied = !(FileManager.default.isReadableFile(atPath: folder.path))
            } else {
                // If we can't even start accessing, and it's not a standard path, it's likely denied
                permissionDenied = true
            }
        }
    }
    
    private func getGitReferenceWithSecurityScope() -> GitReference? {
        guard isGitRepo else { return nil }
        
        // Try to use bookmark data if available
        if let bookmarkData = folder.bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                // The bookmark can be a parent folder; always query the real repo path.
                return folder.getGitReference(at: folder.path)
            }
        }
        
        // Try global authorized folders from SettingsManager
        if let globalBookmarkData = SettingsManager.shared.bookmarkData(for: folder.path) {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: globalBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               bookmarkedURL.startAccessingSecurityScopedResource() {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                return folder.getGitReference(at: folder.path)
            }
        }
        
        let url = URL(fileURLWithPath: folder.path)
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return folder.getGitReference(at: folder.path)
    }
    
    private func requestAccess() {
        guard let url = FileDialogHelper.selectFolder(
            title: "Grant Access to Folder",
            message: "Shark needs permission to access this folder to check for Xcode projects and Git status.",
            initialPath: folder.path
        ) else {
            return
        }
        
        // Verify it's the same folder (or a parent)
        // For simplicity, we'll just update the bookmark for this folder
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            var updatedFolder = folder
            updatedFolder.bookmarkData = bookmarkData
            onUpdate(updatedFolder)
            
            // Refresh status
            permissionDenied = false
            checkFolderStatus()
        } catch {
            print("Failed to create bookmark: \(error)")
        }
    }
}

struct GitReferenceBadge: View {
    let reference: GitReference
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 9))
            Text(displayText)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(badgeColor)
        )
    }
    
    private var displayText: String {
        switch reference {
        case .branch(let branch): return branch
        case .tag(let tag): return tag
        }
    }
    
    private var iconName: String {
        switch reference {
        case .branch:
            return "arrow.branch"
        case .tag:
            return "tag.fill"
        }
    }
    
    private var badgeColor: Color {
        switch reference {
        case .tag:
            return Color(nsColor: .systemPink)
        case .branch(let branch):
            switch branch {
        case "main", "master":
            return Color(nsColor: .systemGreen)
        case "develop", "dev":
            return Color(nsColor: .systemBlue)
        case let b where b.hasPrefix("feature/"):
            return Color(nsColor: .systemPurple)
        case let b where b.hasPrefix("bugfix/") || b.hasPrefix("fix/"):
            return Color(nsColor: .systemOrange)
        case let b where b.hasPrefix("release/"):
            return Color(nsColor: .systemTeal)
        default:
            return Color(nsColor: .systemGray)
        }
        }
    }
}

#Preview {
    @Previewable @State var folders: [Folder] = [
        Folder(name: "Example", path: "/Users/example/Projects/Example", displayName: "Example Folder")
    ]
    
    FolderListView(folders: $folders)
        .frame(width: 300, height: 600)
}
