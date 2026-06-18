//
//  VirtualWorkspaceFile.swift
//  Shark
//

import Foundation

struct VirtualWorkspaceFile: Codable {
    var version: Int = 1
    var name: String
    var links: [LinkedFolder]
    var createdAt: Date
    var codexSessionDisplayNames: [String: String]?

    struct LinkedFolder: Codable {
        let originalPath: String
        let symlinkName: String
        let parentFolder: String?

        var folderName: String {
            URL(fileURLWithPath: originalPath).lastPathComponent
        }
    }

    static let metadataFileName = ".shark-workspace.json"
    private static let legacyMetadataFileName = ".claude-workspace.json"
}

extension VirtualWorkspaceFile {
    static func metadataURL(in directoryURL: URL) -> URL? {
        let currentURL = directoryURL.appendingPathComponent(metadataFileName)
        if FileManager.default.fileExists(atPath: currentURL.path) {
            return currentURL
        }

        let legacyURL = directoryURL.appendingPathComponent(legacyMetadataFileName)
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }

        return nil
    }

    static func parse(from url: URL) throws -> VirtualWorkspaceFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VirtualWorkspaceFile.self, from: data)
    }

    static func parse(fromDirectory directoryURL: URL) throws -> VirtualWorkspaceFile {
        guard let url = metadataURL(in: directoryURL) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try parse(from: url)
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    func save(toDirectory directoryURL: URL) throws {
        try save(to: directoryURL.appendingPathComponent(Self.metadataFileName))
    }

    static func createEmpty(name: String) -> VirtualWorkspaceFile {
        VirtualWorkspaceFile(name: name, links: [], createdAt: Date())
    }

    func toWorkspace(directoryPath: String) -> Workspace {
        Workspace(name: name, filePath: directoryPath)
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

    mutating func setCodexSessionDisplayName(_ name: String?, for sessionID: String) {
        var names = codexSessionDisplayNames ?? [:]
        if let name, !name.isEmpty {
            names[sessionID] = name
        } else {
            names.removeValue(forKey: sessionID)
        }
        codexSessionDisplayNames = names.isEmpty ? nil : names
    }

    mutating func addLink(originalPath: String, symlinkName: String, parentFolder: String?) {
        links.append(LinkedFolder(originalPath: originalPath, symlinkName: symlinkName, parentFolder: parentFolder))
    }
}
