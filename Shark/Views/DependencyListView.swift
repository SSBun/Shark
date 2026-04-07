//
//  DependencyListView.swift
//  Shark
//
//  Created by caishilin on 2026/04/01.
//

import SwiftUI

struct DependencyListView: View {
    @Environment(\.dismiss) var dismiss
    let folder: Folder
    @State private var dependencies: [VenomDependency] = []
    @State private var localDependencies: [VenomDependency] = []
    @State private var searchText = ""
    @State private var isLoading = false

    var filteredDependencies: [VenomDependency] {
        if searchText.isEmpty {
            return dependencies
        } else {
            return dependencies.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.git.localizedCaseInsensitiveContains(searchText) ||
                $0.tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var filteredLocalDependencies: [VenomDependency] {
        if searchText.isEmpty {
            return localDependencies
        } else {
            return localDependencies.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.localPath?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dependencies")
                        .font(.headline)
                    Text(folder.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") {
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
                TextField("Search dependencies...", text: $searchText)
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
                ProgressView("Loading dependencies...")
                Spacer()
            } else if dependencies.isEmpty && localDependencies.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No dependencies found")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if filteredDependencies.isEmpty && filteredLocalDependencies.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No matching dependencies")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    // Developing Dependencies Section
                    if !localDependencies.isEmpty {
                        Section {
                            ForEach(filteredLocalDependencies) { dependency in
                                LocalDependencyRow(dependency: dependency)
                                    .padding(.vertical, 4)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12))
                                Text("Developing Dependencies")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(filteredLocalDependencies.count)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.orange.opacity(0.15))
                                    )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.orange.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.orange.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }

                    // Regular Dependencies Section
                    if !dependencies.isEmpty {
                        Section {
                            ForEach(filteredDependencies) { dependency in
                                DependencyRow(dependency: dependency)
                                    .padding(.vertical, 4)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "shippingbox")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                                Text("Dependencies")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(filteredDependencies.count)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.blue.opacity(0.15))
                                    )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.blue.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.blue.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            HStack {
                let totalFiltered = filteredDependencies.count + filteredLocalDependencies.count
                let total = dependencies.count + localDependencies.count
                Text("\(totalFiltered) of \(total) dependencies")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear {
            loadDependencies()
        }
    }

    private func loadDependencies() {
        isLoading = true
        Log.info("Opening dependency list for: \(folder.name) (path: \(folder.path))", category: .workspace)

        DispatchQueue.global(qos: .userInitiated).async {
            let deps = VenomfileParser.parseDependencies(from: folder)
            let localDeps = VenomfileParser.parseLocalDependencies(from: folder)
            DispatchQueue.main.async {
                self.dependencies = deps
                self.localDependencies = localDeps
                self.isLoading = false

                if deps.isEmpty && localDeps.isEmpty {
                    Log.info("No dependencies found for: \(folder.name). Venomfiles check: \(folder.hasVenomfiles)", category: .workspace)

                    // Try to diagnose why empty
                    let venomfilesPath = (folder.path as NSString).appendingPathComponent("Venomfiles")
                    var isDir: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: venomfilesPath, isDirectory: &isDir)
                    Log.debug("Venomfiles path: \(venomfilesPath), exists: \(exists), isDirectory: \(isDir.boolValue)", category: .workspace)
                } else {
                    Log.info("Loaded \(deps.count) dependencies and \(localDeps.count) local dependencies for: \(folder.name)", category: .workspace)
                }
            }
        }
    }
}

struct LocalDependencyRow: View {
    let dependency: VenomDependency
    @State private var gitBranch: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "hammer")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))

                Text(dependency.name)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                // Show git branch if available, otherwise show "local" badge
                if let branch = gitBranch, !branch.isEmpty {
                    GitReferenceBadge(reference: .branch(branch))
                } else {
                    Text("local")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange)
                        )
                }

                if !dependency.sourceFilePath.isEmpty {
                    Button(action: {
                        let fileURL = URL(fileURLWithPath: dependency.sourceFilePath)
                        NSWorkspace.shared.open(fileURL)
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit \(URL(fileURLWithPath: dependency.sourceFilePath).lastPathComponent) in default editor")
                }
            }

            if let localPath = dependency.localPath, !localPath.isEmpty {
                HStack(spacing: 4) {
                    Text(localPath)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(action: {
                        let folderURL = URL(fileURLWithPath: localPath)
                        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            loadGitBranch()
        }
    }

    private func loadGitBranch() {
        guard let localPath = dependency.localPath else {
            Log.debug("[LocalDependencyRow] No localPath for dependency: \(dependency.name)", category: .workspace)
            return
        }

        Log.debug("[LocalDependencyRow] Loading git branch for: \(dependency.name) at path: \(localPath)", category: .workspace)

        // Check if path exists and is a git repository
        let fileManager = FileManager.default
        let gitPath = (localPath as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: gitPath, isDirectory: &isDirectory)

        Log.debug("[LocalDependencyRow] Git path: \(gitPath), exists: \(exists), isDirectory: \(isDirectory.boolValue)", category: .workspace)

        guard exists && isDirectory.boolValue else {
            Log.debug("[LocalDependencyRow] Not a git repository: \(localPath)", category: .workspace)
            return
        }

        // Run git command on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let branch = getGitBranch(at: localPath)
            Log.debug("[LocalDependencyRow] Git branch result for \(self.dependency.name): \(branch ?? "nil")", category: .workspace)
            DispatchQueue.main.async {
                self.gitBranch = branch
            }
        }
    }
}

struct DependencyRow: View {
    let dependency: VenomDependency

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "shippingbox")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))

                Text(dependency.name)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if !dependency.tag.isEmpty {
                    Text(dependency.tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.pink)
                        )
                }

                if let url = repositoryURL {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open repository in browser")
                }

                if !dependency.sourceFilePath.isEmpty {
                    Button(action: {
                        let fileURL = URL(fileURLWithPath: dependency.sourceFilePath)
                        NSWorkspace.shared.open(fileURL)
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit \(URL(fileURLWithPath: dependency.sourceFilePath).lastPathComponent) in default editor")
                }
            }

            if !dependency.git.isEmpty {
                Text(dependency.git)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
    }

    private var repositoryURL: URL? {
        guard !dependency.git.isEmpty else { return nil }

        let git = dependency.git.trimmingCharacters(in: .whitespacesAndNewlines)

        // Already a full URL
        if let url = URL(string: git), url.scheme != nil {
            // Convert SSH format to HTTPS for common hosting platforms
            if git.hasPrefix("git@") {
                return convertSSHToHTTPS(git)
            }
            return url
        }

        // SSH format: git@github.com:user/repo.git
        if git.hasPrefix("git@") {
            return convertSSHToHTTPS(git)
        }

        // Short format: user/repo
        return URL(string: "https://github.com/\(git)")
    }

    private func convertSSHToHTTPS(_ ssh: String) -> URL? {
        // git@github.com:user/repo.git -> https://github.com/user/repo
        // git@gitlab.com:user/repo.git -> https://gitlab.com/user/repo
        // git@gitee.com:user/repo.git -> https://gitee.com/user/repo

        let pattern = "git@([^:]+):(.+?)(?:\\.git)?$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: ssh, range: NSRange(ssh.startIndex..., in: ssh)),
              match.numberOfRanges >= 3 else {
            return nil
        }

        guard let hostRange = Range(match.range(at: 1), in: ssh),
              let pathRange = Range(match.range(at: 2), in: ssh) else {
            return nil
        }

        let host = String(ssh[hostRange])
        let path = String(ssh[pathRange])

        return URL(string: "https://\(host)/\(path)")
    }
}

// MARK: - Git Branch Helper

/// Read git branch directly from git files (sandbox-safe)
private func getGitBranch(at path: String) -> String? {
    Log.debug("[getGitBranch] Checking path: \(path)", category: .workspace)

    // Try to read from .git/HEAD file directly
    let gitDir = (path as NSString).appendingPathComponent(".git")
    let headPath = (gitDir as NSString).appendingPathComponent("HEAD")

    guard FileManager.default.fileExists(atPath: headPath),
          let headContent = try? String(contentsOfFile: headPath, encoding: .utf8) else {
        Log.debug("[getGitBranch] Cannot read HEAD file at: \(headPath)", category: .workspace)
        return nil
    }

    let ref = headContent.trimmingCharacters(in: .whitespacesAndNewlines)
    Log.debug("[getGitBranch] HEAD content: \(ref)", category: .workspace)

    // HEAD contains: "ref: refs/heads/main" or just a commit hash
    if ref.hasPrefix("ref: ") {
        // Extract branch name from ref
        let branch = String(ref.dropFirst("ref: refs/heads/".count))
        Log.debug("[getGitBranch] Found branch: \(branch)", category: .workspace)
        return branch
    } else {
        // Detached HEAD - try to find tag or just return short commit
        if let tag = findTagForCommit(ref, in: gitDir) {
            Log.debug("[getGitBranch] Found tag: \(tag)", category: .workspace)
            return tag
        }
        // Return short commit hash
        let shortCommit = String(ref.prefix(7))
        Log.debug("[getGitBranch] Detached HEAD, commit: \(shortCommit)", category: .workspace)
        return shortCommit
    }
}

/// Find tag for a commit by scanning refs/tags directory
private func findTagForCommit(_ commit: String, in gitDir: String) -> String? {
    let tagsDir = (gitDir as NSString).appendingPathComponent("refs/tags")

    guard FileManager.default.fileExists(atPath: tagsDir) else {
        return nil
    }

    do {
        let tagFiles = try FileManager.default.contentsOfDirectory(atPath: tagsDir)
        for tagFile in tagFiles {
            let tagPath = (tagsDir as NSString).appendingPathComponent(tagFile)
            if let tagContent = try? String(contentsOfFile: tagPath, encoding: .utf8) {
                let tagCommit = tagContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if tagCommit == commit {
                    return tagFile
                }
            }
        }
    } catch {
        // Ignore errors
    }

    // Try packed-refs
    let packedRefsPath = (gitDir as NSString).appendingPathComponent("packed-refs")
    if let packedRefs = try? String(contentsOfFile: packedRefsPath, encoding: .utf8) {
        for line in packedRefs.split(separator: "\n") {
            let lineStr = String(line)
            if lineStr.hasPrefix("#") || lineStr.hasPrefix("^") { continue }
            let parts = lineStr.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0] == commit, parts[1].hasPrefix("refs/tags/") {
                return String(parts[1].dropFirst("refs/tags/".count))
            }
        }
    }

    return nil
}

#Preview {
    DependencyListView(
        folder: Folder(name: "Test", path: "/test")
    )
    .frame(width: 500, height: 500)
}
