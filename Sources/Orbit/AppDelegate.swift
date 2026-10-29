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

        print("[Orbit] Running! Press ⌥ + Space, hold Option, or click Middle Mouse Button to trigger.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        CarbonHotKeyManager.shared.unregister()
        EventTapManager.shared.stop()
    }
}
