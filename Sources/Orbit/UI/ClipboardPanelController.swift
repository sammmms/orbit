import AppKit
import SwiftUI

public final class ClipboardPanel: NSPanel {
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
        if event.keyCode == 53 { // Esc
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

@MainActor
public final class ClipboardPanelController: ObservableObject {
    public static let shared = ClipboardPanelController()

    private var panel: ClipboardPanel?
    private var previousApp: NSRunningApplication?

    private init() {}

    public func show() {
        // Capture currently frontmost app before opening clipboard window, fallback to AppState
        let myBundleID = Bundle.main.bundleIdentifier ?? "id.bizapps.orbit"
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != myBundleID,
           front.activationPolicy == .regular {
            self.previousApp = front
        } else {
            self.previousApp = AppState.shared.lastExternalApp
        }

        if panel == nil {
            let p = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 400))
            p.onEscape = { [weak self] in
                self?.close()
            }
            self.panel = p
        }

        guard let panel = panel else { return }

        let contentView = ClipboardHistoryView(
            onSelect: { [weak self] entry in
                let myBundleID = Bundle.main.bundleIdentifier ?? "id.bizapps.orbit"
                var target = self?.previousApp
                if target == nil || target?.bundleIdentifier == myBundleID {
                    target = AppState.shared.lastExternalApp
                }
                self?.closeImmediately()
                ClipboardHistoryManager.shared.selectAndPaste(entry: entry, targetApp: target)
            },
            onClose: { [weak self] in
                self?.close()
            }
        )

        let hosting = NSHostingView(rootView: contentView)
        panel.contentView = hosting

        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = targetScreen.frame

        let desiredX = mouseLoc.x - 190.0
        let desiredY = mouseLoc.y - 200.0

        // Clamp to screen
        let clampedX = min(max(screenFrame.minX + 20, desiredX), screenFrame.maxX - 400)
        let clampedY = min(max(screenFrame.minY + 20, desiredY), screenFrame.maxY - 420)

        panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        panel.alphaValue = 1.0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    public func closeImmediately() {
        guard let panel = panel else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1.0
    }

    public func close() {
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak panel] in
            DispatchQueue.main.async {
                panel?.orderOut(nil)
                panel?.alphaValue = 1.0
            }
        })
    }
}
