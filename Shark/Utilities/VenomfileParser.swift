//
//  VenomfileParser.swift
//  Shark
//
//  Created by caishilin on 2026/04/01.
//

import Foundation

struct VenomfileParser {
    /// Parse all dependencies from the Venomfiles directory within a folder
    static func parseDependencies(from folder: Folder) -> [VenomDependency] {
        guard folder.existsOnDisk else { return [] }

        // Try to access via bookmark data first
        if let dependencies = accessAndParse(folder: folder) {
            return dependencies
        }

        // Try global authorized folders from SettingsManager
        if let globalBookmarkData = SettingsManager.shared.bookmarkData(for: folder.path) {
            var folderWithBookmark = folder
            folderWithBookmark.bookmarkData = globalBookmarkData
            if let dependencies = accessAndParse(folder: folderWithBookmark) {
                return dependencies
            }
        }

        // Direct access using folder.path - search recursively for Venomfiles
        return parseDependenciesRecursively(baseURL: URL(fileURLWithPath: folder.path), bookmarkData: folder.bookmarkData)
    }

    /// Parse local developing dependencies from customization.yml in the Venomfiles directory
    static func parseLocalDependencies(from folder: Folder) -> [VenomDependency] {
        guard folder.existsOnDisk else { return [] }

        // Try to access via bookmark data first
        if let dependencies = accessAndParseLocal(folder: folder) {
            return dependencies
        }

        // Try global authorized folders from SettingsManager
        if let globalBookmarkData = SettingsManager.shared.bookmarkData(for: folder.path) {
            var folderWithBookmark = folder
            folderWithBookmark.bookmarkData = globalBookmarkData
            if let dependencies = accessAndParseLocal(folder: folderWithBookmark) {
                return dependencies
            }
        }

        // Direct access using folder.path
        return parseLocalDependenciesRecursively(baseURL: URL(fileURLWithPath: folder.path), bookmarkData: folder.bookmarkData)
    }

    private static func accessAndParseLocal(folder: Folder) -> [VenomDependency]? {
        guard let bookmarkData = folder.bookmarkData else { return nil }

        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
              url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        return parseLocalDependenciesRecursively(baseURL: url, bookmarkData: bookmarkData)
    }

    private static func parseLocalDependenciesRecursively(baseURL: URL, bookmarkData: Data?, depth: Int = 0) -> [VenomDependency] {
        guard depth < 3 else { return [] }

        let fileManager = FileManager.default

        // Check if there's a Venomfiles directory at current level
        let venomfilesURL = baseURL.appendingPathComponent("Venomfiles")
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: venomfilesURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            // Parse local dependencies from customization.yml
            let localDeps = parseCustomizationFile(at: venomfilesURL)
            if !localDeps.isEmpty {
                return localDeps
            }
        }

        // Search subdirectories recursively
        do {
            let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            for itemURL in contents {
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let subDeps = parseLocalDependenciesRecursively(baseURL: itemURL, bookmarkData: bookmarkData, depth: depth + 1)
                    if !subDeps.isEmpty {
                        return subDeps
                    }
                }
            }
        } catch {
            // Ignore errors when scanning subdirectories
        }

        return []
    }

    private static func parseCustomizationFile(at venomfilesURL: URL) -> [VenomDependency] {
        let customizationURL = venomfilesURL.appendingPathComponent("customization.yml")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: customizationURL.path) else {
            return []
        }

        guard let content = try? String(contentsOf: customizationURL, encoding: .utf8) else {
            return []
        }

        var dependencies: [VenomDependency] = []

        // Parse YAML format:
        // ---
        // ModuleName:
        //   path: "/path/to/module"
        // AnotherModule:
        //   path: "/path/to/another"

        // Split into lines and process
        let lines = content.components(separatedBy: .newlines)
        var currentModule: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip document start marker and empty lines
            if trimmed == "---" || trimmed.isEmpty {
                continue
            }

            // Check if this is a module name (no leading spaces, ends with colon)
            let modulePattern = "^([^:]+):$"
            if let regex = try? NSRegularExpression(pattern: modulePattern),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
               match.numberOfRanges >= 2,
               let range = Range(match.range(at: 1), in: trimmed) {
                currentModule = String(trimmed[range])
                continue
            }

            // Check if this is a path property (indented, starts with "path:")
            let pathPattern = "^\\s*path:\\s*\"?([^\"]+)\"?$"
            if let regex = try? NSRegularExpression(pattern: pathPattern),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges >= 2,
               let range = Range(match.range(at: 1), in: line),
               let module = currentModule {
                let path = String(line[range]).trimmingCharacters(in: .whitespaces)
                let dependency = VenomDependency(
                    name: module,
                    git: "",
                    tag: "local",
                    sourceFilePath: customizationURL.path,
                    localPath: path
                )
                dependencies.append(dependency)
            }
        }

        return dependencies.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func accessAndParse(folder: Folder) -> [VenomDependency]? {
        guard let bookmarkData = folder.bookmarkData else { return nil }

        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
              url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Use the resolved URL to search for Venomfiles recursively
        return parseDependenciesRecursively(baseURL: url, bookmarkData: bookmarkData)
    }

    private static func parseDependenciesRecursively(baseURL: URL, bookmarkData: Data?, depth: Int = 0) -> [VenomDependency] {
        guard depth < 3 else { return [] }

        let fileManager = FileManager.default

        // Check if there's a Venomfiles directory at current level
        let venomfilesURL = baseURL.appendingPathComponent("Venomfiles")
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: venomfilesURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            // Parse dependencies from this Venomfiles
            let deps = parseDependenciesFromURL(venomfilesURL)
            if !deps.isEmpty {
                return deps
            }
        }

        // Search subdirectories recursively
        do {
            let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            for itemURL in contents {
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let subDeps = parseDependenciesRecursively(baseURL: itemURL, bookmarkData: bookmarkData, depth: depth + 1)
                    if !subDeps.isEmpty {
                        return subDeps
                    }
                }
            }
        } catch {
            // Ignore errors when scanning subdirectories
        }

        return []
    }

    private static func parseDependenciesFromURL(_ venomfilesURL: URL) -> [VenomDependency] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: venomfilesURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return []
        }

        var dependencies: [VenomDependency] = []

        // Find all .rb files recursively within Venomfiles
        if let enumerator = fileManager.enumerator(at: venomfilesURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if fileURL.pathExtension == "rb" {
                    if let dependency = parseDependencyFile(at: fileURL) {
                        dependencies.append(dependency)
                    }
                }
            }
        }

        return dependencies.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func parseDependencyFile(at url: URL) -> VenomDependency? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        // Parse v.name, v.git, v.tag from Ruby file
        // Format: VenomFile.new do |v|
        //           v.name = 'Name'
        //           v.git = 'git@...'
        //           v.tag = 'version'
        //         end

        var name: String?
        var git: String?
        var tag: String?

        // Regex patterns for Ruby strings (both single and double quotes)
        let namePattern = #"v\s*\.\s*name\s*=\s*['"]([^'"]+)['"]"#
        let gitPattern = #"v\s*\.\s*git\s*=\s*['"]([^'"]+)['"]"#
        let tagPattern = #"v\s*\.\s*tag\s*=\s*['"]([^'"]+)['"]"#

        if let regex = try? NSRegularExpression(pattern: namePattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            name = String(content[range])
        }

        if let regex = try? NSRegularExpression(pattern: gitPattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            git = String(content[range])
        }

        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            tag = String(content[range])
        }

        guard let name = name, !name.isEmpty else {
            return nil
        }

        return VenomDependency(
            name: name,
            git: git ?? "",
            tag: tag ?? "",
            sourceFilePath: url.path
        )
    }
}
