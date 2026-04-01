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
            } else if dependencies.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No dependencies found")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if filteredDependencies.isEmpty {
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
                List(filteredDependencies) { dependency in
                    DependencyRow(dependency: dependency)
                        .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            HStack {
                Text("\(filteredDependencies.count) of \(dependencies.count) dependencies")
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
            DispatchQueue.main.async {
                self.dependencies = deps
                self.isLoading = false

                if deps.isEmpty {
                    Log.info("No dependencies found for: \(folder.name). Venomfiles check: \(folder.hasVenomfiles)", category: .workspace)

                    // Try to diagnose why empty
                    let venomfilesPath = (folder.path as NSString).appendingPathComponent("Venomfiles")
                    var isDir: ObjCBool = false
                    let exists = FileManager.default.fileExists(atPath: venomfilesPath, isDirectory: &isDir)
                    Log.debug("Venomfiles path: \(venomfilesPath), exists: \(exists), isDirectory: \(isDir.boolValue)", category: .workspace)
                } else {
                    Log.info("Loaded \(deps.count) dependencies for: \(folder.name)", category: .workspace)
                }
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

#Preview {
    DependencyListView(
        folder: Folder(name: "Test", path: "/test")
    )
    .frame(width: 500, height: 500)
}
