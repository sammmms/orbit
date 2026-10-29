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

        // 2. Activate target app and paste via AppleScript & Hardware event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let app = appToPaste, let bundleID = app.bundleIdentifier, bundleID != myBundleID {
                print("[Orbit Clipboard] Activating target: \(app.localizedName ?? "") (\(bundleID))")
                app.activate(options: [.activateAllWindows])

                let script = """
                tell application id "\(bundleID)" to activate
                delay 0.08
                tell application "System Events" to keystroke "v" using command down
                """
                var err: NSDictionary?
                let res = NSAppleScript(source: script)?.executeAndReturnError(&err)
                print("[Orbit Clipboard] AppleScript res: \(res != nil), err: \(err?.description ?? "none")")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    self.postHardwareCmdV()
                }
            } else {
                print("[Orbit Clipboard] Fallback activation...")
                appToPaste?.activate(options: [.activateAllWindows])
                let script = """
                delay 0.08
                tell application "System Events" to keystroke "v" using command down
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    self.postHardwareCmdV()
                }
            }
        }
    }

    private func postHardwareCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            keyUp.post(tap: .cghidEventTap)
        }
        print("[Orbit Clipboard] Posted hardware Cmd+V tap")
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
