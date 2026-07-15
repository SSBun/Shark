//
//  CodexSessionPreviewMessageView.swift
//  Shark
//

import SwiftUI

struct CodexSessionPreviewMessageView: View {
    let message: CodexSessionPreview.Message

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(roleTitle, systemImage: roleSystemImage)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(roleColor)

                Spacer()

                if let timestamp = message.timestamp {
                    Text(timestamp, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(message.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private var roleTitle: String {
        switch message.role {
        case .user:
            "User"
        case .assistant:
            "Assistant"
        }
    }

    private var roleSystemImage: String {
        switch message.role {
        case .user:
            "person.fill"
        case .assistant:
            "sparkles"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user:
            .accentColor
        case .assistant:
            .secondary
        }
    }
}
