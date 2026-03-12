import AppKit
import SwiftUI

/// NSPanel subclass that can always become key window (needed for borderless panels to receive keyboard input)
private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
class FloatingPanelController {
    private var panel: NSPanel?

    func show<Content: View>(
        content: Content,
        size: NSSize = NSSize(width: 420, height: 320),
        borderless: Bool = false
    ) {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let styleMask: NSWindow.StyleMask = borderless
            ? [.borderless]
            : [.titled, .closable, .nonactivatingPanel, .hudWindow]

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView

        if borderless {
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            // Position near top of screen (like Raycast)
            if let screen = NSScreen.main {
                let x = (screen.frame.width - size.width) / 2
                let y = screen.frame.height * 0.7
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        } else {
            panel.title = "SendToClaw"
            panel.titlebarAppearsTransparent = true
            panel.contentMinSize = size
            panel.contentMaxSize = size
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    func hide() {
        panel?.close()
        panel = nil
    }
}
