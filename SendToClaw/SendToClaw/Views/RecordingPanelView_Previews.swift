import SwiftUI

private func sampleAppState(
    state: RecordingState,
    text: String = "",
    live: String = "",
    level: Float = 0.4,
    connected: Bool = true,
    channelName: String = "Office"
) -> AppState {
    let a = AppState()
    a.recordingState = state
    a.transcribedText = text
    a.liveTranscription = live
    a.audioLevel = level
    a.isConnected = connected
    a.connectedChannelName = connected ? channelName : ""
    return a
}

#Preview("Recording") {
    RecordingPanelView(appState: sampleAppState(state: .recording, live: "Hello from preview", level: 0.7))
        .padding(40)
        .background(.black.opacity(0.5))
}

#Preview("Reviewing") {
    RecordingPanelView(appState: sampleAppState(state: .reviewing, text: "Transcribed text ready to send"))
        .padding(40)
        .background(.black.opacity(0.5))
}

#Preview("Sending") {
    RecordingPanelView(appState: sampleAppState(state: .sending, text: "Sending message…"))
        .padding(40)
        .background(.black.opacity(0.5))
}

#Preview("Sent") {
    RecordingPanelView(appState: sampleAppState(state: .sent, text: "Sent!"))
        .padding(40)
        .background(.black.opacity(0.5))
}

#Preview("Error") {
    RecordingPanelView(appState: sampleAppState(state: .error("Network error"), text: "Hello"))
        .padding(40)
        .background(.black.opacity(0.5))
}
