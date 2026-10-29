import Foundation
import Carbon
import AppKit

public final class CarbonHotKeyManager: @unchecked Sendable {
    public static let shared = CarbonHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    public func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install Carbon Event Handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (handlerCallRef, eventRef, userData) -> OSStatus in
                DispatchQueue.main.async {
                    print("[Orbit CarbonHotKey] Hotkey triggered! Toggling Radial Menu...")
                    RadialMenuController.shared.toggle()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status != noErr {
            print("[Orbit CarbonHotKey] Failed to install event handler: \(status)")
            return
        }

        // Register Option + Space globally
        // kVK_Space = 49, optionKey = 0x0800
        let hotKeyID = EventHotKeyID(signature: OSType(0x4f524254), id: 1) // 'ORBT'
        let regStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus == noErr {
            print("[Orbit CarbonHotKey] Successfully registered ⌥ + Space globally (Carbon WindowServer level).")
        } else {
            print("[Orbit CarbonHotKey] Error registering ⌥ + Space: \(regStatus)")
        }
    }

    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
