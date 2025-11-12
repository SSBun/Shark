//
//  AuthorizationManager.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import Foundation
import AppKit
import Combine

enum AuthorizationType {
    case fileSystemAccess
    case fullDiskAccess
    case networkAccess
}

enum AuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
class AuthorizationManager: ObservableObject {
    static let shared = AuthorizationManager()
    
    @Published var fileSystemAccessStatus: AuthorizationStatus = .notDetermined
    @Published var fullDiskAccessStatus: AuthorizationStatus = .notDetermined
    @Published var networkAccessStatus: AuthorizationStatus = .notDetermined
    
    @Published var showAuthorizationPanel = false
    @Published var pendingAuthorizationType: AuthorizationType?
    
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    
    private init() {
        checkAllAuthorizations()
    }
    
    /// Check all authorization statuses
    func checkAllAuthorizations() {
        fileSystemAccessStatus = checkFileSystemAccess()
        fullDiskAccessStatus = checkFullDiskAccess()
        networkAccessStatus = checkNetworkAccess()
    }
    
    /// Check file system access authorization
    func checkFileSystemAccess() -> AuthorizationStatus {
        // Check if we can access user's Documents folder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let documentsPath = documentsPath {
            let testFile = documentsPath.appendingPathComponent(".shark_test")
            do {
                try "test".write(to: testFile, atomically: true, encoding: .utf8)
                try? FileManager.default.removeItem(at: testFile)
                return .authorized
            } catch {
                return .denied
            }
        }
        return .notDetermined
    }
    
    /// Check Full Disk Access authorization
    func checkFullDiskAccess() -> AuthorizationStatus {
        // Check if we can access protected directories
        let protectedPaths = [
            "/Library",
            "/System",
            "/Users"
        ]
        
        for path in protectedPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return .authorized
            }
        }
        
        // If we can't access protected paths, check if it's denied or just not requested
        if fileSystemAccessStatus == .denied {
            return .denied
        }
        
        return .notDetermined
    }
    
    /// Check network access authorization
    func checkNetworkAccess() -> AuthorizationStatus {
        // For macOS, network access is typically always available
        // But we can check if network interfaces are available
        // This is a simplified check
        return .authorized
    }
    
    /// Request authorization for a specific type
    func requestAuthorization(for type: AuthorizationType) {
        pendingAuthorizationType = type
        showAuthorizationPanel = true
    }
    
    /// Handle authorization result
    func handleAuthorizationResult(_ granted: Bool, for type: AuthorizationType) {
        showAuthorizationPanel = false
        
        if granted {
            switch type {
            case .fileSystemAccess:
                fileSystemAccessStatus = .authorized
            case .fullDiskAccess:
                fullDiskAccessStatus = .authorized
                // Open System Preferences to Full Disk Access
                openSystemPreferencesFullDiskAccess()
            case .networkAccess:
                networkAccessStatus = .authorized
            }
        } else {
            switch type {
            case .fileSystemAccess:
                fileSystemAccessStatus = .denied
            case .fullDiskAccess:
                fullDiskAccessStatus = .denied
            case .networkAccess:
                networkAccessStatus = .denied
            }
        }
        
        pendingAuthorizationType = nil
        
        // Resume continuation if waiting
        authorizationContinuation?.resume(returning: granted)
        authorizationContinuation = nil
    }
    
    /// Open System Preferences to Full Disk Access settings
    private func openSystemPreferencesFullDiskAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
    
    /// Check if authorization is required before performing an operation
    func requireAuthorization(for type: AuthorizationType) async -> Bool {
        let status: AuthorizationStatus
        
        switch type {
        case .fileSystemAccess:
            status = fileSystemAccessStatus
        case .fullDiskAccess:
            status = fullDiskAccessStatus
        case .networkAccess:
            status = networkAccessStatus
        }
        
        if status == .authorized {
            return true
        }
        
        if status == .notDetermined {
            requestAuthorization(for: type)
            // Wait for user response
            return await waitForAuthorizationResponse(for: type)
        }
        
        return false
    }
    
    /// Wait for authorization response
    private func waitForAuthorizationResponse(for type: AuthorizationType) async -> Bool {
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            
            // Set up observer to check status periodically
            Task {
                var checkCount = 0
                let maxChecks = 300 // 30 seconds max wait
                
                while checkCount < maxChecks {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                    let status: AuthorizationStatus
                    switch type {
                    case .fileSystemAccess:
                        status = fileSystemAccessStatus
                    case .fullDiskAccess:
                        status = fullDiskAccessStatus
                    case .networkAccess:
                        status = networkAccessStatus
                    }
                    
                    if status == .authorized || status == .denied {
                        continuation.resume(returning: status == .authorized)
                        authorizationContinuation = nil
                        return
                    }
                    
                    checkCount += 1
                }
                
                // Timeout - assume denied
                continuation.resume(returning: false)
                authorizationContinuation = nil
            }
        }
    }
}

