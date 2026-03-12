import SwiftUI

struct TextInputPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Main input row
            HStack(spacing: 12) {
                // Status indicator
                Image("Background")
                    .resizable()
                    .frame(width: 36,height: 36 )

                // Text input
                TextInputEditor(text: $appState.textInputContent, onSubmit: {
                    appState.sendTextInput()
                }, onCancel: {
                    appState.cancelTextInput()
                })

                // Channel picker
                Menu {
                    ForEach(appState.channels) { channel in
                        Button {
                            appState.switchChannel(to: channel.id)
                        } label: {
                            HStack {
                                if channel.id == appState.activeChannelId {
                                    Image(systemName: "checkmark")
                                }
                                Text(channel.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isConnected ? .green : .red)
                            .frame(width: 6, height: 6)
                        Text(appState.connectedChannelName.isEmpty ? "No Channel" : appState.connectedChannelName)
                            .font(.body)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Bottom hint bar
            if appState.textInputState == .error("") || statusHint != nil {
                Divider().opacity(0.3)
                HStack {
                    if let hint = statusHint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(appState.textInputState.isError ? Color.red : Color.secondary)
                    }
                    Spacer()
                    Text("⏎ Send  ⇧⏎ Newline  ⎋ Cancel")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 600)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 48))
        
    }

    private var statusIcon: String {
        switch appState.textInputState {
        case .editing: return "text.cursor"
        case .sending: return "arrow.up.circle.fill"
        case .sent: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .idle: return "text.cursor"
        }
    }

    private var statusColor: Color {
        switch appState.textInputState {
        case .editing: return .secondary
        case .sending: return .orange
        case .sent: return .green
        case .error: return .red
        case .idle: return .secondary
        }
    }

    private var statusHint: String? {
        switch appState.textInputState {
        case .sending: return "Sending..."
        case .sent: return "Sent!"
        case .error(let msg): return msg
        default: return nil
        }
    }
}

private extension TextInputState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

/// Single-line text field that submits on Return and cancels on Escape
struct TextInputEditor: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 16)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .labelColor
        field.placeholderString = "Type a message..."
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true

        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onCancel = onCancel
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void
        var onCancel: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let trimmed = (control as? NSTextField)?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !trimmed.isEmpty {
                    onSubmit()
                }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onCancel()
                return true
            }
            return false
        }
    }
}
