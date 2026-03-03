//
//  SettingsView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var settingsFolderPath: String = ""
    @State private var componentsSearchPath: String = ""
    @State private var selectedLocationType: LocationType = .default
    @State private var authorizedFolders: [String] = []
    @State private var selectedTerminalApp: TerminalApp = .systemDefault
    private let settingsManager = SettingsManager.shared
    
    enum LocationType: String, CaseIterable {
        case `default` = "Default"
        case custom = "Custom"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Settings Saving Folder section
                    settingsSavingFolderSection
                    
                    Divider()
                    
                    // Components Search Path section
                    componentsSearchPathSection
                    
                    Divider()
                    
                    // Folder Access section
                    folderAccessSection
                    
                    Divider()
                    
                    // Terminal App section
                    terminalAppSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .frame(width: 620, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            settingsFolderPath = settingsManager.settingsFolderPath
            componentsSearchPath = settingsManager.componentsSearchPath
            authorizedFolders = settingsManager.authorizedFolders
            selectedTerminalApp = settingsManager.defaultTerminalApp
            // Determine if current path is default or custom
            if settingsFolderPath == settingsManager.defaultSettingsFolderPath {
                selectedLocationType = .default
            } else {
                selectedLocationType = .custom
            }
        }
        .onChange(of: selectedLocationType) { oldValue, newValue in
            if newValue == .default {
                settingsFolderPath = settingsManager.defaultSettingsFolderPath
                settingsManager.settingsFolderPath = settingsFolderPath
                // Refresh workspaces when switching back to default
                WorkspaceManager.shared.refreshWorkspaces()
            }
        }
        .onChange(of: settingsFolderPath) { oldValue, newValue in
            // Auto-save when path changes
            settingsManager.settingsFolderPath = newValue
        }
        .onChange(of: componentsSearchPath) { oldValue, newValue in
            settingsManager.componentsSearchPath = newValue
        }
        .onChange(of: selectedTerminalApp) { oldValue, newValue in
            settingsManager.defaultTerminalApp = newValue
        }
    }
    
    private var folderAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Folder Access Permissions:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Grant Shark permission to access specific directories on your disk. This is required for sandboxed apps to read project files.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            if !authorizedFolders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(authorizedFolders, id: \.self) { path in
                        HStack {
                            Text(path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button(action: {
                                settingsManager.removeAuthorizedFolder(at: path)
                                authorizedFolders = settingsManager.authorizedFolders
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Button("Grant Access to New Folder...") {
                requestGlobalFolderAccess()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    private func requestGlobalFolderAccess() {
        guard let url = FileDialogHelper.selectFolder(
            title: "Grant Folder Access",
            message: "Select a folder that Shark should have permission to access."
        ) else {
            return
        }
        
        settingsManager.addAuthorizedFolder(url)
        authorizedFolders = settingsManager.authorizedFolders
    }
    
    private var componentsSearchPathSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Components Search Path:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Specify the directory where Shark should look for your reusable components.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 6) {
                Text(componentsSearchPath.isEmpty ? "Not set" : componentsSearchPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(componentsSearchPath.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                
                if !componentsSearchPath.isEmpty {
                    Button(action: {
                        let url = URL(fileURLWithPath: componentsSearchPath)
                        NSWorkspace.shared.open(url)
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
            }
            
            Button("Set Path...") {
                selectComponentsSearchPath()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    private func selectComponentsSearchPath() {
        guard let url = FileDialogHelper.selectFolder(
            title: "Select Components Search Path",
            message: "Choose a folder containing your components"
        ) else {
            return
        }
        
        settingsManager.saveComponentsSearchPathBookmark(url)
        componentsSearchPath = url.path
    }
    
    private var settingsSavingFolderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings Saving Folder:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Choose where your workspace configurations and app settings are stored.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Dropdown
            Picker("", selection: $selectedLocationType) {
                ForEach(LocationType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180, alignment: .leading)
            
            // Path display with arrow icon
            HStack(spacing: 6) {
                Text(displayPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                
                Button(action: {
                    openFolderInFinder()
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
            .padding(.leading, 0)
            
            // Change button (only show for custom)
            if selectedLocationType == .custom {
                Button("Change...") {
                    selectSettingsFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var displayPath: String {
        if selectedLocationType == .default {
            return settingsManager.defaultSettingsFolderPath
        } else {
            return settingsFolderPath.isEmpty ? settingsManager.defaultSettingsFolderPath : settingsFolderPath
        }
    }
    
    private func selectSettingsFolder() {
        guard let url = FileDialogHelper.selectFolder(
            title: "Select Settings Saving Folder",
            message: "Choose a folder where Shark will save your workspace files"
        ) else {
            return
        }
        
        // Persist access to this folder across app launches
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "settingsFolderBookmark")
            
            // Start accessing the security-scoped resource
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("Failed to create security-scoped bookmark: \(error)")
        }
        
        settingsFolderPath = url.path
        selectedLocationType = .custom
        
        // Refresh workspaces after changing storage path
        WorkspaceManager.shared.refreshWorkspaces()
    }
    
    private func openFolderInFinder() {
        let path = displayPath
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
    
    private var terminalAppSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Terminal Application:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Choose the terminal application to use when opening folders in terminal.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Picker("Terminal App", selection: $selectedTerminalApp) {
                ForEach(TerminalApp.allCases) { app in
                    let isInstalled = app.isInstalled
                    Text(app.displayName + (isInstalled ? "" : " (Not Installed)"))
                        .tag(app)
                        .foregroundColor(isInstalled ? .primary : .secondary)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300, alignment: .leading)
            
            // Show installed apps info
            let installedApps = TerminalApp.allCases.filter { $0 != .systemDefault && $0.isInstalled }
            if !installedApps.isEmpty {
                Text("Detected: \(installedApps.map { $0.displayName }.joined(separator: ", "))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            // Custom terminal app selection
            Button("Select Custom Terminal App...") {
                selectCustomTerminalApp()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
    }
    
    private func selectCustomTerminalApp() {
        guard let window = NSApp.mainWindow else { return }
        
        let dialog = NSOpenPanel()
        dialog.title = "Select Terminal Application"
        dialog.showsHiddenFiles = false
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        
        // Set default directory to Applications
        dialog.directoryURL = URL(fileURLWithPath: "/Applications")
        
        // Filter for app bundles using allowedFileTypes
        dialog.allowedFileTypes = ["app"]
        
        dialog.beginSheetModal(for: window) { result in
            guard result == .OK, let appURL = dialog.url else { return }
            
            // Get the bundle identifier
            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else {
                print("Could not get bundle identifier for selected app")
                return
            }
            
            print("Selected terminal app: \(appURL.lastPathComponent) (bundle: \(bundleId))")
            
            // Save to UserDefaults for future use
            UserDefaults.standard.set(appURL.path, forKey: "customTerminalAppPath")
            UserDefaults.standard.set(bundleId, forKey: "customTerminalAppBundleId")
            
            // Show confirmation
            let alert = NSAlert()
            alert.messageText = "Terminal App Selected"
            alert.informativeText = "\(appURL.lastPathComponent) has been selected as your custom terminal app.\n\nYou can now right-click on any folder and select 'Open in Terminal' to use this app."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

#Preview {
    SettingsView()
}

