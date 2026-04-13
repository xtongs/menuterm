import AppKit
import Carbon

final class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
        registerHotkey()
    }

    deinit {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    private func registerHotkey() {
        // Ctrl + ` (grave accent, keyCode 50)
        let hotkeyID = EventHotKeyID(signature: OSType(0x4D544D54), // "MTMT"
                                      id: 1)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { mgr.callback() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(controlKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }
}
