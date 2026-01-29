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
    let onAddFolder: (() -> Void)?
    let onUpdateFolder: ((Folder) -> Void)?
    let onSelectComponents: (() -> Void)?
    
    init(folders: Binding<[Folder]>, onAddFolder: (() -> Void)? = nil, onUpdateFolder: ((Folder) -> Void)? = nil, onSelectComponents: (() -> Void)? = nil) {
        self._folders = folders
        self.onAddFolder = onAddFolder
        self.onUpdateFolder = onUpdateFolder
        self.onSelectComponents = onSelectComponents
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
                List {
                    ForEach(folders) { folder in
                        FolderRow(
                            folder: folder,
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
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
    
    private func showFolderInFinder(_ folder: Folder) {
        let folderURL = URL(fileURLWithPath: folder.path)
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
    }
}

struct FolderRow: View {
    let folder: Folder
    let onShowInFinder: () -> Void
    let onDelete: () -> Void
    let onUpdate: (Folder) -> Void
    @State private var folderExists: Bool = true
    @State private var isGitRepo: Bool = false
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
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(folder.displayName ?? folder.name)
                        .font(.system(size: 13))
                        .foregroundColor(permissionDenied ? .orange : (folderExists ? .primary : .secondary))
                    
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
            
            if isGitRepo && folderExists {
                Divider()
                
                Button(action: {
                    ForkOpener.openRepository(at: folder.path)
                }) {
                    HStack {
                        Image(systemName: "arrow.branch")
                        Text("Open in Fork")
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

#Preview {
    @Previewable @State var folders: [Folder] = [
        Folder(name: "Example", path: "/Users/example/Projects/Example", displayName: "Example Folder")
    ]
    
    FolderListView(folders: $folders)
        .frame(width: 300, height: 600)
}

