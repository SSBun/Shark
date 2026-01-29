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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .frame(width: 620, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            settingsFolderPath = settingsManager.settingsFolderPath
            componentsSearchPath = settingsManager.componentsSearchPath
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
    }
    
    private var componentsSearchPathSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Components Search Path:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
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
            Text("Settings Saving Folder:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
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
}

#Preview {
    SettingsView()
}

