import AppKit

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var lastExternalApp: NSRunningApplication?

    private init() {
        captureCurrentExternalApp()
        setupObserver()
    }

    public func start() {
        captureCurrentExternalApp()
    }

    public func captureCurrentExternalApp() {
        let myBundleID = Bundle.main.bundleIdentifier ?? "id.bizapps.orbit"
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != myBundleID,
           current.activationPolicy == .regular {
            self.lastExternalApp = current
            print("[Orbit AppState] Captured external app: \(current.localizedName ?? "") (\(current.bundleIdentifier ?? ""))")
        } else if self.lastExternalApp == nil {
            // Fallback to frontmost non-Orbit regular app
            if let candidate = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier != myBundleID && $0.activationPolicy == .regular && $0.isActive
            }) ?? NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier != myBundleID && $0.activationPolicy == .regular
            }) {
                self.lastExternalApp = candidate
                print("[Orbit AppState] Fallback external app: \(candidate.localizedName ?? "") (\(candidate.bundleIdentifier ?? ""))")
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
                if app.bundleIdentifier != myBundleID && app.activationPolicy == .regular {
                    self.lastExternalApp = app
                    print("[Orbit AppState] Tracked active external app: \(app.localizedName ?? "Unknown")")
                }
            }
        }
    }
}
