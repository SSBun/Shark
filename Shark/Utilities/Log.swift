//
//  Log.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/03.
//

import os.log

// MARK: - Logging

enum LogCategory {
    case terminal
    case general
    case workspace
    case settings
}

enum Log {
    private static let subsystem = "com.csl.cool.Shark"
    
    private static func osLog(for category: LogCategory) -> OSLog {
        return OSLog(subsystem: subsystem, category: String(describing: category))
    }
    
    // MARK: - Log Methods
    
    static func debug(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        os_log("%{public}s", log: osLog(for: category), type: .debug, message)
    }
    
    static func error(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        os_log("%{public}s", log: osLog(for: category), type: .error, message)
    }
    
    static func info(_ message: String, category: LogCategory = .general, file: String = #file, line: Int = #line) {
        os_log("%{public}s", log: osLog(for: category), type: .info, message)
    }
}
