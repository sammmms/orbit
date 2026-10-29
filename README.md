# 🪐 Orbit

A lightweight, blazing-fast native radial menu (pie menu) for macOS written in **Swift & SwiftUI**.

Hold a hotkey or middle-click anywhere on macOS, and a frosted-glass radial wheel pops up directly under your cursor. Move your mouse towards any slice and release to launch apps, run custom terminal scripts, snip & OCR text from your screen, or control media with zero friction.

```
       [ Terminal ]
            ▲
 [ Lock ]   │   [ VS Code ]
      ◀─────┼─────▶
 [ Notes ]  │   [ Browser ]
            ▼
      [ Screen OCR ]
```

---

## ✨ Why Orbit?

* **Fitts’s Law Speed:** Every option is equidistant from your mouse cursor. Selecting an item requires an angular flick rather than precision aiming, developing subconscious muscle memory over time.
* **100% Native & Featherweight:** 
  * Binary size: **~460 KB** (no Electron, no webview bloat).
  * Memory: **< 25 MB** RAM.
  * Launch latency: **< 5 ms**.
* **Liquid Glass UI:** Built with SwiftUI's native `.ultraThinMaterial`, dynamic spring animations, and subtle haptic feedback.
* **Supercharged Actions:**
  * 💻 **App Launcher:** Instant access to your favorite terminals, editors, or browsers.
  * 📷 **Screen OCR:** Interactive screen selection -> native Apple Vision text recognition -> plain text copied to clipboard.
  * 🎵 **Media Controller:** AppleScript-driven play/pause for Spotify and Apple Music.
  * 🎨 **Native Color Sampler:** Screen eye-dropper that copies hex (`#RRGGBB`) directly to clipboard.
  * 📋 **Clean Paste:** Strips formatting from clipboard and pastes cleanly.
  * ⚡ **Shell Scripting:** Run any custom zsh command in background.
* **Fully Configurable via JSON:** Customize items, icons, colors, and radii in `~/.config/orbit/config.json`.

---

## 🚀 Triggers & Controls

Orbit supports three intuitive trigger styles out of the box:

| Trigger | How it Works |
|---|---|
| **⌥ + Space** | Toggles the menu at cursor. Move to slice and click, or hit **Esc** to cancel. |
| **Middle Click (Hold & Flick)** | Hold scroll wheel down anywhere -> flick cursor toward slice -> release to execute! |
| **Option Hold** | Hold the `⌥ Option` key for >180ms -> wheel appears -> flick and release. |

---

## 🛠️ Installation & Building

### Requirements
* macOS 14.0+ (Sonoma, Sequoia, or newer)
* Swift 6.0+ / Xcode Command Line Tools

### Quick Build & Run
```bash
# Clone or navigate to the repo
cd ~/Documents/GitHub/orbit

# Build and run directly in development
swift run

# Or package into a standalone macOS .app bundle
./scripts/bundle.sh run
```

This creates `Orbit.app` right inside the repo. You can drag `Orbit.app` to `/Applications` or set it to run on login!

---

## ⚙️ Configuration

Orbit creates its configuration file automatically at:
```
~/.config/orbit/config.json
```
You can also click the Orbit status icon in your **Menu Bar** and select **"Edit Configuration..."** to open it instantly.

### Sample Configuration
```json
{
  "appearance": {
    "hapticsEnabled": true,
    "innerRadius": 46,
    "radius": 145,
    "soundEnabled": true
  },
  "trigger": {
    "enableMiddleClick": true,
    "holdDurationMs": 180,
    "holdModifier": "Option",
    "hotkey": "Option+Space"
  },
  "items": [
    {
      "id": "terminal",
      "title": "Terminal",
      "icon": "terminal.fill",
      "color": "green",
      "action": "openApp",
      "payload": "Terminal",
      "subtitle": "Launch Shell"
    },
    {
      "id": "code",
      "title": "VS Code",
      "icon": "chevron.left.forwardslash.chevron.right",
      "color": "blue",
      "action": "openApp",
      "payload": "Visual Studio Code",
      "subtitle": "Code Editor"
    },
    {
      "id": "browser",
      "title": "Browser",
      "icon": "safari.fill",
      "color": "cyan",
      "action": "openUrl",
      "payload": "https://google.com",
      "subtitle": "Open Web"
    },
    {
      "id": "ocr",
      "title": "Screen OCR",
      "icon": "text.viewfinder",
      "color": "orange",
      "action": "ocr",
      "payload": "",
      "subtitle": "Snip & Copy Text"
    },
    {
      "id": "media",
      "title": "Play / Pause",
      "icon": "playpause.fill",
      "color": "pink",
      "action": "mediaPlayPause",
      "payload": "",
      "subtitle": "Music & Spotify"
    },
    {
      "id": "color",
      "title": "Color Picker",
      "icon": "eyedropper.halffull",
      "color": "purple",
      "action": "colorPicker",
      "payload": "",
      "subtitle": "Pick Hex Color"
    },
    {
      "id": "cleanpaste",
      "title": "Clean Paste",
      "icon": "doc.on.clipboard.fill",
      "color": "yellow",
      "action": "cleanPaste",
      "payload": "",
      "subtitle": "Strip Formats"
    },
    {
      "id": "lock",
      "title": "Lock Mac",
      "icon": "lock.fill",
      "color": "red",
      "action": "lockScreen",
      "payload": "",
      "subtitle": "Put Screen to Sleep"
    }
  ]
}
```

### Supported Actions:
* `"openApp"`: Launches application by name or bundle id (`"payload": "Ghostty"` or `"Visual Studio Code"`).
* `"openUrl"`: Opens web address in default browser (`"payload": "https://github.com"`).
* `"runScript"`: Executes arbitrary shell commands via zsh (`"payload": "git status"` or custom bash alias).
* `"ocr"`: Interactive screen snip with automatic optical character recognition to clipboard.
* `"mediaPlayPause"`: Toggles play/pause for Spotify or Apple Music.
* `"colorPicker"`: Native macOS pixel color sampler.
* `"cleanPaste"`: Strips clipboard rich text and pastes plain string.
* `"lockScreen"`: Puts Mac display to sleep immediately.

---

## 🔒 Permissions

Because Orbit listens globally for mouse events and hotkeys:
* macOS requires **Accessibility Permissions** (`System Settings > Privacy & Security > Accessibility`).
* When launching Orbit for the first time, macOS will prompt you to toggle Orbit on in Accessibility.

---

## 📂 Architecture

```
Orbit/
├── Package.swift
├── scripts/
│   └── bundle.sh              # Releases & signs Orbit.app
└── Sources/Orbit/
    ├── main.swift             # App entry point
    ├── AppDelegate.swift      # Background agent lifecycle
    ├── Models/
    │   └── RadialItem.swift   # Item and Config data structures
    ├── Services/
    │   ├── ConfigManager.swift    # JSON persistence (~/.config/orbit/)
    │   ├── ActionExecutor.swift   # OCR, App launch, scripts, AppleScript
    │   └── EventTapManager.swift  # CGEventTap session listener
    └── UI/
        ├── MenuBarController.swift    # NSStatusItem menu bar integration
        ├── RadialPanel.swift          # Non-activating floating NSPanel
        ├── RadialMenuView.swift       # SwiftUI interactive pie menu
        └── RadialSliceShape.swift     # Annular sector trigonometry
```

---

## 📄 License
MIT License. Created by Samuel.
