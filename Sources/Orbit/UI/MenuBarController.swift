import AppKit

@MainActor
public final class MenuBarController {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?

    private init() {}

    public func setup() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "Orbit") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "◎"
        }

        let menu = NSMenu()

        let triggerItem = NSMenuItem(title: "Trigger Orbit", action: #selector(triggerOrbit), keyEquivalent: " ")
        triggerItem.keyEquivalentModifierMask = [.option]
        triggerItem.target = self
        menu.addItem(triggerItem)

        menu.addItem(NSMenuItem.separator())

        let openConfigItem = NSMenuItem(title: "Edit Configuration...", action: #selector(openConfig), keyEquivalent: ",")
        openConfigItem.target = self
        menu.addItem(openConfigItem)

        let openFolderItem = NSMenuItem(title: "Open Config Folder", action: #selector(openConfigFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About Orbit", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit Orbit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func triggerOrbit() {
        RadialMenuController.shared.toggle()
    }

    @objc private func openConfig() {
        ConfigManager.shared.openConfigFileInEditor()
    }

    @objc private func openConfigFolder() {
        ConfigManager.shared.openConfigDirectory()
    }

    @objc private func reloadConfig() {
        ConfigManager.shared.loadConfig()
        let alert = NSAlert()
        alert.messageText = "Configuration Reloaded"
        alert.informativeText = "Orbit loaded \(ConfigManager.shared.config.items.count) items from config.json."
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Orbit for macOS"
        alert.informativeText = "A lightweight native radial menu for macOS.\n\nTrigger with:\n• ⌥ + Space\n• Middle Mouse Button (Hold & Flick)\n• Option Key Hold\n\nCrafted with Swift & SwiftUI."
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
