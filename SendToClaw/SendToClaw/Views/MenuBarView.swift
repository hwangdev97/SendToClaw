import SwiftUI
import CoreAudio

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @State private var inputDevices: [(id: AudioDeviceID, name: String)] = []
    @State private var currentDeviceName: String = ""

    var body: some View {
        VStack {
            Button("Record & Send (Cmd+Shift+C)") {
                appState.togglePanel()
            }

            Button("Text Input (Cmd+Shift+T)") {
                appState.toggleTextInputPanel()
            }

            Divider()

            // Channel selection
            channelSection

            Divider()

            // Language selection
            Menu("Language: \(selectedLanguageName)") {
                ForEach(SpeechRecognitionService.commonLocales, id: \.id) { locale in
                    Button {
                        appState.selectedLocaleId = locale.id
                    } label: {
                        HStack {
                            if appState.selectedLocaleId == locale.id {
                                Image(systemName: "checkmark")
                            }
                            Text(locale.name)
                        }
                    }
                }
            }

            // Microphone selection
            Menu("Mic: \(currentDeviceName)") {
                ForEach(inputDevices, id: \.id) { device in
                    Button {
                        SpeechRecognitionService.setInputDevice(id: device.id)
                        refreshDevices()
                    } label: {
                        HStack {
                            if device.name == currentDeviceName {
                                Image(systemName: "checkmark")
                            }
                            Text(device.name)
                        }
                    }
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 4)
        .onAppear {
            refreshDevices()
        }
    }

    @ViewBuilder
    private var channelSection: some View {
        // Connection status
        HStack {
            Circle()
                .fill(appState.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            if appState.isConnected {
                Text("Connected: \(appState.connectedChannelName)")
            } else {
                Text("Disconnected")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)

        // Channel list
        ForEach(appState.channels) { channel in
            Menu {
                Button("Connect") {
                    appState.switchChannel(to: channel.id)
                }
                Button("Edit...") {
                    appState.channelEditController.show(appState: appState, editingChannel: channel)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    appState.removeChannel(id: channel.id)
                }
            } label: {
                HStack {
                    if channel.id == appState.activeChannelId {
                        Image(systemName: appState.isConnected ? "checkmark.circle.fill" : "checkmark.circle")
                    } else {
                        Image(systemName: "circle")
                    }
                    Image(systemName: channel.type == .web ? "globe" : "paperplane")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.name)
                        Text(channelSubtitle(channel))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        Menu("Add Channel") {
            Button("Web Server...") {
                appState.channelEditController.show(appState: appState, channelType: .web)
            }
            Button("Telegram...") {
                appState.channelEditController.show(appState: appState, channelType: .telegram)
            }
        }

        if !appState.isConnected {
            Button("Reconnect") {
                appState.reconnect()
            }
        }
    }

    private func channelSubtitle(_ channel: Channel) -> String {
        switch channel.type {
        case .web:
            return "\(channel.host ?? ""):\(channel.port ?? 0)"
        case .telegram:
            return "Telegram Bot"
        }
    }

    private var selectedLanguageName: String {
        SpeechRecognitionService.commonLocales.first { $0.id == appState.selectedLocaleId }?.name ?? appState.selectedLocaleId
    }

    private func refreshDevices() {
        inputDevices = SpeechRecognitionService.availableInputDevices()
        currentDeviceName = SpeechRecognitionService.currentInputDeviceName()
    }
}
