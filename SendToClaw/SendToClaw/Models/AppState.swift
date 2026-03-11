import SwiftUI
import Combine

enum RecordingState: Equatable {
    case idle
    case recording
    case reviewing
    case sending
    case sent
    case error(String)
}

@MainActor
class AppState: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var transcribedText = ""
    @Published var liveTranscription = ""
    @Published var isConnected = false
    @Published var isPanelVisible = false
    @Published var audioLevel: Float = 0

    let speechService = SpeechRecognitionService()
    let openClawService = OpenClawService()
    let configService = ConfigService()
    let hotkeyService = HotkeyService()
    let panelController = FloatingPanelController()

    func setup() {
        hotkeyService.register { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }

        Task {
            await connectToOpenClaw()
        }
    }

    func togglePanel() {
        if isPanelVisible {
            cancel()
        } else {
            showPanelAndRecord()
        }
    }

    func showPanelAndRecord() {
        isPanelVisible = true
        panelController.show(appState: self)
        startRecording()
    }

    func startRecording() {
        recordingState = .recording
        liveTranscription = ""
        transcribedText = ""
        audioLevel = 0

        // Wire up audio level callback
        speechService.onAudioLevel = { [weak self] level in
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        speechService.startRecognition(
            onPartialResult: { [weak self] text in
                Task { @MainActor in
                    self?.liveTranscription = text
                }
            },
            onFinalResult: { [weak self] text in
                Task { @MainActor in
                    self?.transcribedText = text
                    self?.liveTranscription = text
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.recordingState = .error(error)
                }
            }
        )
    }

    func stopRecording() {
        speechService.stopRecognition()
        audioLevel = 0
        if transcribedText.isEmpty {
            transcribedText = liveTranscription
        }
        recordingState = .reviewing
    }

    func send() {
        guard !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        recordingState = .sending

        Task {
            do {
                if !isConnected {
                    await connectToOpenClaw()
                }
                try await openClawService.sendMessage(text: transcribedText)
                recordingState = .sent

                try? await Task.sleep(for: .seconds(1))
                hidePanel()
            } catch {
                recordingState = .error(error.localizedDescription)
            }
        }
    }

    func cancel() {
        speechService.stopRecognition()
        hidePanel()
    }

    func hidePanel() {
        panelController.hide()
        isPanelVisible = false
        recordingState = .idle
        transcribedText = ""
        liveTranscription = ""
        audioLevel = 0
    }

    func connectToOpenClaw() async {
        do {
            let config = try configService.loadConfig()
            try await openClawService.connect(config: config)
            isConnected = true
        } catch {
            isConnected = false
            print("OpenClaw connection failed: \(error)")
        }
    }

    func reconnect() {
        Task {
            await connectToOpenClaw()
        }
    }
}
