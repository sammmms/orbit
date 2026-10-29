import Foundation
import Combine
import AppKit

@MainActor
public final class ConfigManager: ObservableObject {
    public static let shared = ConfigManager()

    @Published public var config: OrbitConfig

    private let fileManager = FileManager.default
    private var configDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("orbit", isDirectory: true)
    }

    private var configFileURL: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    private init() {
        self.config = OrbitConfig()
        loadConfig()
    }

    public func loadConfig() {
        do {
            if !fileManager.fileExists(atPath: configFileURL.path) {
                try createDefaultConfigFile()
            }
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            self.config = try decoder.decode(OrbitConfig.self, from: data)
            print("[Orbit] Loaded configuration with \(self.config.items.count) radial items.")
        } catch {
            print("[Orbit] Warning: Could not load config.json (\(error)). Using defaults.")
            self.config = OrbitConfig()
        }
    }

    public func saveConfig() {
        do {
            try ensureDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFileURL, options: .atomic)
            print("[Orbit] Configuration saved successfully to \(configFileURL.path)")
        } catch {
            print("[Orbit] Error saving config: \(error)")
        }
    }

    private func createDefaultConfigFile() throws {
        try ensureDirectoryExists()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let defaultData = try encoder.encode(OrbitConfig())
        try defaultData.write(to: configFileURL, options: .atomic)
        print("[Orbit] Created default configuration file at: \(configFileURL.path)")
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: configDirectory.path) {
            try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
    }

    public func openConfigFileInEditor() {
        try? ensureDirectoryExists()
        if !fileManager.fileExists(atPath: configFileURL.path) {
            try? createDefaultConfigFile()
        }
        // Try opening with default text editor or VS Code / TextEdit
        let ws = NSWorkspace.shared
        ws.open(configFileURL)
    }

    public func openConfigDirectory() {
        try? ensureDirectoryExists()
        NSWorkspace.shared.selectFile(configFileURL.path, inFileViewerRootedAtPath: configDirectory.path)
    }
}
