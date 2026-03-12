import SwiftUI

struct TextInputPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Status bar
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(appState.connectedChannelName.isEmpty ? "Disconnected" : appState.connectedChannelName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Text input area
            TextInputEditor(text: $appState.textInputContent, onSubmit: {
                appState.sendTextInput()
            })
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.background.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(height: 100)

            // Hint + buttons
            HStack {
                Text("Return to send, Shift+Return for newline")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("Cancel") {
                    appState.cancelTextInput()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var statusColor: Color {
        switch appState.textInputState {
        case .editing: return .blue
        case .sending: return .orange
        case .sent: return .green
        case .error: return .red
        case .idle: return .gray
        }
    }

    private var statusText: String {
        switch appState.textInputState {
        case .editing: return "Type your message"
        case .sending: return "Sending..."
        case .sent: return "Sent!"
        case .error(let msg): return "Error: \(msg)"
        case .idle: return "Ready"
        }
    }
}

/// A TextEditor that intercepts Return to submit, Shift+Return for newline
struct TextInputEditor: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor

        // Focus the text view
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Return pressed without Shift → submit
                if NSEvent.modifierFlags.contains(.shift) {
                    // Shift+Return → insert newline
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                let trimmed = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSubmit()
                }
                return true
            }
            return false
        }
    }
}
