//
//  AuthorizationPanel.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI

struct AuthorizationPanel: View {
    @ObservedObject var authManager = AuthorizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if let authType = authManager.pendingAuthorizationType {
            VStack(spacing: 20) {
                // Icon
                Image(systemName: iconForType(authType))
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                    .padding(.top, 20)
                
                // Title
                Text(titleForType(authType))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Description
                Text(descriptionForType(authType))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Additional info for Full Disk Access
                if authType == .fullDiskAccess {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To grant Full Disk Access:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Click \"Open System Preferences\"")
                            Text("2. Select \"Full Disk Access\"")
                            Text("3. Click the lock to make changes")
                            Text("4. Check the box next to \"Shark\"")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        authManager.handleAuthorizationResult(false, for: authType)
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    if authType == .fullDiskAccess {
                        Button("Open System Preferences") {
                            authManager.handleAuthorizationResult(true, for: authType)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Grant Access") {
                            authManager.handleAuthorizationResult(true, for: authType)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(width: 500, height: 400)
            .padding()
        }
    }
    
    private func iconForType(_ type: AuthorizationType) -> String {
        switch type {
        case .fileSystemAccess:
            return "folder.badge.questionmark"
        case .fullDiskAccess:
            return "lock.shield"
        case .networkAccess:
            return "network"
        }
    }
    
    private func titleForType(_ type: AuthorizationType) -> String {
        switch type {
        case .fileSystemAccess:
            return "File System Access Required"
        case .fullDiskAccess:
            return "Full Disk Access Required"
        case .networkAccess:
            return "Network Access Required"
        }
    }
    
    private func descriptionForType(_ type: AuthorizationType) -> String {
        switch type {
        case .fileSystemAccess:
            return "Shark needs access to your file system to manage workspace files and folders."
        case .fullDiskAccess:
            return "Shark needs Full Disk Access to read and manage workspace files in protected directories. This allows the app to access workspace files stored anywhere on your Mac."
        case .networkAccess:
            return "Shark needs network access to sync workspace configurations and access remote resources."
        }
    }
}

struct AuthorizationPanelModifier: ViewModifier {
    @ObservedObject var authManager = AuthorizationManager.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $authManager.showAuthorizationPanel) {
                AuthorizationPanel()
            }
    }
}

extension View {
    func authorizationPanel() -> some View {
        modifier(AuthorizationPanelModifier())
    }
}

#Preview {
    AuthorizationPanel()
}

