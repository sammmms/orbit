import Foundation
import AppKit

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

        // 1. Re-activate the target application so it regains window focus
        if let app = targetApp {
            app.activate()
        }

        // 2. Give macOS 150ms to complete focus switch, then simulate Cmd + V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // A. AppleScript paste (guaranteed to deliver to the frontmost active window)
            let script = "tell application \"System Events\" to keystroke \"v\" using command down"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if error == nil {
                    print("[Orbit Clipboard] Successfully pasted via AppleScript keystroke!")
                    return
                }
            }

            // B. Fallback: CGEvent keyboard simulation
            let src = CGEventSource(stateID: .combinedSessionState)
            let vKeyCode: CGKeyCode = 9 // 'v'
            if let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) {
                keyDown.flags = .maskCommand
                keyUp.flags = .maskCommand
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
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
