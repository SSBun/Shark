//
//  ComponentValidationView.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/26.
//

import SwiftUI

struct ValidationField: View {
    let label: String
    @Binding var text: String
    let error: ValidationError?
    let placeholder: String
    let onSubmit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    init(
        label: String,
        text: Binding<String>,
        error: ValidationError? = nil,
        placeholder: String = "",
        onSubmit: (() -> Void)? = nil
    ) {
        self.label = label
        self._text = text
        self.error = error
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit {
                        onSubmit?()
                    }
                
                if error != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                } else if !text.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                }
            }
            
            if let error = error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 11))
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var borderColor: Color {
        if error != nil {
            return .red
        } else if isFocused {
            return .accentColor
        } else if !text.isEmpty {
            return .green.opacity(0.5)
        }
        return Color(NSColor.separatorColor)
    }
}

struct ValidationButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    
    init(
        _ title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(.circular)
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isEnabled || isLoading)
    }
}

struct ErrorBanner: View {
    let title: String
    let message: String
    let onDismiss: (() -> Void)?
    let onRetry: (() -> Void)?
    
    init(
        title: String,
        message: String,
        onDismiss: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let onRetry = onRetry {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(radius: 10)
            )
        }
    }
}

#Preview("Validation Field") {
    VStack(spacing: 20) {
        ValidationField(
            label: "Workspace Name",
            text: .constant("My Workspace"),
            error: nil,
            placeholder: "Enter workspace name"
        )
        
        ValidationField(
            label: "Invalid Name",
            text: .constant(""),
            error: .emptyField(fieldName: "Workspace name"),
            placeholder: "Enter workspace name"
        )
        
        ValidationButton("Create Workspace", isEnabled: true) {
            print("Create")
        }
        
        ErrorBanner(
            title: "Failed to Load",
            message: "Could not connect to the server",
            onDismiss: {},
            onRetry: {}
        )
    }
    .padding()
    .frame(width: 400, height: 400)
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "folder.badge.questionmark",
        title: "No Workspaces",
        message: "Create your first workspace to get started",
        actionTitle: "Create Workspace",
        action: {}
    )
    .frame(width: 400, height: 300)
}
