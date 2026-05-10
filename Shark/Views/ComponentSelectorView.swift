//
//  ComponentSelectorView.swift
//  Shark
//
//  Created by caishilin on 2026/01/29.
//

import SwiftUI

struct ComponentSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var allFolders: [Folder] = []
    @State private var selectedFolderPaths: Set<String> = []
    @State private var isLoading = false
    
    let searchPaths: [String]
    let onAdd: ([Folder]) -> Void
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return allFolders
        } else {
            return allFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Components")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search folders...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // List
            if isLoading {
                Spacer()
                ProgressView("Scanning folders...")
                Spacer()
            } else if allFolders.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(searchPaths.isEmpty ? "No search paths configured" : "No folders found in search paths")
                        .foregroundColor(.secondary)
                    if !searchPaths.isEmpty {
                        Text(searchPaths.joined(separator: "\n"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                Spacer()
            } else {
                List(filteredFolders, id: \.path) { folder in
                    HStack {
                        Button(action: {
                            toggleSelection(for: folder.path)
                        }) {
                            Image(systemName: selectedFolderPaths.contains(folder.path) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedFolderPaths.contains(folder.path) ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(folder.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(folder.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection(for: folder.path)
                    }
                    .contextMenu {
                        let targetPaths = selectedTargetPaths(for: folder)
                        let targetCount = targetPaths.count

                        Button(action: {
                            copyPaths(targetPaths)
                        }) {
                            Label(
                                targetCount > 1 ? "Copy \(targetCount) Paths" : "Copy Path",
                                systemImage: "doc.on.doc"
                            )
                        }

                        Divider()

                        Button(action: {
                            openInFork(paths: targetPaths)
                        }) {
                            Label(
                                targetCount > 1 ? "Open \(targetCount) in Fork" : "Open in Fork",
                                systemImage: "arrow.branch"
                            )
                        }

                        Button(action: {
                            openInSourceTree(paths: targetPaths)
                        }) {
                            HStack {
                                if let icon = SourceTreeOpener.appIcon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "arrow.triangle.branch")
                                }
                                Text(targetCount > 1 ? "Open \(targetCount) in SourceTree" : "Open in SourceTree")
                            }
                        }

                        Button(action: {
                            openInTerminal(paths: targetPaths)
                        }) {
                            Label(
                                targetCount > 1 ? "Open \(targetCount) in Terminal" : "Open in Terminal",
                                systemImage: "terminal"
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(selectedFolderPaths.count) selected")
                    .foregroundColor(.secondary)
                Spacer()
                Button("Add Selected") {
                    let selected = allFolders.filter { selectedFolderPaths.contains($0.path) }
                    onAdd(selected)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFolderPaths.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            scanFolders()
        }
    }
    
    private func scanFolders() {
        guard !searchPaths.isEmpty else {
            allFolders = []
            return
        }
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            var allFound: [Folder] = []
            var seenPaths = Set<String>()

            for path in searchPaths {
                let url = URL(fileURLWithPath: path)
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let contents = try fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )

                    for itemURL in contents {
                        var isDir: ObjCBool = false
                        guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
                        guard !seenPaths.contains(itemURL.path) else { continue }
                        seenPaths.insert(itemURL.path)
                        allFound.append(Folder(
                            name: itemURL.lastPathComponent,
                            path: itemURL.path,
                            displayName: nil
                        ))
                    }
                } catch {
                    print("Error scanning directory \(path): \(error)")
                }
            }

            allFound.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.allFolders = allFound
                self.isLoading = false
            }
        }
    }
    
    private func selectedTargetPaths(for folder: Folder) -> [String] {
        if selectedFolderPaths.contains(folder.path), !selectedFolderPaths.isEmpty {
            return selectedFolderPaths.sorted()
        }
        return [folder.path]
    }
    
    private func toggleSelection(for path: String) {
        if selectedFolderPaths.contains(path) {
            selectedFolderPaths.remove(path)
        } else {
            selectedFolderPaths.insert(path)
        }
    }
    
    private func copyPaths(_ paths: [String]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    private func openInFork(paths: [String]) {
        for path in paths {
            ForkOpener.openRepository(at: path)
        }
    }

    private func openInSourceTree(paths: [String]) {
        for path in paths {
            SourceTreeOpener.openRepository(at: path)
        }
    }

    private func openInTerminal(paths: [String]) {
        for path in paths {
            TerminalOpener.openFolder(path)
        }
    }
}
