import SwiftUI
import Foundation

struct RecordingPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            // Main bar
            HStack(spacing: 12) {
                Image("Background")
                    .resizable()
                    .frame(width: 36, height: 36)

                // Center area: waveform when recording, text otherwise
                Group {
                    if appState.recordingState == .recording {
                        WaveformView(level: appState.audioLevel)
                    } else {
                        Text(displayText)
                            .font(.system(size: 14))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 28)

                statusBadge
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: 600)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 48))

            // Live transcription below the bar
            if !appState.liveTranscription.isEmpty {
                Text(appState.liveTranscription)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .shadow(color: .black, radius: 3, x: 0, y: 1)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
        }
        .frame(width: 600)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch appState.recordingState {
        case .recording:
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Recording")
                    .font(.caption)
            }
            .foregroundStyle(.red)
        case .sending:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Sending")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        case .sent:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                Text("Sent")
                    .font(.caption)
            }
            .foregroundStyle(.green)
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                Text(msg)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }

    private var displayText: String {
        switch appState.recordingState {
        case .reviewing:
            return appState.transcribedText.isEmpty ? "No transcription" : appState.transcribedText
        case .sending:
            return appState.transcribedText
        case .sent:
            return "Message sent"
        case .error:
            return appState.transcribedText
        case .idle:
            return "Ready"
        case .recording:
            return ""
        }
    }

    private var textColor: Color {
        switch appState.recordingState {
        case .sent: return .green
        case .error: return .red
        case .idle: return .secondary
        default: return .primary
        }
    }
}

/// Animated waveform visualization for recording state
struct WaveformView: View {
    let level: Float
    private let barCount = 40

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<barCount, id: \.self) { index in
                let normalizedIndex = Float(index) / Float(barCount)
                // Create a wave shape centered at the current level
                let distance = abs(normalizedIndex - 0.5) * 2.0
                let height = max(0.08, (1.0 - distance) * level)
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: height))
                    .frame(height: CGFloat(height) * 28)
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
    }

    private func barColor(for height: Float) -> Color {
        if height > 0.7 {
            return .red
        } else if height > 0.4 {
            return .orange
        } else {
            return .green
        }
    }
}

/// Legacy bar-style audio level view (kept for compatibility)
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
