import Testing
import Foundation
@testable import SendToClaw

@Suite("AppState Tests")
@MainActor
struct AppStateTests {

    @Test("Initial state is idle")
    func initialState() {
        let appState = AppState()
        #expect(appState.recordingState == .idle)
        #expect(appState.transcribedText == "")
        #expect(appState.liveTranscription == "")
        #expect(appState.isConnected == false)
        #expect(appState.isPanelVisible == false)
    }

    @Test("RecordingState equality")
    func recordingStateEquality() {
        #expect(RecordingState.idle == RecordingState.idle)
        #expect(RecordingState.recording == RecordingState.recording)
        #expect(RecordingState.reviewing == RecordingState.reviewing)
        #expect(RecordingState.sending == RecordingState.sending)
        #expect(RecordingState.sent == RecordingState.sent)
        #expect(RecordingState.error("a") == RecordingState.error("a"))
        #expect(RecordingState.error("a") != RecordingState.error("b"))
        #expect(RecordingState.idle != RecordingState.recording)
    }

    @Test("stopRecording copies liveTranscription to transcribedText when empty")
    func stopRecordingCopiesLiveText() {
        let appState = AppState()
        appState.recordingState = .recording
        appState.liveTranscription = "Hello world"
        appState.transcribedText = ""

        appState.stopRecording()

        #expect(appState.transcribedText == "Hello world")
        #expect(appState.recordingState == .reviewing)
    }

    @Test("stopRecording preserves existing transcribedText")
    func stopRecordingPreservesText() {
        let appState = AppState()
        appState.recordingState = .recording
        appState.liveTranscription = "partial"
        appState.transcribedText = "final result"

        appState.stopRecording()

        #expect(appState.transcribedText == "final result")
    }

    @Test("hidePanel resets all state")
    func hidePanelResetsState() {
        let appState = AppState()
        appState.recordingState = .reviewing
        appState.transcribedText = "some text"
        appState.liveTranscription = "some text"
        appState.isPanelVisible = true

        appState.hidePanel()

        #expect(appState.recordingState == .idle)
        #expect(appState.transcribedText == "")
        #expect(appState.liveTranscription == "")
        #expect(appState.isPanelVisible == false)
    }

    @Test("send rejects empty text")
    func sendRejectsEmptyText() {
        let appState = AppState()
        appState.recordingState = .reviewing
        appState.transcribedText = "   "

        appState.send()

        // Should still be in reviewing state since text was blank
        #expect(appState.recordingState == .reviewing)
    }
}
