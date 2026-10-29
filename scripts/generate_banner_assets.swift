import Foundation
import AppKit

func runCli(_ cmd: String, args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: cmd)
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
}

func postNotification(_ name: String) {
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name(name),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

func getOrbitRadialWindowId() -> Int? {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for info in windowListInfo {
        if let ownerName = info[kCGWindowOwnerName as String] as? String, ownerName == "Orbit" {
            let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let w = bounds["Width"] as? Int ?? 0
            if w > 1000 {
                return info[kCGWindowNumber as String] as? Int
            }
        }
    }
    return nil
}

func getOrbitClipboardWindowId() -> Int? {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for info in windowListInfo {
        if let ownerName = info[kCGWindowOwnerName as String] as? String, ownerName == "Orbit" {
            let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let w = bounds["Width"] as? Int ?? 0
            if w < 500 && w > 300 {
                return info[kCGWindowNumber as String] as? Int
            }
        }
    }
    return nil
}

let bannerDir = "/Users/sam/Documents/GitHub/orbit/assets/banner_refs"
try? FileManager.default.createDirectory(atPath: bannerDir, withIntermediateDirectories: true)

let cx: CGFloat = 756
let cy: CGFloat = 491

struct RadialTarget {
    let filename: String
    let mouseX: Int
    let mouseY: Int
    let title: String
}

let targets: [RadialTarget] = [
    RadialTarget(
        filename: "02_radial_menu_neutral.png",
        mouseX: Int(cx),
        mouseY: Int(cy),
        title: "Neutral Radial HUD"
    ),
    RadialTarget(
        filename: "03_radial_menu_hover_terminal.png",
        mouseX: Int(cx),
        mouseY: Int(cy - 95),
        title: "Terminal Hover State"
    ),
    RadialTarget(
        filename: "04_radial_menu_hover_clips.png",
        mouseX: Int(cx + 67),
        mouseY: Int(cy - 67),
        title: "Clips Hover State"
    ),
    RadialTarget(
        filename: "05_radial_menu_hover_media.png",
        mouseX: Int(cx),
        mouseY: Int(cy + 95),
        title: "Media Play/Pause Hover State"
    ),
    RadialTarget(
        filename: "06_radial_menu_hover_lock.png",
        mouseX: Int(cx - 67),
        mouseY: Int(cy - 67),
        title: "Lock Mac Hover State"
    )
]

for t in targets {
    print("Capturing \(t.filename) [\(t.title)]...")
    postNotification("id.bizapps.orbit.closeRadial")
    Thread.sleep(forTimeInterval: 0.25)

    // Position mouse initially at center
    runCli("/opt/homebrew/bin/cliclick", args: ["m:\(Int(cx)),\(Int(cy))"])
    Thread.sleep(forTimeInterval: 0.1)

    // Open Radial HUD
    postNotification("id.bizapps.orbit.openRadial")
    Thread.sleep(forTimeInterval: 0.3)

    // Move mouse to trigger hover
    runCli("/opt/homebrew/bin/cliclick", args: ["m:\(t.mouseX),\(t.mouseY)"])
    Thread.sleep(forTimeInterval: 0.35)

    if let wid = getOrbitRadialWindowId() {
        let tempPath = "\(bannerDir)/temp_raw.png"
        let finalPath = "\(bannerDir)/\(t.filename)"
        runCli("/usr/sbin/screencapture", args: ["-x", "-l\(wid)", "-o", tempPath])
        runCli("/usr/bin/sips", args: ["--cropToHeightWidth", "1040", "1040", tempPath, "--out", finalPath])
        try? FileManager.default.removeItem(atPath: tempPath)
        print(" -> Successfully saved: \(finalPath)")
    } else {
        print(" -> Error: Radial window not found!")
    }

    postNotification("id.bizapps.orbit.closeRadial")
    Thread.sleep(forTimeInterval: 0.25)
}

// Capture Clipboard Panel
print("Capturing 07_clipboard_history_panel.png...")
postNotification("id.bizapps.orbit.showClipboard")
Thread.sleep(forTimeInterval: 0.4)

if let wid = getOrbitClipboardWindowId() {
    let finalPath = "\(bannerDir)/07_clipboard_history_panel.png"
    runCli("/usr/sbin/screencapture", args: ["-x", "-l\(wid)", "-o", finalPath])
    print(" -> Successfully saved: \(finalPath)")
} else {
    print(" -> Error: Clipboard window not found!")
}

runCli("/opt/homebrew/bin/cliclick", args: ["kp:esc"])
Thread.sleep(forTimeInterval: 0.2)

print("\nBanner asset generation complete!")
