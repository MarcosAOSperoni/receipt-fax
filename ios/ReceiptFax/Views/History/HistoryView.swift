import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var messageStore: MessageStore
    @StateObject private var viewModel = HistoryViewModel()
    @State private var failedMessage: MessageResponse?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && messageStore.messages.isEmpty {
                    ProgressView()
                } else if messageStore.messages.isEmpty {
                    emptyStateView
                } else {
                    List(messageStore.messages) { message in
                        MessageRow(message: message)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if message.status == "failed" { failedMessage = message }
                            }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            Task { await viewModel.refresh(apiClient: appState.apiClient, store: messageStore) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh(apiClient: appState.apiClient, store: messageStore)
        }
        .sheet(item: $failedMessage) { message in
            FailedMessageSheet(message: message) {
                failedMessage = nil
                Task { await viewModel.resend(message: message, apiClient: appState.apiClient, store: messageStore) }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if #available(iOS 17, *) {
            ContentUnavailableView(
                "No Messages",
                systemImage: "printer",
                description: Text("Messages you send will appear here.")
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "printer")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Messages")
                    .font(.title2.bold())
                Text("Messages you send will appear here.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

struct MessageRow: View {
    let message: MessageResponse

    private var displayLines: [RichLine] {
        if let rich = message.richBody { return rich }
        let text = message.body ?? (message.imagePath != nil ? "Image" : "")
        return [RichLine(
            size: message.style.size,
            align: message.style.align,
            spans: [RichSpan(text: text, bold: message.style.bold)]
        )]
    }

    private var statusAccentColor: Color {
        switch message.status {
        case "printed": return .green
        case "failed":  return .red
        default:        return Color(.tertiaryLabel)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(statusAccentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    RichMessageView(richLines: displayLines, compact: true, font: message.font ?? "monospace")
                        .lineLimit(2)
                    Spacer()
                    StatusBadge(status: message.status)
                }
                Text(message.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case "printed": return "Printed ✓"
        case "failed":  return "Failed ✗"
        default:        return "Pending"
        }
    }

    private var badgeColor: Color {
        switch status {
        case "printed": return .green
        case "failed":  return .red
        default:        return Color(UIColor.secondaryLabel)
        }
    }
}

struct FailedMessageSheet: View {
    let message: MessageResponse
    let onResend: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if let reason = message.failureReason {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failure Reason").font(.headline)
                        Text(reason)
                            .foregroundStyle(.red)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }

                if let body = message.body {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message").font(.headline)
                        Text(body)
                    }
                }

                if message.body == nil {
                    Text("Image-only messages cannot be resent from History. Compose a new message with a new photo.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                if message.body != nil {
                    Button("Resend Message") { onResend() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Failed Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
