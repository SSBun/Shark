//
//  ClaudeWorkspaceFile.swift
//  Shark
//

import Foundation

struct ClaudeWorkspaceFile: Codable {
    var version: Int = 1
    var name: String
    var links: [LinkedFolder]
    var createdAt: Date

    struct LinkedFolder: Codable {
        let originalPath: String
        let symlinkName: String
        let parentFolder: String?

        var folderName: String {
            URL(fileURLWithPath: originalPath).lastPathComponent
        }
    }

    static let metadataFileName = ".claude-workspace.json"
}

extension ClaudeWorkspaceFile {
    static func parse(from url: URL) throws -> ClaudeWorkspaceFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ClaudeWorkspaceFile.self, from: data)
    }

    static func parse(fromDirectory directoryURL: URL) throws -> ClaudeWorkspaceFile {
        let metadataURL = directoryURL.appendingPathComponent(metadataFileName)
        return try parse(from: metadataURL)
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    func save(toDirectory directoryURL: URL) throws {
        let metadataURL = directoryURL.appendingPathComponent(Self.metadataFileName)
        try save(to: metadataURL)
    }

    static func createEmpty(name: String) -> ClaudeWorkspaceFile {
        ClaudeWorkspaceFile(name: name, links: [], createdAt: Date())
    }

    func toWorkspace(directoryPath: String) -> Workspace {
        Workspace(
            name: name,
            filePath: directoryPath,
            type: .claude
        )
    }

    func toFolders() -> [Folder] {
        links.map { link in
            let bookmarkKey = "folderBookmark_\(link.originalPath)"
            let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey)
            let venomfilesKey = "hasVenomfiles_\(link.originalPath)"
            let cachedHasVenomfiles = UserDefaults.standard.bool(forKey: venomfilesKey)

            return Folder(
                name: link.folderName,
                path: link.originalPath,
                displayName: nil,
                bookmarkData: bookmarkData,
                hasVenomfiles: cachedHasVenomfiles
            )
        }
    }

    mutating func addLink(originalPath: String, symlinkName: String, parentFolder: String?) {
        let link = LinkedFolder(originalPath: originalPath, symlinkName: symlinkName, parentFolder: parentFolder)
        links.append(link)
    }

    mutating func removeLink(originalPath: String) {
        links.removeAll { $0.originalPath == originalPath }
    }
}
