# SendToClaw

A macOS menu bar app for quickly sending voice or text messages to [OpenClaw](https://github.com/nicepkg/openclaw) — with optional Telegram forwarding via AppleScript automation.

## Features

- **Voice Input** — Hold `Cmd+Shift+C` to record, release to auto-send. Uses Apple Speech Recognition for real-time transcription.
- **Text Input** — Press `Cmd+Shift+T` to open a text input panel. Press `Return` to send, `Shift+Return` for newline.
- **Multi-Channel** — Send to OpenClaw (WebSocket) or Telegram (AppleScript) interchangeably. Add multiple channels and switch between them.
- **Menu Bar App** — Lives in the menu bar, no dock icon. Quick access to channel management, language, and microphone settings.

## Channels

| Type | How it works |
|------|-------------|
| **Web** | Connects to OpenClaw gateway via WebSocket. Requires host, port, and auth token. Auto-imports from `~/.openclaw/openclaw.json` on first launch. |
| **Telegram** | Opens Telegram Desktop via `tg://` URL scheme and sends messages using AppleScript UI automation. Requires the bot's username and Accessibility permission. |

## Requirements

- macOS 15.0+
- Xcode 16+
- For voice input: Microphone and Speech Recognition permissions
- For Telegram channel: Telegram Desktop installed + Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Build & Run

```bash
cd SendToClaw
xcodebuild -scheme SendToClaw -configuration Debug build
```

Or open `SendToClaw/SendToClaw.xcodeproj` in Xcode and run.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+C` | Hold to record voice, release to send |
| `Cmd+Shift+T` | Toggle text input panel |
| `Return` | Send text (in text input panel) |
| `Esc` | Cancel / close panel |

## Configuration

On first launch, SendToClaw tries to import the local OpenClaw config from `~/.openclaw/openclaw.json`. You can also add channels manually from the menu bar.

## License

MIT
