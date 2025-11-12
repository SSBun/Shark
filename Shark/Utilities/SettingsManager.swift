//
//  SettingsManager.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let settingsFolderPathKey = "settingsFolderPath"
    
    private init() {}
    
    /// Get the default settings folder path (SharkSpace in Documents)
    var defaultSettingsFolderPath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("SharkSpace").path
    }
    
    /// Get the current settings folder path, or default if not set
    var settingsFolderPath: String {
        get {
            if let savedPath = UserDefaults.standard.string(forKey: settingsFolderPathKey), !savedPath.isEmpty {
                return savedPath
            }
            return defaultSettingsFolderPath
        }
        set {
            UserDefaults.standard.set(newValue, forKey: settingsFolderPathKey)
        }
    }
    
    /// Get the settings folder URL, creating it if necessary
    func getSettingsFolderURL() throws -> URL {
        let path = settingsFolderPath
        let url = URL(fileURLWithPath: path)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        return url
    }
    
    /// Generate a unique workspace filename
    func generateWorkspaceFilename(baseName: String = "workspace") -> String {
        let folderURL = URL(fileURLWithPath: settingsFolderPath)
        var filename = "\(baseName).code-workspace"
        var counter = 1
        
        while FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(filename).path) {
            filename = "\(baseName)-\(counter).code-workspace"
            counter += 1
        }
        
        return filename
    }
    
    /// Get the full URL for a new workspace file
    func getNewWorkspaceURL(baseName: String = "workspace") throws -> URL {
        let folderURL = try getSettingsFolderURL()
        let filename = generateWorkspaceFilename(baseName: baseName)
        return folderURL.appendingPathComponent(filename)
    }
}

