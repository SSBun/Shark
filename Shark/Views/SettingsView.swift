//
//  SettingsView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar Header
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Detail View
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .components:
                    ComponentsSettingsView()
                case .access:
                    AccessSettingsView()
                case .terminal:
                    TerminalSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case components = "Components"
    case access = "Access"
    case terminal = "Terminal"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .components: return "square.grid.3x1.below.line.grid.1x2"
        case .access: return "folder.badge.gearshape"
        case .terminal: return "terminal"
        }
    }
}

struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.rawValue)
                    .font(.system(size: 11))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                VStack {
                    Spacer()
                    if isSelected {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @State private var settingsFolderPath: String = ""
    @State private var selectedLocationType: LocationType = .default
    private let settingsManager = SettingsManager.shared

    enum LocationType: String, CaseIterable {
        case `default` = "Default"
        case custom = "Custom"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Settings Saving Folder
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings Saving Folder")
                        .font(.headline)

                    Text("Choose where your workspace configurations and app settings are stored.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Picker("Location:", selection: $selectedLocationType) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)

                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(displayPath)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                        Spacer()
                        Button(action: openFolderInFinder) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    if selectedLocationType == .custom {
                        Button("Change...") {
                            selectSettingsFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            settingsFolderPath = settingsManager.settingsFolderPath
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
                WorkspaceManager.shared.refreshWorkspaces()
            }
        }
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
        ) else { return }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "settingsFolderBookmark")
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("Failed to create security-scoped bookmark: \(error)")
        }

        settingsFolderPath = url.path
        selectedLocationType = .custom
        settingsManager.settingsFolderPath = url.path
        WorkspaceManager.shared.refreshWorkspaces()
    }

    private func openFolderInFinder() {
        let path = displayPath
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Components Settings

struct ComponentsSettingsView: View {
    @State private var componentsSearchPath: String = ""
    private let settingsManager = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Components Search Path")
                        .font(.headline)

                    Text("Specify the directory where Shark should look for your reusable components.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(componentsSearchPath.isEmpty ? "Not set" : componentsSearchPath)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(componentsSearchPath.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                        Spacer()
                        if !componentsSearchPath.isEmpty {
                            Button(action: {
                                let url = URL(fileURLWithPath: componentsSearchPath)
                                NSWorkspace.shared.open(url)
                            }) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    Button("Set Path...") {
                        selectComponentsSearchPath()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onAppear {
            componentsSearchPath = settingsManager.componentsSearchPath
        }
        .onChange(of: componentsSearchPath) { oldValue, newValue in
            settingsManager.componentsSearchPath = newValue
        }
    }

    private func selectComponentsSearchPath() {
        guard let url = FileDialogHelper.selectFolder(
            title: "Select Components Search Path",
            message: "Choose a folder containing your components"
        ) else { return }

        settingsManager.saveComponentsSearchPathBookmark(url)
        componentsSearchPath = url.path
    }
}

// MARK: - Access Settings

struct AccessSettingsView: View {
    @State private var authorizedFolders: [String] = []
    private let settingsManager = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Folder Access Permissions")
                        .font(.headline)

                    Text("Grant Shark permission to access specific directories on your disk. This is required for sandboxed apps to read project files.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if authorizedFolders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            VStack(spacing: 4) {
                                Text("No folders authorized")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Click below to grant access to a folder")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(30)
                        .frame(maxWidth: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(authorizedFolders, id: \.self) { path in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    Text(path)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.primary)
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
                                .padding(10)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                    }

                    Button("Grant Access to New Folder...") {
                        requestGlobalFolderAccess()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onAppear {
            authorizedFolders = settingsManager.authorizedFolders
        }
    }

    private func requestGlobalFolderAccess() {
        guard let url = FileDialogHelper.selectFolder(
            title: "Grant Folder Access",
            message: "Select a folder that Shark should have permission to access."
        ) else { return }

        settingsManager.addAuthorizedFolder(url)
        authorizedFolders = settingsManager.authorizedFolders
    }
}

// MARK: - Terminal Settings

struct TerminalSettingsView: View {
    @State private var selectedTerminalApp: TerminalApp = .systemDefault
    private let settingsManager = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Terminal Application")
                        .font(.headline)

                    Text("Choose the terminal application to use when opening folders in terminal.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(TerminalApp.allCases) { app in
                            TerminalAppRow(
                                app: app,
                                isSelected: selectedTerminalApp == app,
                                onSelect: { selectedTerminalApp = app }
                            )
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)

                    let installedApps = TerminalApp.allCases.filter { $0 != .systemDefault && $0.isInstalled }
                    if !installedApps.isEmpty {
                        Text("Detected: \(installedApps.map { $0.displayName }.joined(separator: ", "))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Button("Select Custom Terminal App...") {
                        selectCustomTerminalApp()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .onAppear {
            selectedTerminalApp = settingsManager.defaultTerminalApp
        }
        .onChange(of: selectedTerminalApp) { oldValue, newValue in
            settingsManager.defaultTerminalApp = newValue
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
        dialog.directoryURL = URL(fileURLWithPath: "/Applications")
        dialog.allowedFileTypes = ["app"]

        dialog.beginSheetModal(for: window) { result in
            guard result == .OK, let appURL = dialog.url else { return }

            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else {
                print("Could not get bundle identifier for selected app")
                return
            }

            print("Selected terminal app: \(appURL.lastPathComponent) (bundle: \(bundleId))")

            UserDefaults.standard.set(appURL.path, forKey: "customTerminalAppPath")
            UserDefaults.standard.set(bundleId, forKey: "customTerminalAppBundleId")

            let alert = NSAlert()
            alert.messageText = "Terminal App Selected"
            alert.informativeText = "\(appURL.lastPathComponent) has been selected as your custom terminal app."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

struct TerminalAppRow: View {
    let app: TerminalApp
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    if !app.isInstalled && app != .systemDefault {
                        Text("Not Installed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
