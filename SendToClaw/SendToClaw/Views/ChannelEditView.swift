import SwiftUI

struct ChannelEditView: View {
    var appState: AppState
    var channelType: ChannelType
    var editingChannel: Channel?
    var onDismiss: () -> Void

    @State private var name: String = ""
    // Web fields
    @State private var host: String = ""
    @State private var port: String = "18789"
    @State private var token: String = ""
    // Telegram fields
    @State private var botUsername: String = ""

    @State private var errorMessage: String?

    var isEditing: Bool { editingChannel != nil }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Channel" : "Add Channel")
                .font(.headline)

            Form {
                TextField("Name", text: $name, prompt: Text(namePlaceholder))

                switch channelType {
                case .web:
                    TextField("Host", text: $host, prompt: Text("e.g. 192.168.1.100 or claw.example.com"))
                    TextField("Port", text: $port, prompt: Text("18789"))
                    SecureField("Token", text: $token, prompt: Text("Gateway auth token"))
                case .telegram:
                    TextField("Bot Username", text: $botUsername, prompt: Text("e.g. my_openclaw_bot (without @)"))
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!isValid)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            if let channel = editingChannel {
                name = channel.name
                switch channel.type {
                case .web:
                    host = channel.host ?? ""
                    port = String(channel.port ?? 18789)
                    token = channel.token ?? ""
                case .telegram:
                    botUsername = channel.botUsername ?? ""
                }
            }
        }
    }

    private var namePlaceholder: String {
        switch channelType {
        case .web: return "e.g. Home / Office / Cloud"
        case .telegram: return "e.g. My Telegram"
        }
    }

    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        switch channelType {
        case .web:
            return !host.isEmpty && !token.isEmpty
        case .telegram:
            return !botUsername.isEmpty
        }
    }

    private func save() {
        switch channelType {
        case .web:
            guard let portInt = Int(port), portInt > 0, portInt <= 65535 else {
                errorMessage = "Invalid port number"
                return
            }
            if isEditing, let existing = editingChannel {
                var updated = existing
                updated.name = name
                updated.host = host
                updated.port = portInt
                updated.token = token
                appState.updateChannel(updated)
            } else {
                let channel = Channel(
                    id: UUID(), type: .web, name: name,
                    host: host, port: portInt, token: token
                )
                appState.addChannel(channel)
            }

        case .telegram:
            if isEditing, let existing = editingChannel {
                var updated = existing
                updated.name = name
                updated.botUsername = botUsername
                appState.updateChannel(updated)
            } else {
                let channel = Channel(
                    id: UUID(), type: .telegram, name: name,
                    botUsername: botUsername
                )
                appState.addChannel(channel)
            }
        }

        onDismiss()
    }
}

/// Controller to show ChannelEditView in a standalone window
@MainActor
class ChannelEditWindowController {
    private var window: NSWindow?

    func show(appState: AppState, editingChannel: Channel? = nil, channelType: ChannelType? = nil) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let type = editingChannel?.type ?? channelType ?? .web

        let view = ChannelEditView(
            appState: appState,
            channelType: type,
            editingChannel: editingChannel,
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = editingChannel != nil ? "Edit Channel" : "Add Channel"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func close() {
        window?.close()
        window = nil
    }
}

#if DEBUG

#Preview("Add Web Channel") {
    ChannelEditView(
        appState: AppState(),
        channelType: .web,
        editingChannel: nil,
        onDismiss: {}
    )
}

#Preview("Add Telegram Channel") {
    ChannelEditView(
        appState: AppState(),
        channelType: .telegram,
        editingChannel: nil,
        onDismiss: {}
    )
}

#Preview("Edit Web Channel") {
    let editing = Channel(
        id: UUID(),
        type: .web,
        name: "Office",
        host: "claw.example.com",
        port: 18789,
        token: "abc123"
    )
    return ChannelEditView(
        appState: AppState(),
        channelType: .web,
        editingChannel: editing,
        onDismiss: {}
    )
}

#Preview("Edit Telegram Channel") {
    let editing = Channel(
        id: UUID(),
        type: .telegram,
        name: "My Telegram",
        botUsername: "my_openclaw_bot"
    )
    return ChannelEditView(
        appState: AppState(),
        channelType: .telegram,
        editingChannel: editing,
        onDismiss: {}
    )
}

#endif

