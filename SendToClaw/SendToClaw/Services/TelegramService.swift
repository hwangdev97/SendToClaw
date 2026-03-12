import AppKit
import Foundation

class TelegramService {
    /// Check if we have Accessibility permission (needed for System Events keystroke)
    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompt user to grant Accessibility permission
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func sendMessage(text: String, channel: Channel) async throws {
        guard let botUsername = channel.botUsername, !botUsername.isEmpty else {
            throw TelegramError.missingConfig
        }

        // Check accessibility permission before doing anything
        guard Self.hasAccessibilityPermission() else {
            Self.requestAccessibilityPermission()
            throw TelegramError.noAccessibility
        }

        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)

        // Open the bot chat in Telegram
        let urlString = "tg://resolve?domain=\(botUsername)"
        guard let url = URL(string: urlString) else {
            throw TelegramError.invalidURL
        }

        NSWorkspace.shared.open(url)
        try await Task.sleep(for: .seconds(1.5))

        // Set clipboard to message text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Run AppleScript on a background thread to avoid blocking
        let scriptResult: (success: Bool, errorMsg: String?) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = """
                tell application "System Events"
                    keystroke "v" using command down
                    delay 0.3
                    keystroke return
                end tell
                """
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? error.description
                    continuation.resume(returning: (false, msg))
                } else {
                    continuation.resume(returning: (true, nil))
                }
            }
        }

        // Restore clipboard
        try await Task.sleep(for: .seconds(0.5))
        pasteboard.clearContents()
        if let old = oldContents {
            pasteboard.setString(old, forType: .string)
        }

        if !scriptResult.success {
            throw TelegramError.scriptFailed(scriptResult.errorMsg ?? "Unknown error")
        }

        print("[Telegram] Message sent via AppleScript")
    }
}

enum TelegramError: LocalizedError {
    case missingConfig
    case invalidURL
    case noAccessibility
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig: return "Telegram bot username not configured"
        case .invalidURL: return "Invalid Telegram URL"
        case .noAccessibility: return "Please grant Accessibility permission in System Settings → Privacy & Security → Accessibility, then retry."
        case .scriptFailed(let msg): return "AppleScript failed: \(msg)"
        }
    }
}
