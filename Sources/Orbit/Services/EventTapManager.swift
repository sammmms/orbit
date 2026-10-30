import Foundation
@preconcurrency import CoreGraphics
import AppKit

public final class EventTapManager: @unchecked Sendable {
    public static let shared = EventTapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var optionHoldTimer: Timer?
    private var optionKeyDownTime: Date?
    private var isOptionHeld: Bool = false
    private var otherKeyPressedDuringHold: Bool = false

    private init() {}

    public func start() {
        guard eventTap == nil else { return }

        // Mask for modifiers and middle mouse button
        let eventsOfInterest: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        )

        guard let tap = tap else {
            print("[Orbit EventTap] Warning: CGEventTap creation failed. Grant Accessibility in System Settings if using Middle Click.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[Orbit EventTap] Middle-click and Option-hold listeners active.")
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let flags = event.flags

        let shouldConsume: Bool = MainActor.assumeIsolated {
            let config = ConfigManager.shared.config
            let controller = RadialMenuController.shared

            // MARK: - 1. Middle Mouse Button (Button 2) Hold & Flick
            if config.trigger.enableMiddleClick && buttonNumber == 2 {
                if type == .otherMouseDown {
                    controller.open(holdMode: true)
                    return true // Consume event
                } else if type == .otherMouseUp {
                    if controller.isOpen && controller.isHoldMode {
                        controller.handleModifierOrKeyRelease()
                        return true // Consume event
                    }
                }
            }

            // MARK: - 2. Modifier Hold (Disabled when set to "None")
            let holdSetting = config.trigger.holdModifier.lowercased()
            guard holdSetting != "none" && !holdSetting.isEmpty else {
                return false
            }

            // Reset hold timer if another key is pressed
            if type == .keyDown {
                otherKeyPressedDuringHold = true
                optionHoldTimer?.invalidate()
                optionHoldTimer = nil
            }

            // Modifier Hold (Option Key)
            if type == .flagsChanged {
                let optionPressed = flags.contains(.maskAlternate)

                if holdSetting == "option" {
                    if optionPressed && !isOptionHeld {
                        isOptionHeld = true
                        otherKeyPressedDuringHold = false
                        optionKeyDownTime = Date()

                        let holdDelay = Double(config.trigger.holdDurationMs) / 1000.0
                        optionHoldTimer?.invalidate()
                        optionHoldTimer = Timer.scheduledTimer(withTimeInterval: holdDelay, repeats: false) { [weak self] _ in
                            guard let self = self else { return }
                            MainActor.assumeIsolated {
                                if self.isOptionHeld && !self.otherKeyPressedDuringHold {
                                    controller.open(holdMode: true)
                                }
                            }
                        }
                    } else if !optionPressed && isOptionHeld {
                        isOptionHeld = false
                        optionHoldTimer?.invalidate()
                        optionHoldTimer = nil

                        if controller.isOpen && controller.isHoldMode {
                            controller.handleModifierOrKeyRelease()
                        }
                    }
                }
            }

            return false
        }

        if shouldConsume {
            return nil
        } else {
            return Unmanaged.passUnretained(event)
        }
    }
}
