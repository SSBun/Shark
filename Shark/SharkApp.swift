//
//  SharkApp.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

@main
struct SharkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .authorizationPanel()
                .environmentObject(AuthorizationManager.shared)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove "New Window" command
            }
        }
        
        Settings {
            SettingsView()
                .authorizationPanel()
                .environmentObject(AuthorizationManager.shared)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var windowObservers: [NSObjectProtocol] = []
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no visible windows, show the main window
        if !flag {
            if let window = mainWindow ?? findMainContentWindow() {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Track windows after a short delay to ensure they're created
        DispatchQueue.main.async { [weak self] in
            self?.setupWindowTracking()
        }
    }
    
    private func setupWindowTracking() {
        // Find and track the main content window
        mainWindow = findMainContentWindow()
        
        // Track settings window when it appears
        let settingsObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let window = notification.object as? NSWindow else { return }
            
            // Identify settings window by checking if it's a settings scene window
            if self.isSettingsWindow(window) {
                self.settingsWindow = window
                return
            }
            
            // Identify main window by checking if it's the content window
            if self.isMainContentWindow(window) {
                self.mainWindow = window
                return
            }
            
            // Prevent multiple main content windows
            // Only close windows that are content windows (not dialogs, alerts, etc.)
            if self.isContentWindow(window) && window != self.mainWindow {
                window.close()
            }
        }
        windowObservers.append(settingsObserver)
        
        // Terminate app when main window closes
        let closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let window = notification.object as? NSWindow else { return }
            
            // Clean up tracked windows
            if window == self.mainWindow {
                self.mainWindow = nil
                NSApplication.shared.terminate(nil)
            } else if window == self.settingsWindow {
                self.settingsWindow = nil
            }
        }
        windowObservers.append(closeObserver)
    }
    
    /// Find the main content window (WindowGroup window)
    private func findMainContentWindow() -> NSWindow? {
        return NSApplication.shared.windows.first { window in
            isMainContentWindow(window)
        }
    }
    
    /// Check if a window is the main content window
    private func isMainContentWindow(_ window: NSWindow) -> Bool {
        // Main content window is a regular titled window that's not settings
        return window.isVisible &&
               window.styleMask.contains(.titled) &&
               !isSettingsWindow(window) &&
               !isDialogWindow(window)
    }
    
    /// Check if a window is a settings window
    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        // Settings windows typically have specific characteristics
        // Check by title pattern
        let title = window.title.lowercased()
        return title.contains("settings") || title.contains("preferences")
    }
    
    /// Check if a window is a dialog (file picker, alert, etc.)
    private func isDialogWindow(_ window: NSWindow) -> Bool {
        // File dialogs, alerts, and panels are not content windows
        // Check window type using class name
        let windowType = String(describing: type(of: window))
        return window is NSPanel ||
               windowType.contains("NSSavePanel") ||
               windowType.contains("NSOpenPanel") ||
               windowType.contains("NSAlert") ||
               windowType.contains("Panel")
    }
    
    /// Check if a window is a content window (main or settings)
    private func isContentWindow(_ window: NSWindow) -> Bool {
        return isMainContentWindow(window) || isSettingsWindow(window)
    }
    
    deinit {
        // Clean up observers
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
    }
}
