import Carbon
import AppKit

class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandlerRef: EventHandlerRef?

    private static var sharedInstance: HotkeyService?

    func register(handler: @escaping () -> Void) {
        self.handler = handler
        HotkeyService.sharedInstance = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                HotkeyService.sharedInstance?.handler?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // Cmd+Shift+C: keyCode 8 = 'C'
        let hotKeyID = EventHotKeyID(signature: OSType(0x5354_4343), id: 1) // "STCC"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
}
