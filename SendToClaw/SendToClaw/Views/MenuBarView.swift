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

            Divider()

            // Microphone selection
            Text("Microphone: \(currentDeviceName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

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

            Divider()

            HStack {
                Circle()
                    .fill(appState.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(appState.isConnected ? "Connected to OpenClaw" : "Disconnected")
            }
            .padding(.horizontal, 8)

            if !appState.isConnected {
                Button("Reconnect") {
                    appState.reconnect()
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

    private func refreshDevices() {
        inputDevices = SpeechRecognitionService.availableInputDevices()
        currentDeviceName = SpeechRecognitionService.currentInputDeviceName()
    }
}
