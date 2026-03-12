import SwiftUI
import Carbon

struct ShortcutSettingsView: View {
    var appState: AppState
    var onDismiss: () -> Void

    @State private var recordShortcut: ShortcutConfig
    @State private var textInputShortcut: ShortcutConfig
    @State private var activeRecorder: RecorderID?

    enum RecorderID {
        case record
        case textInput
    }

    init(appState: AppState, onDismiss: @escaping () -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss
        _recordShortcut = State(initialValue: appState.recordShortcut)
        _textInputShortcut = State(initialValue: appState.textInputShortcut)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Customize Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Record & Send:")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    ShortcutRecorderButton(
                        shortcut: $recordShortcut,
                        isActive: activeRecorder == .record,
                        onActivate: { activeRecorder = .record },
                        onDeactivate: { activeRecorder = nil }
                    )
                    .frame(width: 140)
                }
                GridRow {
                    Text("Text Input:")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    ShortcutRecorderButton(
                        shortcut: $textInputShortcut,
                        isActive: activeRecorder == .textInput,
                        onActivate: { activeRecorder = .textInput },
                        onDeactivate: { activeRecorder = nil }
                    )
                    .frame(width: 140)
                }
            }

            HStack {
                Button("Reset to Defaults") {
                    recordShortcut = .defaultRecord
                    textInputShortcut = .defaultTextInput
                    activeRecorder = nil
                }

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    appState.updateShortcuts(record: recordShortcut, textInput: textInputShortcut)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

// MARK: - Shortcut Recorder Button

struct ShortcutRecorderButton: View {
    @Binding var shortcut: ShortcutConfig
    var isActive: Bool
    var onActivate: () -> Void
    var onDeactivate: () -> Void

    var body: some View {
        ShortcutRecorderRepresentable(
            shortcut: $shortcut,
            isActive: isActive,
            onActivate: onActivate,
            onDeactivate: onDeactivate
        )
        .frame(height: 24)
    }
}

// MARK: - NSViewRepresentable wrapper for key event capture

struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var shortcut: ShortcutConfig
    var isActive: Bool
    var onActivate: () -> Void
    var onDeactivate: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onShortcutCaptured = { keyCode, modifiers in
            shortcut = ShortcutConfig(keyCode: keyCode, modifiers: modifiers)
            onDeactivate()
        }
        view.onCancel = { onDeactivate() }
        view.onActivate = { onActivate() }
        view.updateDisplay(shortcut: shortcut, isActive: isActive)
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.onShortcutCaptured = { keyCode, modifiers in
            shortcut = ShortcutConfig(keyCode: keyCode, modifiers: modifiers)
            onDeactivate()
        }
        nsView.onCancel = { onDeactivate() }
        nsView.onActivate = { onActivate() }
        nsView.updateDisplay(shortcut: shortcut, isActive: isActive)
        if isActive && nsView.window != nil {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

// MARK: - NSView that captures keyboard events

class ShortcutRecorderNSView: NSView {
    var onShortcutCaptured: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?
    var onActivate: (() -> Void)?

    private var isActive = false
    private let textField = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.alignment = .center
        textField.font = .systemFont(ofSize: 13)
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func updateDisplay(shortcut: ShortcutConfig, isActive: Bool) {
        self.isActive = isActive
        if isActive {
            textField.stringValue = "Type shortcut…"
            textField.textColor = .secondaryLabelColor
        } else {
            textField.stringValue = shortcut.symbolString
            textField.textColor = .labelColor
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if !isActive {
            onActivate?()
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isActive else {
            super.keyDown(with: event)
            return
        }

        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        let modifiers = ShortcutConfig.carbonModifiers(from: event.modifierFlags)

        // Require at least one modifier (Cmd, Ctrl, or Option)
        let hasRequiredModifier = (modifiers & UInt32(cmdKey) != 0)
            || (modifiers & UInt32(controlKey) != 0)
            || (modifiers & UInt32(optionKey) != 0)

        guard hasRequiredModifier else { return }

        onShortcutCaptured?(UInt32(event.keyCode), modifiers)
    }

    override func flagsChanged(with event: NSEvent) {
        // Don't handle modifier-only presses as shortcuts
        super.flagsChanged(with: event)
    }
}

// MARK: - Window Controller

@MainActor
class ShortcutSettingsWindowController {
    private var window: NSWindow?

    func show(appState: AppState) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ShortcutSettingsView(
            appState: appState,
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Customize Shortcuts"
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
