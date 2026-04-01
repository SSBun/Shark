//
//  IDEApp.swift
//  Shark
//
//  Created by caishilin on 2026/04/01.
//

import AppKit
import Foundation

enum IDEApp: String, CaseIterable, Identifiable {
    case cursor = "Cursor"
    case trae = "Trae"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor:
            return "Cursor"
        case .trae:
            return "Trae"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .cursor:
            return "com.todesktop.230313mzl4w4u92"
        case .trae:
            return "com.traede.IDE"
        }
    }

    /// Check if this IDE is installed
    var isInstalled: Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
}
