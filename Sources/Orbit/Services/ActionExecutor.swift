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

        case .clipboardHistory:
            showClipboardHistory()
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

    // MARK: - Native macOS Media Remote (MRMediaRemoteSendCommand)
    private func toggleMediaPlayback() {
        // 1. Apple's native private MediaRemote framework (controls Spotify, YouTube in Safari/Chrome/Zen, Apple Music, Podcasts, VLC, etc.)
        let mediaRemoteBundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        if let bundle = mediaRemoteBundle,
           let functionPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool
            let sendCommand = unsafeBitCast(functionPointer, to: MRMediaRemoteSendCommandFunction.self)
            // 2 = kMRTogglePlayPause
            let success = sendCommand(2, nil)
            print("[Orbit] MRMediaRemoteSendCommand(TogglePlayPause) result: \(success)")
        }

        // 2. Hardware media key simulation fallback (NX_KEYTYPE_PLAY)
        func postMediaKey(down: Bool) {
            let key: Int32 = 16 // NX_KEYTYPE_PLAY
            let flags: NSEvent.ModifierFlags = down ? .init(rawValue: 0xa00) : .init(rawValue: 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            ev?.cgEvent?.post(tap: .cghidEventTap)
        }
        postMediaKey(down: true)
        postMediaKey(down: false)
    }

    // MARK: - Clipboard History
    private func showClipboardHistory() {
        ClipboardPanelController.shared.show()
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

        ClipboardHistoryManager.shared.selectAndPaste(
            entry: ClipboardEntry(text: currentText),
            targetApp: AppState.shared.lastExternalApp
        )
    }

    // MARK: - Lock Mac
    private func lockMacDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }
}
