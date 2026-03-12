import SwiftUI
import Foundation

struct RecordingPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            // Status bar
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(appState.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Audio level meter (visible during recording)
            if appState.recordingState == .recording {
                AudioLevelView(level: appState.audioLevel)
                    .frame(height: 30)
            }

            // Text area
            Group {
                if case .reviewing = appState.recordingState {
                    TextEditor(text: $appState.transcribedText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.background.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ScrollView {
                        Text(displayText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(8)
                    }
                    .background(.background.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(height: 160)

            // Buttons
            HStack {
                Button("Cancel") {
                    appState.cancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if appState.recordingState == .recording {
                    Button("Stop") {
                        appState.stopRecording()
                    }
                    .keyboardShortcut(.space, modifiers: [])
                } else if appState.recordingState == .idle {
                    Button("Record") {
                        appState.startRecording()
                    }
                }

                Button("Send") {
                    appState.send()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSend)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .recording: return .red
        case .reviewing: return .orange
        case .sending: return .blue
        case .sent: return .green
        case .error: return .red
        case .idle: return .gray
        }
    }

    private var statusText: String {
        switch appState.recordingState {
        case .recording: return "Recording..."
        case .reviewing: return "Review & Edit"
        case .sending: return "Sending..."
        case .sent: return "Sent!"
        case .error(let msg): return "Error: \(msg)"
        case .idle: return "Ready"
        }
    }

    private var displayText: String {
        switch appState.recordingState {
        case .recording:
            return appState.liveTranscription.isEmpty ? "Listening... (release to send)" : appState.liveTranscription
        case .sent:
            return "Message sent successfully."
        case .sending:
            return appState.transcribedText
        default:
            return appState.transcribedText.isEmpty ? appState.liveTranscription : appState.transcribedText
        }
    }

    private var canSend: Bool {
        switch appState.recordingState {
        case .reviewing:
            return !appState.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
}

/// Simple audio level visualization with animated bars
struct AudioLevelView: View {
    let level: Float
    private let barCount = 20

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let threshold = Float(index) / Float(barCount)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .opacity(level > threshold ? 1.0 : 0.15)
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
        .padding(.horizontal, 4)
    }

    private func barColor(for index: Int) -> Color {
        let ratio = Float(index) / Float(barCount)
        if ratio < 0.5 {
            return .green
        } else if ratio < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}
