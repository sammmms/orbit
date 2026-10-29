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

        // Comprehensive event mask: keys, modifiers, mouse moves, and clicks
        let eventsOfInterest: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue)

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
            print("[Orbit EventTap] Warning: Failed to create CGEventTap. Ensure Accessibility permissions are granted.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[Orbit EventTap] Event tap active and listening.")
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
        let location = event.location
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let shouldConsume: Bool = MainActor.assumeIsolated {
            let config = ConfigManager.shared.config
            let controller = RadialMenuController.shared

            // MARK: - A. When Radial Menu IS OPEN
            // Intercept and absorb inputs so background apps never receive clicks or steal focus!
            if controller.isOpen {
                // 1. Mouse movements & drags
                if type == .mouseMoved || type == .leftMouseDragged || type == .otherMouseDragged {
                    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080.0
                    let cocoaLocation = NSPoint(x: location.x, y: screenHeight - location.y)
                    controller.updateMousePosition(cocoaLocation)
                    // In hold mode or open mode, track smoothly
                }

                // 2. Left Mouse Down: Update selection & CONSUME click so background window is not clicked!
                if type == .leftMouseDown {
                    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080.0
                    let cocoaLocation = NSPoint(x: location.x, y: screenHeight - location.y)
                    controller.updateMousePosition(cocoaLocation)
                    return true // Swallowed!
                }

                // 3. Left Mouse Up: Commit selected slice & CONSUME!
                if type == .leftMouseUp {
                    controller.commitSelection()
                    return true // Swallowed!
                }

                // 4. Right Mouse Down: Dismiss menu & CONSUME!
                if type == .rightMouseDown {
                    controller.close()
                    return true // Swallowed!
                }

                // 5. Escape or Space while open
                if type == .keyDown {
                    if keyCode == 53 { // Escape
                        controller.close()
                        return true
                    }
                    if keyCode == 49 { // Space
                        // If Option+Space pressed again, close
                        controller.close()
                        return true
                    }
                    if keyCode == 36 { // Enter
                        controller.commitSelection()
                        return true
                    }
                }
            }

            // MARK: - B. Middle Click Trigger (Hold & Flick)
            if config.trigger.enableMiddleClick {
                if buttonNumber == 2 { // Middle button
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
            }

            // MARK: - C. Hotkey: Option + Space
            if type == .keyDown {
                if keyCode == 49 { // Space
                    let isOption = flags.contains(.maskAlternate)
                    let isCmd = flags.contains(.maskCommand)
                    let isCtrl = flags.contains(.maskControl)

                    // Trigger on Option+Space (and no Command/Ctrl)
                    if isOption && !isCmd && !isCtrl {
                        controller.toggle()
                        return true // Consume hotkey
                    }
                } else {
                    otherKeyPressedDuringHold = true
                    optionHoldTimer?.invalidate()
                    optionHoldTimer = nil
                }
            }

            // MARK: - D. Modifier Hold (Option Key)
            if type == .flagsChanged {
                let optionPressed = flags.contains(.maskAlternate)
                let holdSetting = config.trigger.holdModifier.lowercased()

                if holdSetting == "option" {
                    if optionPressed && !isOptionHeld {
                        // Option was just pressed down
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
                        // Option was released
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
