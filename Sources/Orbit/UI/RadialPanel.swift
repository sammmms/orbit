import AppKit
import SwiftUI

public final class RadialPanel: NSPanel {
    public var onEscape: (() -> Void)?

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .popUpMenu
        self.isFloatingPanel = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}
