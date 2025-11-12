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
    
    init(folders: Binding<[Folder]>, onAddFolder: (() -> Void)? = nil) {
        self._folders = folders
        self.onAddFolder = onAddFolder
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add button
            HStack {
                Text("Folders")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
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
    @State private var folderExists: Bool = true
    @State private var isGitRepo: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Folder icon with status indicators
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "folder.fill")
                    .foregroundColor(folderExists ? .blue : .gray)
                    .font(.system(size: 14))
                
                // Git badge indicator
                if isGitRepo && folderExists {
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
                        .foregroundColor(folderExists ? .primary : .secondary)
                    
                    if !folderExists {
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
            Button(action: onShowInFinder) {
                HStack {
                    Image(systemName: "folder")
                    Text("Show in Finder")
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
    }
}

#Preview {
    @Previewable @State var folders: [Folder] = [
        Folder(name: "Example", path: "/Users/example/Projects/Example", displayName: "Example Folder")
    ]
    
    FolderListView(folders: $folders)
        .frame(width: 300, height: 600)
}

