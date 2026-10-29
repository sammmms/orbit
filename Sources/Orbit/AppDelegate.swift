import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background menu bar app (no dock icon clutter)
        NSApp.setActivationPolicy(.accessory)

        // Initialize Menu Bar item
        MenuBarController.shared.setup()

        // Start listening to global event tap
        EventTapManager.shared.start()

        print("[Orbit] Running! Press ⌥ + Space, hold Option, or click Middle Mouse Button to trigger.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        EventTapManager.shared.stop()
    }
}
