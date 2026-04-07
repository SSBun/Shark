//
//  VenomDependency.swift
//  Shark
//
//  Created by caishilin on 2026/04/01.
//

import Foundation

struct VenomDependency: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let git: String
    let tag: String
    let sourceFilePath: String
    let localPath: String?

    init(name: String, git: String, tag: String, sourceFilePath: String = "", localPath: String? = nil) {
        self.name = name
        self.git = git
        self.tag = tag
        self.sourceFilePath = sourceFilePath
        self.localPath = localPath
    }

    /// Whether this is a locally integrated dependency (developing dependency)
    var isLocal: Bool {
        localPath != nil && !localPath!.isEmpty
    }
}
