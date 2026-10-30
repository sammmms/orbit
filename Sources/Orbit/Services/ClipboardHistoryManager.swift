import Foundation
import AppKit
import Carbon

public struct ClipboardEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var date: Date

    public init(id: String = UUID().uuidString, text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }

    public var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        if firstLine.count > 60 {
            return String(firstLine.prefix(57)) + "..."
        }
        return firstLine.isEmpty ? "(Empty)" : firstLine
    }
}

@MainActor
public final class ClipboardHistoryManager: ObservableObject {
    public static let shared = ClipboardHistoryManager()

    @Published public private(set) var entries: [ClipboardEntry] = []

    private var lastChangeCount: Int = 0
    private var pollTimer: Timer?
    private let maxEntries = 30

    private var storageURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("orbit", isDirectory: true)
            .appendingPathComponent("clipboard_history.json")
    }

    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        loadFromDisk()
        startPolling()
    }

    public func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForNewClipboardItem()
            }
        }
    }

    public func addEntry(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Avoid adding duplicate of the top item
        if let first = entries.first, first.text == trimmed {
            return
        }

        let newEntry = ClipboardEntry(text: trimmed)
        entries.insert(newEntry, at: 0)

        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }

        saveToDisk()
    }

    private func checkForNewClipboardItem() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Avoid adding duplicate of the top item
        if let first = entries.first, first.text == text {
            return
        }

        let newEntry = ClipboardEntry(text: text)
        entries.insert(newEntry, at: 0)

        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }

        saveToDisk()
    }

    public func selectAndPaste(entry: ClipboardEntry, targetApp: NSRunningApplication? = nil) {
        let myBundleID = Bundle.main.bundleIdentifier ?? "id.bizapps.orbit"
        var appToPaste = targetApp
        if appToPaste == nil || appToPaste?.bundleIdentifier == myBundleID {
            appToPaste = AppState.shared.lastExternalApp
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        self.lastChangeCount = pasteboard.changeCount

        // Bring the selected entry to the top of history
        if let idx = entries.firstIndex(of: entry) {
            entries.remove(at: idx)
            entries.insert(entry, at: 0)
            saveToDisk()
        }

        NSSound(named: "Pop")?.play()

        // 1. Hide Orbit panel immediately
        ClipboardPanelController.shared.closeImmediately()

        // 2. Reactivate target application using dual activation (AppleScript open-app event + NSWorkspace.openApplication)
        if let app = appToPaste {
            print("[Orbit Clipboard] Activating target: \(app.localizedName ?? "") (\(app.bundleIdentifier ?? ""))")
            if let bundleID = app.bundleIdentifier {
                let script = "tell application id \"\(bundleID)\" to activate"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            if let url = app.bundleURL {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
            }
        }

        // 3. Perform proven native CoreGraphics Cmd+V keystroke (Maccy / Flycut engine) after 150ms settle delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.postNativePasteKeystroke()
        }
    }

    private func postNativePasteKeystroke() {
        let isTrusted = AXIsProcessTrusted()
        if !isTrusted {
            print("[Orbit Clipboard] Accessibility not trusted. Prompting user...")
            let options = ["AXTrustedCheckOptionPrompt": true as CFBoolean] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        // 1. AppleScript keystroke
        let script = "tell application \"System Events\" to keystroke \"v\" using command down"
        NSAppleScript(source: script)?.executeAndReturnError(nil)

        // 2. macOS AppKit requires NX_DEVICELCMDKEYMASK (0x000008) in addition to .maskCommand
        // to recognize Command modifier when simulating Cmd+V without physical keypress.
        let cmdFlag = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let vKeyCode: CGKeyCode = 9 // ANSI V

        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("[Orbit Clipboard] Failed to create CGEvent for paste")
            return
        }

        keyVDown.flags = cmdFlag
        keyVUp.flags = cmdFlag

        keyVDown.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            keyVUp.post(tap: .cgSessionEventTap)
        }

        print("[Orbit Clipboard] Successfully posted native Cmd+V to cgSessionEventTap!")
    }

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Non-critical persistence
        }
    }

    private func loadFromDisk() {
        do {
            if FileManager.default.fileExists(atPath: storageURL.path) {
                let data = try Data(contentsOf: storageURL)
                let decoder = JSONDecoder()
                self.entries = try decoder.decode([ClipboardEntry].self, from: data)
            }
        } catch {
            self.entries = []
        }
    }
}
