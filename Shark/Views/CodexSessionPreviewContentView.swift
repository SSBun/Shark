//
//  CodexSessionPreviewContentView.swift
//  Shark
//

import SwiftUI

struct CodexSessionPreviewContentView: View {
    let loadState: CodexSessionPreviewStore.LoadState

    var body: some View {
        switch loadState {
        case .idle:
            ContentUnavailableView(
                "No Session Selected",
                systemImage: "text.bubble"
            )
        case .loading:
            ProgressView("Loading session preview...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let preview):
            if preview.initialPrompt == nil, preview.recentMessages.isEmpty {
                ContentUnavailableView(
                    "No Previewable Messages",
                    systemImage: "text.bubble",
                    description: Text("This session has no user or assistant text messages.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let initialPrompt = preview.initialPrompt {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Initial Prompt")
                                    .font(.headline)
                                CodexSessionPreviewMessageView(message: initialPrompt)
                            }
                        }

                        if !preview.recentMessages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Messages")
                                    .font(.headline)

                                ForEach(preview.recentMessages) { message in
                                    CodexSessionPreviewMessageView(message: message)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        case .failed(let message):
            ContentUnavailableView(
                "Unable to Load Preview",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }
}
