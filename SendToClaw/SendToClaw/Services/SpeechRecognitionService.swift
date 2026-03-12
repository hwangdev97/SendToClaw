import Speech
import AVFoundation
import CoreAudio

class SpeechRecognitionService {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Selected locale for speech recognition. nil = system default (auto-detect).
    var locale: Locale?

    private var speechRecognizer: SFSpeechRecognizer? {
        if let locale = locale {
            return SFSpeechRecognizer(locale: locale)
        }
        return SFSpeechRecognizer()
    }

    /// List supported locales that have on-device or cloud recognition
    static func supportedLocales() -> [(id: String, name: String)] {
        let supported = SFSpeechRecognizer.supportedLocales()
        let displayNames: [(id: String, name: String)] = supported.map { locale in
            let name = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            return (id: locale.identifier, name: "\(name) (\(locale.identifier))")
        }.sorted { $0.name < $1.name }
        return displayNames
    }

    /// Common languages shown at the top of the menu
    static let commonLocales: [(id: String, name: String)] = [
        ("", "Auto (System Default)"),
        ("zh-CN", "中文（简体）"),
        ("zh-TW", "中文（繁體）"),
        ("en-US", "English (US)"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어"),
    ]

    /// Current audio level (0.0 to 1.0) for UI visualization
    var onAudioLevel: ((Float) -> Void)?

    private var bufferCount = 0

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// List available audio input devices
    static func availableInputDevices() -> [(id: AudioDeviceID, name: String)] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )

        var inputDevices: [(id: AudioDeviceID, name: String)] = []

        for deviceID in deviceIDs {
            // Check if device has input channels
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputSize) == noErr else {
                continue
            }

            let bufferListPtr = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferListPtr.deallocate() }
            guard AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &inputSize, bufferListPtr) == noErr else {
                continue
            }

            let channelCount = (0..<Int(bufferListPtr.pointee.mNumberBuffers)).reduce(0) { sum, i in
                let buffers = UnsafeMutableAudioBufferListPointer(bufferListPtr)
                return sum + Int(buffers[i].mNumberChannels)
            }

            guard channelCount > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)

            inputDevices.append((id: deviceID, name: name as String))
        }

        return inputDevices
    }

    /// Set the default input device for the audio engine
    static func setInputDevice(id: AudioDeviceID) {
        var deviceID = id
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )
    }

    /// Get current default input device name
    static func currentInputDeviceName() -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &size,
            &deviceID
        )

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "Unknown" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)
        return name as String
    }

    func startRecognition(
        onPartialResult: @escaping @Sendable (String) -> Void,
        onFinalResult: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) {
        bufferCount = 0

        Task {
            let authorized = await requestAuthorization()
            guard authorized else {
                onError("Speech recognition not authorized. Please enable in System Settings > Privacy & Security.")
                return
            }

            guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
                onError("Speech recognizer is not available for locale: \(self.speechRecognizer?.locale.identifier ?? "unknown")")
                return
            }

            let currentDevice = SpeechRecognitionService.currentInputDeviceName()
            print("[SpeechService] Using recognizer locale: \(speechRecognizer.locale.identifier)")
            print("[SpeechService] Supports on-device: \(speechRecognizer.supportsOnDeviceRecognition)")
            print("[SpeechService] Current input device: \(currentDevice)")

            do {
                try startAudioAndRecognition(
                    speechRecognizer: speechRecognizer,
                    onPartialResult: onPartialResult,
                    onFinalResult: onFinalResult,
                    onError: onError
                )
            } catch {
                onError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    private func startAudioAndRecognition(
        speechRecognizer: SFSpeechRecognizer,
        onPartialResult: @escaping @Sendable (String) -> Void,
        onFinalResult: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) throws {
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        print("[SpeechService] Hardware audio format: \(hardwareFormat)")
        print("[SpeechService] Sample rate: \(hardwareFormat.sampleRate), channels: \(hardwareFormat.channelCount)")

        guard hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 else {
            onError("Invalid audio format — no input device available. Check System Settings > Sound > Input.")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visualization
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frames {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(max(frames, 1)))
            let level = min(rms * 3.0, 1.0)

            // Log first few buffers to diagnose audio issues
            if let self = self {
                self.bufferCount += 1
                if self.bufferCount <= 5 {
                    let peak = (0..<frames).reduce(Float(0)) { max($0, abs(channelData[$1])) }
                    print("[SpeechService] Buffer #\(self.bufferCount): frames=\(frames) rms=\(String(format: "%.6f", rms)) peak=\(String(format: "%.6f", peak)) level=\(String(format: "%.3f", level))")
                }
            }

            self?.onAudioLevel?(level)
        }

        engine.prepare()
        try engine.start()
        print("[SpeechService] Audio engine started successfully")

        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                print("[SpeechService] Result (isFinal=\(result.isFinal)): \(text)")
                if result.isFinal {
                    onFinalResult(text)
                } else {
                    onPartialResult(text)
                }
            }

            if let error = error {
                let nsError = error as NSError
                print("[SpeechService] Error: domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription)")
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 301 {
                    return
                }
                onError(error.localizedDescription)
            }
        }
    }

    func stopRecognition() {
        if let engine = audioEngine, engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        onAudioLevel = nil
    }
}
