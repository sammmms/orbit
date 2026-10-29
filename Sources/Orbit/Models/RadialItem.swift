import Foundation
import SwiftUI

public enum RadialActionType: String, Codable, Sendable {
    case openApp
    case openUrl
    case runScript
    case ocr
    case mediaPlayPause
    case colorPicker
    case cleanPaste
    case lockScreen
}

public struct RadialItem: Identifiable, Codable, Sendable {
    public var id: String
    public var title: String
    public var icon: String // SF Symbol name
    public var color: String // Hex or named: blue, green, orange, purple, pink, cyan, red, yellow
    public var action: RadialActionType
    public var payload: String
    public var subtitle: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        icon: String,
        color: String = "blue",
        action: RadialActionType,
        payload: String = "",
        subtitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
        self.payload = payload
        self.subtitle = subtitle
    }

    public var swiftUIColor: Color {
        switch color.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "red": return .red
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "mint": return .mint
        case "teal": return .teal
        default:
            if color.hasPrefix("#") {
                return Color(hex: color) ?? .accentColor
            }
            return .accentColor
        }
    }
}

public struct TriggerConfig: Codable, Sendable {
    public var hotkey: String // e.g. "Option+Space"
    public var enableMiddleClick: Bool
    public var holdModifier: String // "Option", "Control", "None"
    public var holdDurationMs: Int

    public init(
        hotkey: String = "Option+Space",
        enableMiddleClick: Bool = true,
        holdModifier: String = "Option",
        holdDurationMs: Int = 180
    ) {
        self.hotkey = hotkey
        self.enableMiddleClick = enableMiddleClick
        self.holdModifier = holdModifier
        self.holdDurationMs = holdDurationMs
    }
}

public struct AppearanceConfig: Codable, Sendable {
    public var radius: Double
    public var innerRadius: Double
    public var hapticsEnabled: Bool
    public var soundEnabled: Bool

    public init(
        radius: Double = 145.0,
        innerRadius: Double = 46.0,
        hapticsEnabled: Bool = true,
        soundEnabled: Bool = true
    ) {
        self.radius = radius
        self.innerRadius = innerRadius
        self.hapticsEnabled = hapticsEnabled
        self.soundEnabled = soundEnabled
    }
}

public struct OrbitConfig: Codable, Sendable {
    public var trigger: TriggerConfig
    public var appearance: AppearanceConfig
    public var items: [RadialItem]

    public init(
        trigger: TriggerConfig = TriggerConfig(),
        appearance: AppearanceConfig = AppearanceConfig(),
        items: [RadialItem] = OrbitConfig.defaultItems
    ) {
        self.trigger = trigger
        self.appearance = appearance
        self.items = items
    }

    public static let defaultItems: [RadialItem] = [
        RadialItem(
            id: "terminal",
            title: "Terminal",
            icon: "terminal.fill",
            color: "green",
            action: .openApp,
            payload: "Terminal",
            subtitle: "Launch Shell"
        ),
        RadialItem(
            id: "code",
            title: "VS Code",
            icon: "chevron.left.forwardslash.chevron.right",
            color: "blue",
            action: .openApp,
            payload: "Visual Studio Code",
            subtitle: "Code Editor"
        ),
        RadialItem(
            id: "browser",
            title: "Browser",
            icon: "safari.fill",
            color: "cyan",
            action: .openUrl,
            payload: "https://google.com",
            subtitle: "Open Web"
        ),
        RadialItem(
            id: "ocr",
            title: "Screen OCR",
            icon: "text.viewfinder",
            color: "orange",
            action: .ocr,
            payload: "",
            subtitle: "Snip & Copy Text"
        ),
        RadialItem(
            id: "media",
            title: "Play / Pause",
            icon: "playpause.fill",
            color: "pink",
            action: .mediaPlayPause,
            payload: "",
            subtitle: "Music & Spotify"
        ),
        RadialItem(
            id: "color",
            title: "Color Picker",
            icon: "eyedropper.halffull",
            color: "purple",
            action: .colorPicker,
            payload: "",
            subtitle: "Pick Hex Color"
        ),
        RadialItem(
            id: "cleanpaste",
            title: "Clean Paste",
            icon: "doc.on.clipboard.fill",
            color: "yellow",
            action: .cleanPaste,
            payload: "",
            subtitle: "Strip Formats"
        ),
        RadialItem(
            id: "lock",
            title: "Lock Mac",
            icon: "lock.fill",
            color: "red",
            action: .lockScreen,
            payload: "",
            subtitle: "Put Screen to Sleep"
        )
    ]
}

// Color Hex Extension
extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.remove(at: cleanHex.startIndex)
        }
        guard cleanHex.count == 6 || cleanHex.count == 8 else { return nil }

        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)

        if cleanHex.count == 6 {
            self.init(
                red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgbValue & 0x0000FF) / 255.0
            )
        } else {
            self.init(
                red: Double((rgbValue & 0xFF000000) >> 24) / 255.0,
                green: Double((rgbValue & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgbValue & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgbValue & 0x000000FF) / 255.0
            )
        }
    }
}
