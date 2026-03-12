import SwiftUI
import CoreAudio

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @State private var inputDevices: [(id: AudioDeviceID, name: String)] = []
    @State private var currentDeviceName: String = ""

    var body: some View {
        VStack {
            Button {
                appState.togglePanel()
            } label: {
                Label("Record & Send (\(appState.recordShortcut.symbolString))", systemImage: "waveform")
            }

            Button {
                appState.toggleTextInputPanel()
            } label: {
                Label("Text Input (\(appState.textInputShortcut.symbolString))", systemImage: "text.cursor")
            }

            Button {
                appState.shortcutSettingsController.show(appState: appState)
            } label: {
                Label("Customize Shortcuts...", systemImage: "keyboard")
            }

            Divider()

            // Channel selection
            channelSection

            Divider()

            // Language selection
            Menu {
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
            } label: {
                Label("Language: \(selectedLanguageName)", systemImage: "globe")
            }

            // Microphone selection
            Menu {
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
            } label: {
                Label("Mic: \(currentDeviceName)", systemImage: "mic")
            }

            Divider()

            if let update = appState.updateAvailable {
                Button {
                    NSWorkspace.shared.open(update.url)
                } label: {
                    Label("New Version: v\(update.version)", systemImage: "sparkles")
                }
                Button {
                    appState.updateService.skipVersion(update.version)
                    appState.updateAvailable = nil
                } label: {
                    Label("Skip This Version", systemImage: "xmark.circle")
                }
            }

            if let msg = appState.updateCheckMessage {
                Text(msg)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await appState.checkForUpdates(manual: true) }
            } label: {
                Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
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
                Button {
                    appState.switchChannel(to: channel.id)
                } label: {
                    Label("Connect", systemImage: "link")
                }
                Button {
                    appState.channelEditController.show(appState: appState, editingChannel: channel)
                } label: {
                    Label("Edit...", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    appState.removeChannel(id: channel.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                HStack {
                    if channel.id == appState.activeChannelId {
                        Image(systemName: appState.isConnected ? "checkmark" : "circle")
                    } else {
                        Image(systemName: "")
                    }
                    
                    Text(channel.name)
                    
                }
            }
        }

        Menu {
            Button {
                appState.channelEditController.show(appState: appState, channelType: .web)
            } label: {
                Label("Web Server...", systemImage: "globe")
            }
            Button {
                appState.channelEditController.show(appState: appState, channelType: .telegram)
            } label: {
                Label("Telegram...", systemImage: "paperplane")
            }
        } label: {
            Label("Add Channel", systemImage: "plus")
        }

        if !appState.isConnected {
            Button {
                appState.reconnect()
            } label: {
                Label("Reconnect", systemImage: "arrow.clockwise")
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
