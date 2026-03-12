import SwiftUI
import Carbon
import Combine

enum RecordingState: Equatable {
    case idle
    case recording
    case reviewing
    case sending
    case sent
    case error(String)
}

enum TextInputState: Equatable {
    case idle
    case editing
    case sending
    case sent
    case error(String)
}

@MainActor
class AppState: ObservableObject {
    // Recording panel
    @Published var recordingState: RecordingState = .idle
    @Published var transcribedText = ""
    @Published var liveTranscription = ""
    @Published var isPanelVisible = false
    @Published var audioLevel: Float = 0
    @Published var selectedLocaleId: String = "" // "" = auto/system default

    // Text input panel
    @Published var textInputState: TextInputState = .idle
    @Published var textInputContent = ""
    @Published var isTextPanelVisible = false

    // Update
    @Published var updateAvailable: (version: String, url: URL, notes: String?)?
    @Published var updateCheckMessage: String?

    // Shortcuts
    @Published var recordShortcut: ShortcutConfig = .defaultRecord
    @Published var textInputShortcut: ShortcutConfig = .defaultTextInput

    // Connection
    @Published var isConnected = false

    // Channel management
    @Published var channels: [Channel] = []
    @Published var activeChannelId: UUID?
    @Published var connectedChannelName: String = ""

    let updateService = UpdateService()
    let speechService = SpeechRecognitionService()
    let openClawService = OpenClawService()
    let telegramService = TelegramService()
    let configService = ConfigService()
    let hotkeyService = HotkeyService()
    let panelController = FloatingPanelController()
    let textPanelController = FloatingPanelController()
    let channelEditController = ChannelEditWindowController()
    let shortcutSettingsController = ShortcutSettingsWindowController()

    var activeChannel: Channel? {
        channels.first { $0.id == activeChannelId }
    }

    func setup() {
        channels = configService.loadChannels()
        activeChannelId = configService.loadActiveChannelId()

        if activeChannelId == nil, let first = channels.first {
            activeChannelId = first.id
            configService.saveActiveChannelId(first.id)
        }

        let shortcuts = configService.loadShortcuts()
        recordShortcut = shortcuts.record
        textInputShortcut = shortcuts.textInput

        registerHotkeys()

        Task {
            await connectToActiveChannel()
        }

        Task {
            await checkForUpdates(manual: false)
        }
    }

    // MARK: - Update check

    func checkForUpdates(manual: Bool) async {
        if !manual {
            guard updateService.shouldAutoCheck() else { return }
        }

        let result = await updateService.checkForUpdate()
        updateService.recordCheckTime()

        switch result {
        case .upToDate:
            if manual {
                updateCheckMessage = "已是最新版本 ✓"
                try? await Task.sleep(for: .seconds(3))
                updateCheckMessage = nil
            }
        case .updateAvailable(let version, let url, let notes):
            if !manual && updateService.isVersionSkipped(version) { return }
            updateAvailable = (version: version, url: url, notes: notes)
        case .error(let msg):
            if manual {
                updateCheckMessage = "检查失败: \(msg)"
                try? await Task.sleep(for: .seconds(3))
                updateCheckMessage = nil
            }
        }
    }

    // MARK: - Channel management

    func addChannel(_ channel: Channel) {
        channels.append(channel)
        configService.saveChannels(channels)
        if channels.count == 1 {
            switchChannel(to: channel.id)
        }
    }

    func removeChannel(id: UUID) {
        channels.removeAll { $0.id == id }
        configService.saveChannels(channels)
        if activeChannelId == id {
            activeChannelId = channels.first?.id
            configService.saveActiveChannelId(activeChannelId)
            Task { await connectToActiveChannel() }
        }
    }

    func updateChannel(_ channel: Channel) {
        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            channels[index] = channel
            configService.saveChannels(channels)
            if activeChannelId == channel.id {
                Task { await connectToActiveChannel() }
            }
        }
    }

    func switchChannel(to id: UUID) {
        openClawService.disconnect()
        isConnected = false
        activeChannelId = id
        configService.saveActiveChannelId(id)
        Task { await connectToActiveChannel() }
    }

    func connectToActiveChannel() async {
        guard let channel = activeChannel else {
            isConnected = false
            connectedChannelName = ""
            return
        }

        switch channel.type {
        case .web:
            do {
                try await openClawService.connect(channel: channel)
                isConnected = true
                connectedChannelName = channel.name
            } catch {
                isConnected = false
                connectedChannelName = ""
                print("OpenClaw connection failed: \(error)")
            }
        case .telegram:
            isConnected = true
            connectedChannelName = channel.name
        }
    }

    // MARK: - Shared send logic

    func sendText(_ text: String, onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let channel = activeChannel else {
            onError("No channel selected")
            return
        }

        Task {
            do {
                switch channel.type {
                case .web:
                    if !isConnected {
                        await connectToActiveChannel()
                    }
                    try await openClawService.sendMessage(text: text)
                case .telegram:
                    try await telegramService.sendMessage(text: text, channel: channel)
                }
                onComplete()
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    // MARK: - Recording flow

    func togglePanel() {
        if isPanelVisible {
            cancel()
        } else {
            showPanelAndRecord()
        }
    }

    func showPanelAndRecord() {
        isPanelVisible = true
        panelController.show(
            content: RecordingPanelView(appState: self),
            size: NSSize(width: 600, height: 60),
            borderless: true
        )
        startRecording()
    }

    func startRecording() {
        recordingState = .recording
        liveTranscription = ""
        transcribedText = ""
        audioLevel = 0

        speechService.onAudioLevel = { [weak self] level in
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        speechService.locale = selectedLocaleId.isEmpty ? nil : Locale(identifier: selectedLocaleId)

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

    func stopAndSend() {
        guard recordingState == .recording else { return }
        speechService.stopRecognition()
        audioLevel = 0
        if transcribedText.isEmpty {
            transcribedText = liveTranscription
        }
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            cancel()
        } else {
            recordingState = .reviewing
            send()
        }
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
        recordingState = .sending
        sendText(transcribedText,
            onComplete: { [weak self] in
                Task { @MainActor in
                    self?.recordingState = .sent
                    try? await Task.sleep(for: .seconds(1))
                    self?.hidePanel()
                }
            },
            onError: { [weak self] msg in
                Task { @MainActor in
                    self?.recordingState = .error(msg)
                }
            }
        )
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

    // MARK: - Text input flow

    func toggleTextInputPanel() {
        if isTextPanelVisible {
            cancelTextInput()
        } else {
            showTextInputPanel()
        }
    }

    func showTextInputPanel() {
        textInputContent = ""
        textInputState = .editing
        isTextPanelVisible = true
        textPanelController.show(
            content: TextInputPanelView(appState: self),
            size: NSSize(width: 600, height: 60),
            borderless: true
        )
    }

    func sendTextInput() {
        textInputState = .sending
        sendText(textInputContent,
            onComplete: { [weak self] in
                Task { @MainActor in
                    self?.textInputState = .sent
                    try? await Task.sleep(for: .seconds(0.5))
                    self?.hideTextPanel()
                }
            },
            onError: { [weak self] msg in
                Task { @MainActor in
                    self?.textInputState = .error(msg)
                }
            }
        )
    }

    func cancelTextInput() {
        hideTextPanel()
    }

    func hideTextPanel() {
        textPanelController.hide()
        isTextPanelVisible = false
        textInputState = .idle
        textInputContent = ""
    }

    func reconnect() {
        Task {
            await connectToActiveChannel()
        }
    }

    // MARK: - Hotkey registration

    func registerHotkeys() {
        hotkeyService.unregisterAll()
        hotkeyService.register(hotkeys: [
            HotkeyService.HotkeyConfig(
                id: 1,
                keyCode: recordShortcut.keyCode,
                modifiers: recordShortcut.modifiers,
                onKeyDown: { [weak self] in
                    Task { @MainActor in self?.showPanelAndRecord() }
                },
                onKeyUp: { [weak self] in
                    Task { @MainActor in self?.stopAndSend() }
                }
            ),
            HotkeyService.HotkeyConfig(
                id: 2,
                keyCode: textInputShortcut.keyCode,
                modifiers: textInputShortcut.modifiers,
                onKeyDown: { [weak self] in
                    Task { @MainActor in self?.toggleTextInputPanel() }
                },
                onKeyUp: nil
            ),
        ])
    }

    func updateShortcuts(record: ShortcutConfig, textInput: ShortcutConfig) {
        recordShortcut = record
        textInputShortcut = textInput
        configService.saveShortcuts(record: record, textInput: textInput)
        registerHotkeys()
    }
}
