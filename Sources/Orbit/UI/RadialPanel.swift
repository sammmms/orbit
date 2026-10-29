import AppKit
import SwiftUI

public final class RadialPanel: NSPanel {
    public var onMouseMove: ((CGPoint) -> Void)?
    public var onMouseUp: (() -> Void)?
    public var onEscape: (() -> Void)?

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .popUpMenu
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .mouseMoved:
            let loc = event.locationInWindow
            let converted = CGPoint(x: loc.x, y: frame.height - loc.y)
            onMouseMove?(converted)
        case .leftMouseUp, .otherMouseUp:
            onMouseUp?()
        case .keyDown:
            if event.keyCode == 53 { // Esc key
                onEscape?()
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }
}
