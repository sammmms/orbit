import AppKit
import SwiftUI

@MainActor
public final class RadialMenuController: ObservableObject {
    public static let shared = RadialMenuController()

    private var panel: RadialPanel?
    private var hostingView: NSHostingView<AnyView>?
    private let windowSize: CGFloat = 340.0
    private var currentMenuView: RadialMenuView?

    @Published public private(set) var isOpen: Bool = false
    public var isHoldMode: Bool = false

    private init() {
        setupPanel()
    }

    private func setupPanel() {
        let rect = NSRect(x: 0, y: 0, width: windowSize, height: windowSize)
        let panel = RadialPanel(contentRect: rect)

        let menuView = RadialMenuView(
            configManager: ConfigManager.shared,
            onSelect: { [weak self] item in
                self?.executeAndClose(item: item)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        self.currentMenuView = menuView

        let anyView = AnyView(menuView)
        let hosting = NSHostingView(rootView: anyView)
        hosting.frame = NSRect(x: 0, y: 0, width: windowSize, height: windowSize)

        panel.contentView = hosting
        self.panel = panel
        self.hostingView = hosting

        panel.onMouseMove = { [weak self] point in
            self?.currentMenuView?.updateHover(at: point)
        }

        panel.onMouseUp = { [weak self] in
            if self?.isHoldMode == true {
                self?.currentMenuView?.commitSelection()
            }
        }

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
        let origin = NSPoint(
            x: mouseLoc.x - (windowSize / 2.0),
            y: mouseLoc.y - (windowSize / 2.0)
        )

        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        self.isOpen = true
    }

    public func close() {
        guard isOpen, let panel = panel else { return }
        self.isOpen = false
        self.isHoldMode = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
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
        currentMenuView?.commitSelection()
    }

    public func updateMousePosition(_ screenPoint: NSPoint) {
        guard isOpen, let panel = panel else { return }
        let windowOrigin = panel.frame.origin
        let localX = screenPoint.x - windowOrigin.x
        let localY = screenPoint.y - windowOrigin.y
        let swiftUIPoint = CGPoint(x: localX, y: windowSize - localY)
        currentMenuView?.updateHover(at: swiftUIPoint)
    }

    private func executeAndClose(item: RadialItem) {
        close()
        // Execute on next runloop tick to let UI close cleanly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            ActionExecutor.shared.execute(item: item)
        }
    }
}
