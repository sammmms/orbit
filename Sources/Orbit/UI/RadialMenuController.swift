import AppKit
import SwiftUI

@MainActor
public final class RadialMenuController: ObservableObject {
    public static let shared = RadialMenuController()

    private var panel: RadialPanel?
    private var hostingView: NSHostingView<AnyView>?

    @Published public private(set) var isOpen: Bool = false
    public var isHoldMode: Bool = false

    private init() {
        setupPanel()
    }

    private func setupPanel() {
        // Initial dummy rect; updated dynamically to fill active screen on open
        let initialRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        let panel = RadialPanel(contentRect: initialRect)

        self.panel = panel

        panel.onEscape = { [weak self] in
            self?.close()
        }
    }

    public func toggle() {
        if isOpen {
            close()
        } else {
            open(holdMode: false)
        }
    }

    public func open(holdMode: Bool = false) {
        guard let panel = panel else { return }
        self.isHoldMode = holdMode

        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        let screenFrame = targetScreen.frame

        // Calculate cursor position in local SwiftUI screen coordinates (top-left origin)
        let localX = mouseLoc.x - screenFrame.origin.x
        let localY = screenFrame.height - (mouseLoc.y - screenFrame.origin.y)
        let cursorPoint = CGPoint(x: localX, y: localY)

        // Construct the overlay view
        let overlayView = RadialMenuOverlayView(
            configManager: ConfigManager.shared,
            menuPosition: cursorPoint,
            onSelect: { [weak self] item in
                self?.executeAndClose(item: item)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )

        let hosting = NSHostingView(rootView: AnyView(overlayView))
        hosting.frame = NSRect(origin: .zero, size: screenFrame.size)
        panel.contentView = hosting
        self.hostingView = hosting

        panel.setFrame(screenFrame, display: true)
        panel.alphaValue = 1.0
        panel.makeKeyAndOrderFront(nil)
        self.isOpen = true
    }

    public func close() {
        guard isOpen, let panel = panel else { return }
        self.isOpen = false
        self.isHoldMode = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak panel] in
            DispatchQueue.main.async {
                guard let panel = panel else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1.0
            }
        })
    }

    public func handleModifierOrKeyRelease() {
        guard isOpen, isHoldMode else { return }
        // For hold mode, release can commit or close
        close()
    }

    private func executeAndClose(item: RadialItem) {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            ActionExecutor.shared.execute(item: item)
        }
    }
}
