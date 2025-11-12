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
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no visible windows, show the main window
        if !flag {
            if let window = mainWindow ?? NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Track the main window
        DispatchQueue.main.async { [weak self] in
            self?.mainWindow = NSApplication.shared.windows.first
        }
        
        // Prevent multiple windows by closing any additional windows
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let newWindow = notification.object as? NSWindow else { return }
            
            // If this is not the main window and not the settings window, close it
            if newWindow != self.mainWindow && !newWindow.title.contains("Settings") {
                newWindow.close()
            }
        }
        
        // Terminate app when main window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            
            // If the main window closes, terminate the app
            if window == self?.mainWindow {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
