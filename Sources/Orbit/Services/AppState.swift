import AppKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var lastExternalApp: NSRunningApplication?

    private init() {
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.lastExternalApp = current
        }
        setupObserver()
    }

    public func start() {
        // Trigger initialization
        if lastExternalApp == nil {
            if let current = NSWorkspace.shared.frontmostApplication,
               current.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.lastExternalApp = current
            }
        }
    }

    private func setupObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                guard let self = self, let app = app else { return }
                let myBundleID = Bundle.main.bundleIdentifier ?? "id.bizapps.orbit"
                if app.bundleIdentifier != myBundleID {
                    self.lastExternalApp = app
                    print("[Orbit AppState] Tracked active external app: \(app.localizedName ?? "Unknown")")
                }
            }
        }
    }
}
