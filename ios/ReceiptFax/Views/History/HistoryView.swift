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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if message.status == "failed" { failedMessage = message }
                            }
                    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(message.body ?? (message.imagePath != nil ? "📷 Image" : ""))
                    .lineLimit(2)
                Spacer()
                StatusBadge(status: message.status)
            }
            Text(message.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
