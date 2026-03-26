//
//  AlertManager.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/26.
//

import SwiftUI
import Combine

enum AlertType {
    case success
    case error
    case warning
    case info
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

struct AlertItem: Identifiable, Equatable {
    let id = UUID()
    let type: AlertType
    let title: String
    let message: String
    let duration: TimeInterval
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        type: AlertType,
        title: String,
        message: String,
        duration: TimeInterval = 3.0,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
        self.action = action
        self.actionTitle = actionTitle
    }
    
    static func == (lhs: AlertItem, rhs: AlertItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var alerts: [AlertItem] = []
    @Published var isShowing: Bool = false
    
    private var dismissTimers: [UUID: Timer] = [:]
    
    private init() {}
    
    func show(_ alert: AlertItem) {
        alerts.append(alert)
        
        if alerts.count == 1 {
            isShowing = true
        }
        
        if alert.duration > 0 {
            let timer = Timer.scheduledTimer(withTimeInterval: alert.duration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.dismiss(alert)
                }
            }
            dismissTimers[alert.id] = timer
        }
    }
    
    func show(
        type: AlertType,
        title: String,
        message: String,
        duration: TimeInterval = 3.0,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        let alert = AlertItem(
            type: type,
            title: title,
            message: message,
            duration: duration,
            action: action,
            actionTitle: actionTitle
        )
        show(alert)
    }
    
    func dismiss(_ alert: AlertItem) {
        dismissTimers[alert.id]?.invalidate()
        dismissTimers.removeValue(forKey: alert.id)
        
        withAnimation(.easeOut(duration: 0.2)) {
            alerts.removeAll { $0.id == alert.id }
        }
        
        if alerts.isEmpty {
            isShowing = false
        }
    }
    
    func dismissAll() {
        dismissTimers.values.forEach { $0.invalidate() }
        dismissTimers.removeAll()
        
        withAnimation(.easeOut(duration: 0.2)) {
            alerts.removeAll()
        }
        isShowing = false
    }
    
    func success(_ message: String, title: String = "Success") {
        show(type: .success, title: title, message: message)
    }
    
    func error(_ message: String, title: String = "Error", action: (() -> Void)? = nil, actionTitle: String? = nil) {
        show(type: .error, title: title, message: message, duration: action != nil ? 0 : 5.0, action: action, actionTitle: actionTitle)
    }
    
    func warning(_ message: String, title: String = "Warning") {
        show(type: .warning, title: title, message: message)
    }
    
    func info(_ message: String, title: String = "Info") {
        show(type: .info, title: title, message: message)
    }
}

struct ToastAlertView: View {
    @ObservedObject var alertManager = AlertManager.shared
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 8) {
                ForEach(alertManager.alerts) { alert in
                    ToastAlertRow(alert: alert)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}

struct ToastAlertRow: View {
    let alert: AlertItem
    @ObservedObject var alertManager = AlertManager.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.type.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(alert.type.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(alert.message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let action = alert.action, let actionTitle = alert.actionTitle {
                Button(action: {
                    alert.action?()
                    alertManager.dismiss(alert)
                }) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Button(action: {
                alertManager.dismiss(alert)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(alert.type.color.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: 380)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ToastModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(ToastAlertView())
    }
}

extension View {
    func toast() -> some View {
        modifier(ToastModifier())
    }
}
