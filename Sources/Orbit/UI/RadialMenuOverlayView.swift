import SwiftUI

public struct RadialMenuOverlayView: View {
    @ObservedObject var configManager: ConfigManager
    public var menuPosition: CGPoint // in local SwiftUI screen coordinates
    public var onSelect: (RadialItem) -> Void
    public var onCancel: () -> Void

    public init(
        configManager: ConfigManager = .shared,
        menuPosition: CGPoint,
        onSelect: @escaping (RadialItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.configManager = configManager
        self.menuPosition = menuPosition
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        GeometryReader { geometry in
            let wheelSize: CGFloat = 360.0
            let margin = wheelSize / 2.0 + 10.0

            // Clamp so wheel is never clipped at screen edges
            let clampedX = min(max(margin, menuPosition.x), geometry.size.width - margin)
            let clampedY = min(max(margin, menuPosition.y), geometry.size.height - margin)

            ZStack {
                // Fullscreen transparent backdrop: catches any clicks outside and dismisses Orbit
                // without passing clicks to the background desktop or apps!
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCancel()
                    }

                // The Radial Menu Wheel
                RadialMenuView(
                    configManager: configManager,
                    onSelect: onSelect,
                    onCancel: onCancel
                )
                .position(x: clampedX, y: clampedY)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
