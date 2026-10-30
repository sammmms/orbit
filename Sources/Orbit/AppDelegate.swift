import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance: terminate any other running Orbit instances
        let myPID = ProcessInfo.processInfo.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? "id.bizapps.orbit"
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            if app.processIdentifier != myPID {
                app.terminate()
            }
        }

        // Run as background menu bar app (no dock icon clutter)
        NSApp.setActivationPolicy(.accessory)

        // Check & prompt for Accessibility permissions (needed to simulate Cmd+V paste)
        let options = ["AXTrustedCheckOptionPrompt": true as CFBoolean] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("[Orbit] Accessibility permission trusted on launch: \(trusted)")

        // Check Screen Capture permission status on launch
        let screenCaptureTrusted = CGPreflightScreenCaptureAccess()
        print("[Orbit] Screen Capture permission trusted on launch: \(screenCaptureTrusted)")

        // Ensure configuration is loaded or created
        _ = ConfigManager.shared

        // Start tracking active external application for bulletproof auto-paste
        AppState.shared.start()

        // Start tracking clipboard history in background
        ClipboardHistoryManager.shared.startPolling()

        // Initialize Menu Bar item
        MenuBarController.shared.setup()

        // Register Global Carbon HotKey (Option + Space)
        // This fires at the WindowServer level, bypassing any terminal / tmux / secure input suppression!
        CarbonHotKeyManager.shared.register()

        // Start listening to global event tap (for middle mouse & option hold)
        EventTapManager.shared.start()

        // Distributed notifications for automation & external triggers
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("id.bizapps.orbit.trigger"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                RadialMenuController.shared.toggle()
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("id.bizapps.orbit.openRadial"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if !RadialMenuController.shared.isOpen {
                    RadialMenuController.shared.open()
                }
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("id.bizapps.orbit.closeRadial"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                RadialMenuController.shared.close()
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("id.bizapps.orbit.showClipboard"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ClipboardPanelController.shared.show()
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("id.bizapps.orbit.closeClipboard"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ClipboardPanelController.shared.close()
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("id.bizapps.orbit.triggerOCR"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ActionExecutor.shared.execute(item: RadialItem(
                    id: "ocr",
                    title: "Screen OCR",
                    icon: "text.viewfinder",
                    color: "orange",
                    action: .ocr,
                    payload: "",
                    subtitle: "Copy Text"
                ))
            }
        }

        print("[Orbit] Running! Press ⌥ + Space, hold Option, or click Middle Mouse Button to trigger.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        CarbonHotKeyManager.shared.unregister()
        EventTapManager.shared.stop()
    }
}
