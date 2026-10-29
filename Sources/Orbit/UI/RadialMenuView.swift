import SwiftUI
import AppKit

public struct RadialMenuView: View {
    @ObservedObject var configManager: ConfigManager
    public var onSelect: (RadialItem) -> Void
    public var onCancel: () -> Void

    @State private var hoveredIndex: Int? = nil
    @State private var mousePos: CGPoint = .zero
    @State private var isVisible: Bool = false

    private var items: [RadialItem] {
        configManager.config.items
    }

    private var appearance: AppearanceConfig {
        configManager.config.appearance
    }

    private let size: CGFloat = 340.0
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
            // Background blur base
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: appearance.radius * 2 + 30, height: appearance.radius * 2 + 30)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)

            // Slices
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                sliceView(index: index, item: item)
            }

            // Center Hub
            centerHubView
        }
        .frame(width: size, height: size)
        .scaleEffect(isVisible ? 1.0 : 0.85)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isVisible)
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: hoveredIndex)
        .onAppear {
            isVisible = true
        }
        // Continuous tracking of mouse within the panel
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    updateHover(at: value.location)
                }
                .onEnded { value in
                    commitSelection()
                }
        )
    }

    // MARK: - Individual Slice View
    @ViewBuilder
    private func sliceView(index: Int, item: RadialItem) -> some View {
        let isSelected = hoveredIndex == index
        let count = max(items.count, 1)
        let step = 360.0 / Double(count)
        let midAngleDeg = -90.0 + (Double(index) * step)
        let gapDeg = 2.5
        let startAngleDeg = midAngleDeg - (step / 2.0) + (gapDeg / 2.0)
        let endAngleDeg = midAngleDeg + (step / 2.0) - (gapDeg / 2.0)

        let outerR = isSelected ? CGFloat(appearance.radius + 10) : CGFloat(appearance.radius)
        let innerR = CGFloat(appearance.innerRadius)

        // Mid point position for icon & title
        let rad = midAngleDeg * .pi / 180.0
        let midR = (innerR + outerR) / 2.0
        let iconX = center.x + CGFloat(cos(rad)) * midR
        let iconY = center.y + CGFloat(sin(rad)) * midR

        ZStack {
            // Slice wedge shape
            AnnularSector(
                startAngle: Angle(degrees: startAngleDeg),
                endAngle: Angle(degrees: endAngleDeg),
                innerRadius: innerR,
                outerRadius: outerR
            )
            .fill(
                isSelected
                    ? AnyShapeStyle(item.swiftUIColor.opacity(0.35))
                    : AnyShapeStyle(Color.white.opacity(0.04))
            )
            .overlay(
                AnnularSector(
                    startAngle: Angle(degrees: startAngleDeg),
                    endAngle: Angle(degrees: endAngleDeg),
                    innerRadius: innerR,
                    outerRadius: outerR
                )
                .stroke(
                    isSelected
                        ? item.swiftUIColor.opacity(0.8)
                        : Color.white.opacity(0.08),
                    lineWidth: isSelected ? 2.0 : 1.0
                )
            )

            // Slice Icon & Title
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: isSelected ? 20 : 17, weight: .semibold))
                    .foregroundColor(isSelected ? item.swiftUIColor : .primary.opacity(0.9))

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
                    .lineLimit(1)
            }
            .position(x: iconX, y: iconY)
            .scaleEffect(isSelected ? 1.15 : 1.0)
        }
    }

    // MARK: - Center Hub View
    private var centerHubView: some View {
        let innerR = CGFloat(appearance.innerRadius)
        let selectedItem = hoveredIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }

        return ZStack {
            // Glowing border & backdrop
            Circle()
                .fill(.ultraThickMaterial)
                .frame(width: innerR * 2, height: innerR * 2)
                .overlay(
                    Circle()
                        .stroke(
                            selectedItem?.swiftUIColor.opacity(0.7) ?? Color.white.opacity(0.15),
                            lineWidth: selectedItem != nil ? 2.5 : 1.2
                        )
                )
                .shadow(
                    color: selectedItem?.swiftUIColor.opacity(0.3) ?? Color.clear,
                    radius: 12
                )

            // Content inside Hub
            if let item = selectedItem {
                VStack(spacing: 2) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(item.swiftUIColor)

                    Text(item.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.4))

                    Text("Orbit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .transition(.opacity)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            onCancel()
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
        if distance > CGFloat(appearance.radius + 40) {
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
