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

    init(name: String, git: String, tag: String, sourceFilePath: String = "") {
        self.name = name
        self.git = git
        self.tag = tag
        self.sourceFilePath = sourceFilePath
    }
}
