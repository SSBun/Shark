//
//  GitManager.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/26.
//

import Foundation
import Combine

enum GitOperation {
    case status
    case pull
    case push
    case fetch
    case checkout(branch: String)
    case createBranch(name: String)
    case commit(message: String)
    case stash
    case stashPop
    case clean
    case reset
}

struct GitBranch: Identifiable, Hashable {
    let id: String
    let name: String
    let isCurrent: Bool
    let isRemote: Bool
    let isAhead: Bool
    let isBehind: Bool
    let upstream: String?
    
    init(name: String, isCurrent: Bool = false, isRemote: Bool = false, isAhead: Bool = false, isBehind: Bool = false, upstream: String? = nil) {
        self.id = "\(isRemote ? "remote/" : "local/")\(name)"
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
        self.isAhead = isAhead
        self.isBehind = isBehind
        self.upstream = upstream
    }
}

@MainActor
final class GitManager: ObservableObject {
    static let shared = GitManager()
    
    @Published var isOperationInProgress: Bool = false
    @Published var operationError: String?
    @Published var lastOperationResult: String?
    
    private init() {}
    
    func runGitOperation(_ operation: GitOperation, at repoPath: String) async throws -> String {
        isOperationInProgress = true
        operationError = nil
        lastOperationResult = nil
        
        defer { isOperationInProgress = false }
        
        do {
            let result: String
            switch operation {
            case .status:
                result = try await runGitCommand(["status", "--porcelain"], at: repoPath)
            case .pull:
                result = try await runGitCommand(["pull"], at: repoPath)
            case .push:
                result = try await runGitCommand(["push"], at: repoPath)
            case .fetch:
                result = try await runGitCommand(["fetch", "--all", "--prune", "--tags"], at: repoPath)
            case .checkout(let branch):
                result = try await runGitCommand(["checkout", branch], at: repoPath)
            case .createBranch(let name):
                result = try await runGitCommand(["checkout", "-b", name], at: repoPath)
            case .commit(let message):
                result = try await runGitCommand(["commit", "-m", message], at: repoPath)
            case .stash:
                result = try await runGitCommand(["stash"], at: repoPath)
            case .stashPop:
                result = try await runGitCommand(["stash", "pop"], at: repoPath)
            case .clean:
                result = try await runGitCommand(["clean", "-fd"], at: repoPath)
            case .reset:
                result = try await runGitCommand(["reset", "--hard", "HEAD"], at: repoPath)
            }
            
            lastOperationResult = result
            return result
        } catch let error as NSError {
            operationError = error.localizedDescription
            throw error
        }
    }
    
    /// Returns the current working-tree, version tag, and upstream status for a repository.
    func repositoryStatus(at repoPath: String) async -> GitRepositoryStatus {
        do {
            let output = try await runGitCommand(
                ["status", "--porcelain=v2", "--branch", "--untracked-files=normal"],
                at: repoPath
            )
            let tag = try? await runGitCommand(
                ["for-each-ref", "--sort=-version:refname", "--count=1", "--format=%(refname:short)", "refs/tags"],
                at: repoPath
            )
            let latestTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
            return GitRepositoryStatus(
                porcelainV2: output,
                latestTag: latestTag?.isEmpty == false ? latestTag : nil
            )
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    /// Fetches remote branches and tags without changing the working tree.
    nonisolated func fetchRemoteReferences(at repoPath: String) async throws {
        _ = try await runGitCommand(
            ["fetch", "--all", "--prune", "--tags", "--quiet"],
            at: repoPath
        )
    }
    
    func getBranches(at repoPath: String) async -> [GitBranch] {
        var branches: [GitBranch] = []
        
        // Get local branches
        if let localOutput = try? await runGitCommand(["branch"], at: repoPath) {
            let lines = localOutput.split(separator: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let isCurrent = trimmed.hasPrefix("*")
                let name = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "* "))
                if !name.isEmpty {
                    branches.append(GitBranch(name: name, isCurrent: isCurrent))
                }
            }
        }
        
        // Get remote branches
        if let remoteOutput = try? await runGitCommand(["branch", "-r"], at: repoPath) {
            let lines = remoteOutput.split(separator: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.contains("HEAD") {
                    let name = trimmed.components(separatedBy: " -> ").last ?? trimmed
                    branches.append(GitBranch(name: name, isRemote: true))
                }
            }
        }
        
        return branches
    }
    
    func getStashes(at repoPath: String) async -> [(index: Int, message: String)] {
        var stashes: [(Int, String)] = []
        
        if let stashOutput = try? await runGitCommand(["stash", "list"], at: repoPath) {
            let lines = stashOutput.split(separator: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let message = trimmed.replacingOccurrences(of: "^{", with: "")
                    stashes.append((index, message))
                }
            }
        }
        
        return stashes
    }
    
    func getCommits(at repoPath: String, limit: Int = 20) async -> [(hash: String, message: String, author: String, date: Date)] {
        var commits: [(String, String, String, Date)] = []
        
        if let logOutput = try? await runGitCommand(["log", "--format=%H|%s|%an|%ad", "--date=iso", "-n", String(limit)], at: repoPath) {
            let lines = logOutput.split(separator: "\n")
            for line in lines {
                let parts = line.split(separator: "|")
                if parts.count >= 4 {
                    let hash = String(parts[0])
                    let message = String(parts[1])
                    let author = String(parts[2])
                    let dateString = String(parts[3])
                    
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let date = formatter.date(from: dateString) ?? Date()
                    
                    commits.append((hash, message, author, date))
                }
            }
        }
        
        return commits
    }
    
    private nonisolated func runGitCommand(_ arguments: [String], at repoPath: String) async throws -> String {
        try Task.checkCancellation()

        let task = Process()
        let outputPipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath] + arguments
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["GIT_TERMINAL_PROMPT": "0"],
            uniquingKeysWith: { _, newValue in newValue }
        )
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        try task.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        try Task.checkCancellation()

        let output = String(data: data, encoding: .utf8) ?? ""
        guard task.terminationStatus == 0 else {
            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "GitManager",
                code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Git command failed" : message]
            )
        }

        return output
    }
}
