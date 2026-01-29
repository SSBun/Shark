//
//  XcodeOpener.swift
//  Shark
//
//  Created by caishilin on 2026/01/29.
//

import AppKit
import Foundation

struct XcodeOpener {
    /// Open an Xcode project or workspace
    static func openProject(at path: String, bookmarkData: Data? = nil) {
        let url = URL(fileURLWithPath: path)
        
        // Try to use bookmark data if available
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let bookmarkedURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               bookmarkedURL.startAccessingSecurityScopedResource() {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                
                // If the path is a subpath of the bookmarked URL, we might need to construct the full URL
                // But usually the path passed here is already the full path.
                // NSWorkspace.shared.open works better with the actual file URL.
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        // Start accessing security-scoped resource if needed
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("Xcode project path does not exist: \(path)")
            return
        }
        
        // Open with default application (which should be Xcode for these extensions)
        NSWorkspace.shared.open(url)
    }
}
