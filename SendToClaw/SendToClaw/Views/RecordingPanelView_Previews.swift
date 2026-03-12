import SwiftUI

private func sampleAppState(
    state: RecordingState,
    text: String = "",
    live: String = "",
    level: Float = 0.4,
    connected: Bool = true,
    channelName: String = "Preview Channel"
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

#Preview("Idle") {
    RecordingPanelView(appState: sampleAppState(state: .idle))
        .frame(width: 420, height: 320)
}

#Preview("Recording") {
    RecordingPanelView(appState: sampleAppState(state: .recording, live: "Listening… Hello from preview", level: 0.7))
        .frame(width: 420, height: 320)
}

#Preview("Reviewing") {
    RecordingPanelView(appState: sampleAppState(state: .reviewing, text: "Transcribed text ready to send"))
        .frame(width: 420, height: 320)
}

#Preview("Sending") {
    RecordingPanelView(appState: sampleAppState(state: .sending, text: "Sending message…"))
        .frame(width: 420, height: 320)
}

#Preview("Sent") {
    RecordingPanelView(appState: sampleAppState(state: .sent, text: "Sent!"))
        .frame(width: 420, height: 320)
}

#Preview("Error") {
    RecordingPanelView(appState: sampleAppState(state: .error("Network error"), text: "Hello"))
        .frame(width: 420, height: 320)
}
