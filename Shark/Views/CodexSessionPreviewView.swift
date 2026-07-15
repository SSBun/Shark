//
//  CodexSessionPreviewView.swift
//  Shark
//

import SwiftUI

struct CodexSessionPreviewView: View {
    static let windowID = "codex-session-preview"
    static let windowTitle = "Codex Session Preview"

    @Environment(CodexSessionPreviewStore.self) private var store

    var body: some View {
        Group {
            if let session = store.session {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(session.title)
                                .font(.title2)
                                .bold()
                                .lineLimit(2)

                            Spacer()

                            Label(runtimeTitle(for: session), systemImage: runtimeSystemImage(for: session))
                                .font(.subheadline)
                                .foregroundStyle(runtimeColor(for: session))
                        }

                        HStack(spacing: 16) {
                            Label {
                                Text(session.updatedAt, format: .dateTime.year().month().day().hour().minute())
                            } icon: {
                                Image(systemName: "clock")
                            }

                            if let model = session.model, !model.isEmpty {
                                Label(model, systemImage: "cpu")
                            }

                            if let source = session.source, !source.isEmpty {
                                Label(source, systemImage: "terminal")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        LabeledContent("Working Directory") {
                            Text(session.cwd)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(20)

                    Divider()

                    CodexSessionPreviewContentView(loadState: store.loadState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    HStack {
                        Menu("More", systemImage: "ellipsis.circle") {
                            Button("Show in Finder", systemImage: "folder", action: showInFinder)
                                .disabled(!store.isSessionFileReadable)
                            Button("Copy Session ID", systemImage: "number", action: copySessionID)
                        }

                        Spacer()

                        Button(primaryActionTitle(for: session), systemImage: primaryActionSystemImage(for: session), action: performPrimaryAction)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(!session.runtimeState.isRunningInTerminal && !store.isSessionFileReadable)
                    }
                    .padding(12)
                    .background(.bar)
                }
            } else {
                ContentUnavailableView(
                    "No Session Selected",
                    systemImage: "text.bubble",
                    description: Text("Double-click a Codex session to preview it.")
                )
            }
        }
        .frame(minWidth: 560, minHeight: 400)
    }

    private func runtimeTitle(for session: CodexSession) -> String {
        session.runtimeState.isRunningInTerminal ? "Running" : "Not Running"
    }

    private func runtimeSystemImage(for session: CodexSession) -> String {
        session.runtimeState.isRunningInTerminal ? "circle.fill" : "circle"
    }

    private func runtimeColor(for session: CodexSession) -> Color {
        session.runtimeState.isRunningInTerminal ? .green : .secondary
    }

    private func primaryActionTitle(for session: CodexSession) -> String {
        session.runtimeState.isRunningInTerminal ? "Jump to iTerm" : "Resume in Terminal"
    }

    private func primaryActionSystemImage(for session: CodexSession) -> String {
        session.runtimeState.isRunningInTerminal ? "arrow.up.forward.square" : "terminal"
    }

    private func performPrimaryAction() {
        guard let session = store.session else { return }

        if session.runtimeState.isRunningInTerminal {
            TerminalOpener.jumpToITermTab(
                iTermSessionID: session.runtimeState.iTermSessionID,
                tty: session.runtimeState.terminalTTY
            )
        } else {
            TerminalOpener.runCommands([
                (executable: "codex", arguments: ["resume", session.id], folder: session.cwd)
            ])
        }
    }

    private func showInFinder() {
        guard let session = store.session else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: session.filePath)])
    }

    private func copySessionID() {
        guard let session = store.session else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.id, forType: .string)
    }
}

#Preview {
    CodexSessionPreviewView()
        .environment(CodexSessionPreviewStore())
}
