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

enum GitStatus: String {
    case clean = "clean"
    case modified = "modified"
    case untracked = "untracked"
    case staged = "staged"
    case ahead = "ahead"
    case behind = "behind"
    case diverged = "diverged"
    case conflict = "conflict"
}

struct GitRepositoryStatus {
    var isClean: Bool
    var modifiedFiles: Int
    var untrackedFiles: Int
    var stagedFiles: Int
    var aheadCount: Int
    var behindCount: Int
    var hasConflicts: Bool
    var currentBranch: String
    var remotes: [String]
    
    init() {
        isClean = true
        modifiedFiles = 0
        untrackedFiles = 0
        stagedFiles = 0
        aheadCount = 0
        behindCount = 0
        hasConflicts = false
        currentBranch = ""
        remotes = []
    }
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
    
    private var cancellables = Set<AnyCancellable>()
    
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
                result = try await runGitCommand(["fetch", "--all"], at: repoPath)
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
    
    func getRepositoryStatus(at repoPath: String) async -> GitRepositoryStatus {
        var status = GitRepositoryStatus()
        
        // Get current branch
        if let branch = try? await runGitCommand(["branch", "--show-current"], at: repoPath) {
            status.currentBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Get status
        if let statusOutput = try? await runGitCommand(["status", "--porcelain"], at: repoPath) {
            let lines = statusOutput.split(separator: "\n")
            for line in lines {
                if line.count >= 2 {
                    let indexStatus = String(line[line.startIndex])
                    let workTreeStatus = String(line[line.index(after: line.startIndex)])
                    
                    if indexStatus == "?" || workTreeStatus == "?" {
                        status.untrackedFiles += 1
                        status.isClean = false
                    }
                    if indexStatus == "M" || indexStatus == "A" || indexStatus == "D" {
                        status.stagedFiles += 1
                        status.isClean = false
                    }
                    if workTreeStatus == "M" || workTreeStatus == "D" {
                        status.modifiedFiles += 1
                        status.isClean = false
                    }
                    if line.contains("UU") || line.contains("AA") || line.contains("DD") {
                        status.hasConflicts = true
                        status.isClean = false
                    }
                }
            }
        }
        
        // Get ahead/behind status
        if let tracking = try? await runGitCommand(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], at: repoPath) {
            let parts = tracking.split(separator: "\t")
            if parts.count == 2 {
                status.behindCount = Int(parts[0]) ?? 0
                status.aheadCount = Int(parts[1]) ?? 0
            }
        }
        
        // Get remotes
        if let remotes = try? await runGitCommand(["remote"], at: repoPath) {
            status.remotes = remotes.split(separator: "\n").map { String($0) }
        }
        
        return status
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
    
    private func runGitCommand(_ arguments: [String], at repoPath: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            task.arguments = ["-C", repoPath] + arguments
            task.standardOutput = Pipe()
            task.standardError = Pipe()
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data ?? Data(), encoding: .utf8) ?? ""
                
                if task.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errorData = (task.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData ?? Data(), encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: NSError(domain: "GitManager", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorOutput]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
