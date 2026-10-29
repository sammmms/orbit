import SwiftUI
import AppKit

public struct RadialMenuView: View {
    @ObservedObject var configManager: ConfigManager
    public var onSelect: (RadialItem) -> Void
    public var onCancel: () -> Void

    @State private var hoveredIndex: Int? = nil
    @State private var isVisible: Bool = false

    private var items: [RadialItem] {
        configManager.config.items
    }

    private var appearance: AppearanceConfig {
        configManager.config.appearance
    }

    private let size: CGFloat = 360.0
    private var center: CGPoint {
        CGPoint(x: size / 2.0, y: size / 2.0)
    }

    public init(
        configManager: ConfigManager = .shared,
        onSelect: @escaping (RadialItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.configManager = configManager
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            // MARK: - 1. Native macOS Frosted Glass Backing
            let discDiameter = CGFloat(appearance.radius * 2 + 50)

            ZStack {
                // Real system window blur behind window
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                    .clipShape(Circle())

                // Dark glass tint for contrast over light wallpapers
                Circle()
                    .fill(Color.black.opacity(0.22))

                // Subtle concentric orbit guide tracks
                Circle()
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .frame(width: (appearance.radius + appearance.innerRadius), height: (appearance.radius + appearance.innerRadius))

                // Outer Glass Specular Bevel Border
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .frame(width: discDiameter, height: discDiameter)
            // Multi-tier macOS shadows
            .shadow(color: Color.black.opacity(0.45), radius: 36, x: 0, y: 18)
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)

            // MARK: - 2. Active Slice Glow Aura (Behind items)
            if let idx = hoveredIndex, items.indices.contains(idx) {
                let item = items[idx]
                let count = max(items.count, 1)
                let step = 360.0 / Double(count)
                let midAngleDeg = -90.0 + (Double(idx) * step)
                let rad = midAngleDeg * .pi / 180.0
                let midR = (CGFloat(appearance.innerRadius) + CGFloat(appearance.radius)) / 2.0
                let glowX = center.x + CGFloat(cos(rad)) * midR
                let glowY = center.y + CGFloat(sin(rad)) * midR

                // Vibrant colorful backlight
                Circle()
                    .fill(item.swiftUIColor.opacity(0.45))
                    .frame(width: 90, height: 90)
                    .blur(radius: 24)
                    .position(x: glowX, y: glowY)
                    .transition(.opacity)
            }

            // MARK: - 3. Radial Slices & Pods
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                sliceItemView(index: index, item: item)
            }

            // MARK: - 4. Center Glass Orb Hub
            centerHubView
        }
        .frame(width: size, height: size)
        .scaleEffect(isVisible ? 1.0 : 0.88)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.74), value: isVisible)
        .animation(.spring(response: 0.2, dampingFraction: 0.72), value: hoveredIndex)
        .onAppear {
            isVisible = true
        }
    }

    // MARK: - Slice & Pod View
    @ViewBuilder
    private func sliceItemView(index: Int, item: RadialItem) -> some View {
        let isSelected = hoveredIndex == index
        let count = max(items.count, 1)
        let step = 360.0 / Double(count)
        let midAngleDeg = -90.0 + (Double(index) * step)
        let gapDeg = 3.0
        let startAngleDeg = midAngleDeg - (step / 2.0) + (gapDeg / 2.0)
        let endAngleDeg = midAngleDeg + (step / 2.0) - (gapDeg / 2.0)

        let innerR = CGFloat(appearance.innerRadius)
        let outerR = CGFloat(appearance.radius)

        // Center point for the action pod
        let rad = midAngleDeg * .pi / 180.0
        let midR = (innerR + outerR) / 2.0
        let podX = center.x + CGFloat(cos(rad)) * midR
        let podY = center.y + CGFloat(sin(rad)) * midR

        ZStack {
            // Subtle sector wedge indicator when selected
            if isSelected {
                AnnularSector(
                    startAngle: Angle(degrees: startAngleDeg),
                    endAngle: Angle(degrees: endAngleDeg),
                    innerRadius: innerR + 2,
                    outerRadius: outerR + 10
                )
                .fill(
                    RadialGradient(
                        colors: [
                            item.swiftUIColor.opacity(0.32),
                            item.swiftUIColor.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: innerR,
                        endRadius: outerR + 15
                    )
                )
                .overlay(
                    // Outer neon rim indicator
                    AnnularSector(
                        startAngle: Angle(degrees: startAngleDeg + 1),
                        endAngle: Angle(degrees: endAngleDeg - 1),
                        innerRadius: outerR + 7,
                        outerRadius: outerR + 10
                    )
                    .fill(item.swiftUIColor)
                    .shadow(color: item.swiftUIColor.opacity(0.8), radius: 6)
                )
                .transition(.opacity)
            }

            // Floating Glass Capsule Pod
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: isSelected ? 21 : 17, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? .white : item.swiftUIColor.opacity(0.95))
                    .shadow(color: isSelected ? item.swiftUIColor.opacity(0.9) : Color.clear, radius: 8)

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSelected {
                        // Glowing selected capsule
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        item.swiftUIColor.opacity(0.65),
                                        item.swiftUIColor.opacity(0.35)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.85), item.swiftUIColor.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                    } else {
                        // Inactive glass pill
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    }
                }
            )
            .position(x: podX, y: podY)
            .scaleEffect(isSelected ? 1.16 : 1.0)
            .shadow(
                color: isSelected ? item.swiftUIColor.opacity(0.5) : Color.black.opacity(0.2),
                radius: isSelected ? 12 : 4,
                y: isSelected ? 4 : 2
            )
        }
    }

    // MARK: - Center Hub View (Orb)
    private var centerHubView: some View {
        let innerR = CGFloat(appearance.innerRadius)
        let selectedItem = hoveredIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }

        return ZStack {
            // Frosted Center Orb
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow, state: .active)
                .clipShape(Circle())
                .frame(width: innerR * 2, height: innerR * 2)

            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: innerR * 2, height: innerR * 2)

            // Center Specular Bevel Border
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            selectedItem != nil ? selectedItem!.swiftUIColor.opacity(0.9) : Color.white.opacity(0.45),
                            selectedItem != nil ? selectedItem!.swiftUIColor.opacity(0.3) : Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: selectedItem != nil ? 2.2 : 1.2
                )
                .frame(width: innerR * 2, height: innerR * 2)
                .shadow(
                    color: selectedItem?.swiftUIColor.opacity(0.5) ?? Color.clear,
                    radius: 12
                )

            // Content inside Orb
            if let item = selectedItem {
                VStack(spacing: 2) {
                    Image(systemName: item.icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(item.swiftUIColor)
                        .shadow(color: item.swiftUIColor.opacity(0.7), radius: 6)

                    Text(item.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.45))

                    Text("Orbit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Angle & Hover Math
    public func updateHover(at point: CGPoint) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        // Inside inner deadzone: no selection
        if distance < CGFloat(appearance.innerRadius) {
            if hoveredIndex != nil {
                hoveredIndex = nil
                triggerHaptic()
            }
            return
        }

        // Outside outer ring limit: no selection
        if distance > CGFloat(appearance.radius + 45) {
            if hoveredIndex != nil {
                hoveredIndex = nil
            }
            return
        }

        // Angle calculation
        let count = max(items.count, 1)
        let step = 360.0 / Double(count)

        // atan2 in screen coordinates (dy down is positive)
        let rad = atan2(dy, dx)
        let deg = rad * 180.0 / .pi

        // Normalize so -90° (top) is 0°
        var compassDeg = deg + 90.0
        if compassDeg < 0.0 { compassDeg += 360.0 }

        let index = Int(round(compassDeg / step)) % count
        if hoveredIndex != index {
            hoveredIndex = index
            triggerHaptic()
        }
    }

    public func commitSelection() {
        if let idx = hoveredIndex, items.indices.contains(idx) {
            let item = items[idx]
            onSelect(item)
        } else {
            onCancel()
        }
    }

    private func triggerHaptic() {
        guard appearance.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }
}
