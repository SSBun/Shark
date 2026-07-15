//
//  CodexSessionPreviewStore.swift
//  Shark
//

import Foundation
import Observation

@MainActor
@Observable
final class CodexSessionPreviewStore {
    enum LoadState {
        case idle
        case loading
        case loaded(CodexSessionPreview)
        case failed(String)
    }

    private(set) var session: CodexSession?
    private(set) var loadState: LoadState = .idle
    private(set) var isSessionFileReadable = false

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// Starts loading the preview for the selected Codex session.
    func loadPreview(for session: CodexSession) {
        loadTask?.cancel()
        self.session = session
        loadState = .loading
        isSessionFileReadable = FileManager.default.isReadableFile(atPath: session.filePath)

        let fileURL = URL(fileURLWithPath: session.filePath)
        loadTask = Task {
            do {
                let preview = try await CodexSessionPreviewLoader.load(from: fileURL)
                try Task.checkCancellation()
                loadState = .loaded(preview)
            } catch is CancellationError {
                return
            } catch {
                loadState = .failed(error.localizedDescription)
            }
        }
    }
}
