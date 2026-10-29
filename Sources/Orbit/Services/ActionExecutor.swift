import Foundation
import AppKit
import Vision

@MainActor
public final class ActionExecutor: Sendable {
    public static let shared = ActionExecutor()

    private init() {}

    public func execute(item: RadialItem) {
        print("[Orbit] Executing action '\(item.action)' for '\(item.title)' (payload: \(item.payload))")

        switch item.action {
        case .openApp:
            openApp(nameOrPath: item.payload.isEmpty ? item.title : item.payload)

        case .openUrl:
            openUrl(item.payload)

        case .runScript:
            runShellScript(item.payload)

        case .ocr:
            triggerScreenOCR()

        case .mediaPlayPause:
            toggleMediaPlayback()

        case .colorPicker:
            triggerColorPicker()

        case .cleanPaste:
            cleanClipboardAndPaste()

        case .lockScreen:
            lockMacDisplay()
        }
    }

    // MARK: - App Launcher
    private func openApp(nameOrPath: String) {
        let ws = NSWorkspace.shared

        // 1. Direct path check
        if FileManager.default.fileExists(atPath: nameOrPath) {
            let url = URL(fileURLWithPath: nameOrPath)
            ws.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            return
        }

        // 2. Search Application by name
        if let appUrl = ws.urlForApplication(withBundleIdentifier: nameOrPath) {
            ws.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            return
        }

        // Common application locations
        let commonDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/Applications"
        ]

        var targetName = nameOrPath
        if !targetName.hasSuffix(".app") {
            targetName += ".app"
        }

        for dir in commonDirs {
            let appPath = (dir as NSString).appendingPathComponent(targetName)
            if FileManager.default.fileExists(atPath: appPath) {
                let url = URL(fileURLWithPath: appPath)
                ws.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                return
            }
        }

        // 3. Fallback: launch via `open -a`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", nameOrPath]
        try? process.run()
    }

    // MARK: - Open URL
    private func openUrl(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Shell Script
    private func runShellScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", script]
            try? process.run()
        }
    }

    // MARK: - Screen Snip & OCR
    private func triggerScreenOCR() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Run macOS interactive screencapture directly to clipboard
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-i", "-c"] // interactive, copy to clipboard
            try? proc.run()
            proc.waitUntilExit()

            guard proc.terminationStatus == 0 else { return }

            // Read image from clipboard
            DispatchQueue.main.async {
                guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
                      let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let cgImage = bitmap.cgImage else {
                    return
                }

                // Run Vision text recognition
                let request = VNRecognizeTextRequest { (request, error) in
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation] else {
                        return
                    }

                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    let extractedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !extractedText.isEmpty else { return }

                    DispatchQueue.main.async {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(extractedText, forType: .string)
                        NSSound(named: "Glass")?.play()
                        print("[Orbit OCR] Extracted \(extractedText.count) characters to clipboard.")
                    }
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }
        }
    }

    // MARK: - Media Play / Pause
    private func toggleMediaPlayback() {
        let scriptSource = """
        tell application "System Events"
            set isSpotifyRunning to (exists (processes where name is "Spotify"))
            set isMusicRunning to (exists (processes where name is "Music"))
        end tell
        if isSpotifyRunning then
            tell application "Spotify" to playpause
        else if isMusicRunning then
            tell application "Music" to playpause
        end if
        """
        if let appleScript = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
        }
    }

    // MARK: - Native Color Sampler
    private func triggerColorPicker() {
        DispatchQueue.main.async {
            let sampler = NSColorSampler()
            sampler.show { selectedColor in
                guard let color = selectedColor,
                      let rgbColor = color.usingColorSpace(.sRGB) else { return }

                let r = Int(round(rgbColor.redComponent * 255.0))
                let g = Int(round(rgbColor.greenComponent * 255.0))
                let b = Int(round(rgbColor.blueComponent * 255.0))
                let hex = String(format: "#%02X%02X%02X", r, g, b)

                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(hex, forType: .string)
                NSSound(named: "Tink")?.play()
                print("[Orbit ColorPicker] Picked hex: \(hex)")
            }
        }
    }

    // MARK: - Clean Clipboard & Paste
    private func cleanClipboardAndPaste() {
        let pasteboard = NSPasteboard.general
        guard let currentText = pasteboard.string(forType: .string) else { return }

        // Strip formatting by re-writing only plain string
        pasteboard.clearContents()
        pasteboard.setString(currentText, forType: .string)
        NSSound(named: "Pop")?.play()

        // Simulate Cmd+V
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
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

    // MARK: - Lock Mac
    private func lockMacDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }
}
