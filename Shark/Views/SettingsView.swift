//
//  SettingsView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

// MARK: - Settings Tab (Seahorse-style: TabView with tabItem)

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case folders = "Folders"
    case terminal = "Terminal"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .folders: return "folder.badge.plus"
        case .terminal: return "terminal"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
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
        TabView(selection: $selectedTab) {
            generalTabContent
                .tabItem { Label("General", systemImage: SettingsTab.general.icon) }
                .tag(SettingsTab.general)

            foldersTabContent
                .tabItem { Label("Folders", systemImage: SettingsTab.folders.icon) }
                .tag(SettingsTab.folders)

            terminalTabContent
                .tabItem { Label("Terminal", systemImage: SettingsTab.terminal.icon) }
                .tag(SettingsTab.terminal)

            advancedTabContent
                .tabItem { Label("Advanced", systemImage: SettingsTab.advanced.icon) }
                .tag(SettingsTab.advanced)
        }
        .frame(width: 600, height: 500)
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

    // MARK: - General Tab (Seahorse-style: ScrollView + sections with Dividers)

    private var generalTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Settings saving folder
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings saving folder")
                        .font(.system(size: 13, weight: .semibold))
                    Picker("", selection: $selectedLocationType) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 300)
                    HStack(spacing: 8) {
                        Text(displayPath)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        if selectedLocationType == .custom {
                            Button("Change...") { selectSettingsFolder() }
                        }
                        Button(action: openFolderInFinder) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                    Text("Choose where your workspace configurations and app settings are stored.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Divider()
                // Components search path
                VStack(alignment: .leading, spacing: 10) {
                    Text("Components search path")
                        .font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 8) {
                        Text(componentsSearchPath.isEmpty ? "Not set" : componentsSearchPath)
                            .font(.system(size: 12))
                            .foregroundStyle(componentsSearchPath.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        Button("Set Path...") { selectComponentsSearchPath() }
                        if !componentsSearchPath.isEmpty {
                            Button(action: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: componentsSearchPath))
                            }) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }
                    }
                    Text("Specify the directory where Shark should look for your reusable components.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(30)
        }
    }

    // MARK: - Folders Tab

    private var foldersTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Folder access permissions")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Grant Shark permission to access specific directories on your disk. This is required for sandboxed apps to read project files.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if !authorizedFolders.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
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
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                    }
                    Button("Grant Access to New Folder...") { requestGlobalFolderAccess() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
            .padding(30)
        }
    }

    // MARK: - Terminal Tab

    private var terminalTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Default terminal application")
                        .font(.system(size: 13, weight: .semibold))
                    Picker("Terminal App", selection: $selectedTerminalApp) {
                        ForEach(TerminalApp.allCases) { app in
                            let isInstalled = app.isInstalled
                            Text(app.displayName + (isInstalled ? "" : " (Not Installed)"))
                                .tag(app)
                                .foregroundColor(isInstalled ? .primary : .secondary)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 300)
                    if !TerminalApp.allCases.filter({ $0 != .systemDefault && $0.isInstalled }).isEmpty {
                        let installed = TerminalApp.allCases.filter { $0 != .systemDefault && $0.isInstalled }
                        Text("Detected: \(installed.map { $0.displayName }.joined(separator: ", "))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Button("Select Custom Terminal App...") { selectCustomTerminalApp() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Text("Choose the terminal application to use when opening folders in terminal.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(30)
        }
    }

    // MARK: - Advanced Tab

    @StateObject private var updateManager = UpdateManager.shared

    private var advancedTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // About Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("About")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Shark helps you manage Cursor IDE workspace files and organize your projects.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Version Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Version")
                        .font(.system(size: 13, weight: .semibold))
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Version: \(updateManager.currentVersion) (\(updateManager.buildNumber))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            updateStatusView
                        }
                        Spacer()
                        Button("Check for Updates") {
                            Task {
                                await updateManager.checkForUpdates()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(updateManager.updateStatus == .checking)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(30)
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateManager.updateStatus {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Checking for updates...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .updateAvailable(let version):
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.green)
                Text("Update available: v\(version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Button("Download") {
                    updateManager.openReleasePage()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }
        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                Text("You're up to date!")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Error: \(message)")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
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

