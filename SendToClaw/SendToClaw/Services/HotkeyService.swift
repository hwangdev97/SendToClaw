import Carbon
import AppKit

class HotkeyService {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    // Callbacks keyed by hotkey ID
    private var keyDownHandlers: [UInt32: () -> Void] = [:]
    private var keyUpHandlers: [UInt32: () -> Void] = [:]

    private static var sharedInstance: HotkeyService?

    struct HotkeyConfig {
        let id: UInt32
        let keyCode: UInt32
        let modifiers: UInt32
        let onKeyDown: () -> Void
        let onKeyUp: (() -> Void)?
    }

    func register(hotkeys: [HotkeyConfig]) {
        HotkeyService.sharedInstance = self

        for config in hotkeys {
            keyDownHandlers[config.id] = config.onKeyDown
            if let onKeyUp = config.onKeyUp {
                keyUpHandlers[config.id] = onKeyUp
            }
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let event = event else { return noErr }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let kind = Int(GetEventKind(event))
                if kind == kEventHotKeyPressed {
                    HotkeyService.sharedInstance?.keyDownHandlers[hotKeyID.id]?()
                } else if kind == kEventHotKeyReleased {
                    HotkeyService.sharedInstance?.keyUpHandlers[hotKeyID.id]?()
                }
                return noErr
            },
            2,
            &eventTypes,
            nil,
            &eventHandlerRef
        )

        let signature = OSType(0x5354_4343) // "STCC"
        for config in hotkeys {
            let hotKeyID = EventHotKeyID(signature: signature, id: config.id)
            var ref: EventHotKeyRef?
            RegisterEventHotKey(
                config.keyCode,
                config.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if let ref = ref {
                hotKeyRefs.append(ref)
            }
        }
    }

    // Convenience for backward compatibility
    func register(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        register(hotkeys: [
            HotkeyConfig(
                id: 1,
                keyCode: UInt32(kVK_ANSI_C),
                modifiers: UInt32(cmdKey | shiftKey),
                onKeyDown: onKeyDown,
                onKeyUp: onKeyUp
            )
        ])
    }

    func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        keyDownHandlers.removeAll()
        keyUpHandlers.removeAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    deinit {
        unregisterAll()
    }
}
