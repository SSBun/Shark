//
//  ComponentGitPanel.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/26.
//

import SwiftUI

struct GitPanelView: View {
    let folder: Folder
    @StateObject private var gitManager = GitManager.shared
    @State private var repositoryStatus: GitRepositoryStatus = GitRepositoryStatus()
    @State private var branches: [GitBranch] = []
    @State private var isLoading: Bool = true
    @State private var showCommitSheet: Bool = false
    @State private var showBranchSheet: Bool = false
    @State private var commitMessage: String = ""
    @State private var newBranchName: String = ""
    @State private var selectedBranch: GitBranch?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(folder.path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            if isLoading {
                ProgressView("Loading Git status...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Status Overview
                        statusOverview
                        
                        Divider()
                        
                        // Quick Actions
                        quickActions
                        
                        Divider()
                        
                        // Branches
                        branchesSection
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Refresh") {
                    Task { await loadData() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(gitManager.isOperationInProgress)
                
                Spacer()
                
                if gitManager.isOperationInProgress {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Operation in progress...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .onAppear {
            Task { await loadData() }
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitSheet(
                commitMessage: $commitMessage,
                onCommit: { performCommit() }
            )
        }
        .sheet(isPresented: $showBranchSheet) {
            BranchSheet(
                branches: branches,
                selectedBranch: $selectedBranch,
                newBranchName: $newBranchName,
                onCheckout: { checkoutBranch() },
                onCreate: { createBranch() }
            )
        }
    }
    
    private var statusOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.branch")
                    .foregroundColor(.accentColor)
                Text("Repository Status")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            
            HStack(spacing: 16) {
                StatusBadge(
                    icon: repositoryStatus.isClean ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    value: repositoryStatus.isClean ? "Clean" : "Modified",
                    color: repositoryStatus.isClean ? .green : .orange
                )
                
                StatusBadge(
                    icon: "arrow.up.circle.fill",
                    value: "\(repositoryStatus.aheadCount) ahead",
                    color: .blue
                )
                
                StatusBadge(
                    icon: "arrow.down.circle.fill",
                    value: "\(repositoryStatus.behindCount) behind",
                    color: .purple
                )
            }
            
            if !repositoryStatus.isClean {
                HStack(spacing: 16) {
                    if repositoryStatus.modifiedFiles > 0 {
                        StatusBadge(
                            icon: "doc.fill",
                            value: "\(repositoryStatus.modifiedFiles) modified",
                            color: .orange
                        )
                    }
                    if repositoryStatus.stagedFiles > 0 {
                        StatusBadge(
                            icon: "plus.circle.fill",
                            value: "\(repositoryStatus.stagedFiles) staged",
                            color: .green
                        )
                    }
                    if repositoryStatus.untrackedFiles > 0 {
                        StatusBadge(
                            icon: "questionmark.circle.fill",
                            value: "\(repositoryStatus.untrackedFiles) untracked",
                            color: .gray
                        )
                    }
                }
            }
            
            if repositoryStatus.hasConflicts {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Conflicts detected - resolve before committing")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.accentColor)
                Text("Quick Actions")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                GitActionButton(
                    title: "Pull",
                    icon: "arrow.down.circle",
                    isLoading: false
                ) {
                    performGitOperation(.pull)
                }
                
                GitActionButton(
                    title: "Push",
                    icon: "arrow.up.circle",
                    isLoading: false
                ) {
                    performGitOperation(.push)
                }
                
                GitActionButton(
                    title: "Fetch",
                    icon: "arrow.triangle.2.circlepath",
                    isLoading: false
                ) {
                    performGitOperation(.fetch)
                }
                
                GitActionButton(
                    title: "Commit",
                    icon: "checkmark.circle",
                    isLoading: false
                ) {
                    showCommitSheet = true
                }
                
                GitActionButton(
                    title: "Stash",
                    icon: "tray.and.arrow.down",
                    isLoading: false
                ) {
                    performGitOperation(.stash)
                }
                
                GitActionButton(
                    title: "Branch",
                    icon: "arrow.branch",
                    isLoading: false
                ) {
                    showBranchSheet = true
                }
            }
        }
    }
    
    private var branchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.branch")
                    .foregroundColor(.accentColor)
                Text("Branches")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(repositoryStatus.currentBranch)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(4)
            }
            
            if branches.isEmpty {
                Text("No branches found")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(branches.filter { !$0.isRemote }.prefix(5)) { branch in
                    BranchRow(branch: branch) {
                        performGitOperation(.checkout(branch: branch.name))
                    }
                }
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        repositoryStatus = await gitManager.getRepositoryStatus(at: folder.path)
        branches = await gitManager.getBranches(at: folder.path)
        isLoading = false
    }
    
    private func performGitOperation(_ operation: GitOperation) {
        Task {
            do {
                let result = try await gitManager.runGitOperation(operation, at: folder.path)
                await loadData()
                
                if !result.isEmpty {
                    AlertManager.shared.success(result, title: "Git Operation Completed")
                }
            } catch {
                AlertManager.shared.error(error.localizedDescription, title: "Git Operation Failed")
            }
        }
    }
    
    private func performCommit() {
        guard !commitMessage.isEmpty else {
            AlertManager.shared.warning("Please enter a commit message")
            return
        }
        
        showCommitSheet = false
        performGitOperation(.commit(message: commitMessage))
        commitMessage = ""
    }
    
    private func checkoutBranch() {
        guard let branch = selectedBranch else { return }
        showBranchSheet = false
        performGitOperation(.checkout(branch: branch.name))
    }
    
    private func createBranch() {
        guard !newBranchName.isEmpty else {
            AlertManager.shared.warning("Please enter a branch name")
            return
        }
        
        showBranchSheet = false
        performGitOperation(.createBranch(name: newBranchName))
        newBranchName = ""
    }
}

struct StatusBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

struct GitActionButton: View {
    let title: String
    let icon: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                }
                Text(title)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct BranchRow: View {
    let branch: GitBranch
    let onCheckout: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.branch")
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? .accentColor : .secondary)
            
            Text(branch.name)
                .font(.system(size: 12))
                .foregroundColor(branch.isCurrent ? .primary : .secondary)
            
            if branch.isCurrent {
                Text("current")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .cornerRadius(2)
            }
            
            Spacer()
            
            if !branch.isCurrent {
                Button("Checkout") {
                    onCheckout()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CommitSheet: View {
    @Binding var commitMessage: String
    let onCommit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create Commit")
                .font(.headline)
            
            TextEditor(text: $commitMessage)
                .font(.system(size: 13))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Commit") {
                    onCommit()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(commitMessage.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

struct BranchSheet: View {
    let branches: [GitBranch]
    @Binding var selectedBranch: GitBranch?
    @Binding var newBranchName: String
    let onCheckout: () -> Void
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Manage Branches")
                .font(.headline)
            
            // Existing branches
            if !branches.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(branches.filter { !$0.isRemote }) { branch in
                            Button(action: {
                                selectedBranch = branch
                            }) {
                                HStack {
                                    Image(systemName: "arrow.branch")
                                        .foregroundColor(branch.isCurrent ? .accentColor : .secondary)
                                    Text(branch.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if branch.isCurrent {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(selectedBranch?.id == branch.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            
            Divider()
            
            // Create new branch
            VStack(alignment: .leading, spacing: 8) {
                Text("Create new branch")
                    .font(.system(size: 12, weight: .medium))
                
                HStack {
                    TextField("branch-name", text: $newBranchName)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Create") {
                        onCreate()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newBranchName.isEmpty)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Checkout") {
                    onCheckout()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedBranch == nil)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

#Preview("Git Panel") {
    GitPanelView(
        folder: Folder(name: "TestRepo", path: "/tmp/test")
    )
}
