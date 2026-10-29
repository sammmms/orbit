import SwiftUI
import AppKit

public struct RadialMenuView: View {
    @ObservedObject var configManager: ConfigManager
    public var onSelect: (RadialItem) -> Void
    public var onCancel: () -> Void

    @State private var hoveredIndex: Int? = nil
    @State private var isVisible: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var items: [RadialItem] {
        configManager.config.items
    }

    private var appearance: AppearanceConfig {
        configManager.config.appearance
    }

    private let size: CGFloat = 380.0
    private var center: CGPoint {
        CGPoint(x: size / 2.0, y: size / 2.0)
    }

    private var isDark: Bool {
        if let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return match == .darkAqua
        }
        return colorScheme == .dark
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
            // MARK: - 1. Triangular Pie Slices
            // Each slice owns its own dynamic frosted glass backing, outline, and shadow.
            // NO static under-plate circle! When a slice expands, its entire glass body pops outward!
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                sliceWedgeView(index: index, item: item)
            }

            // MARK: - 2. Center Glass Hub (Orb)
            centerHubView
        }
        .frame(width: size, height: size)
        .scaleEffect(isVisible ? 1.0 : 0.88)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isVisible)
        // High-energy, bouncy spring physics for hovering
        .animation(.spring(response: 0.28, dampingFraction: 0.52, blendDuration: 0.05), value: hoveredIndex)
        .onAppear {
            isVisible = true
        }
        // Continuous mouse hover tracking
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                updateHover(at: location)
            case .ended:
                hoveredIndex = nil
            }
        }
        // Click to commit
        .contentShape(Circle())
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

    // MARK: - Triangular / Annular Wedge Slice View with Dynamic Glass Background
    @ViewBuilder
    private func sliceWedgeView(index: Int, item: RadialItem) -> some View {
        let isSelected = hoveredIndex == index
        let count = max(items.count, 1)
        let step = 360.0 / Double(count)
        let midAngleDeg = -90.0 + (Double(index) * step)

        // Bouncy angular expansion when hovered
        let gapDeg = isSelected ? 1.0 : 2.2
        let angularExpansion = isSelected ? 1.6 : 0.0
        let startAngleDeg = midAngleDeg - (step / 2.0) + (gapDeg / 2.0) - angularExpansion
        let endAngleDeg = midAngleDeg + (step / 2.0) - (gapDeg / 2.0) + angularExpansion

        // Physical radial expansion when hovered (pops 16pt outward, and 4pt inward!)
        let innerR = isSelected ? CGFloat(appearance.innerRadius - 4) : CGFloat(appearance.innerRadius)
        let outerR = isSelected ? CGFloat(appearance.radius + 16) : CGFloat(appearance.radius)

        // Centroid position for the icon and label
        let rad = midAngleDeg * .pi / 180.0
        let midR = (innerR + outerR) / 2.0 + (isSelected ? 5 : 0)
        let posX = center.x + CGFloat(cos(rad)) * midR
        let posY = center.y + CGFloat(sin(rad)) * midR

        let sectorShape = AnnularSector(
            startAngle: Angle(degrees: startAngleDeg),
            endAngle: Angle(degrees: endAngleDeg),
            innerRadius: innerR,
            outerRadius: outerR
        )

        ZStack {
            // A. Frosted Glass Backing FOR THIS SPECIFIC WEDGE
            // Dynamically follows the wedge shape and expands along with it!
            VisualEffectBlur(
                material: isDark ? .underWindowBackground : .menu,
                blendingMode: .behindWindow,
                state: .active,
                appearance: NSAppearance(named: isDark ? .vibrantDark : .vibrantLight)
            )
            .clipShape(sectorShape)
            .opacity(isDark ? (isSelected ? 0.85 : 0.65) : (isSelected ? 0.9 : 0.72))

            // B. Translucent Tint & Accent Gradient
            sectorShape
                .fill(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    item.swiftUIColor.opacity(isDark ? 0.48 : 0.38),
                                    item.swiftUIColor.opacity(isDark ? 0.22 : 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(isDark ? Color.black.opacity(0.18) : Color.white.opacity(0.35))
                )

            // C. Triangular Outline with Bouncy Glow
            sectorShape
                .stroke(
                    isSelected
                        ? item.swiftUIColor
                        : (isDark ? Color.white.opacity(0.24) : Color.black.opacity(0.18)),
                    lineWidth: isSelected ? 3.0 : 1.2
                )
                .shadow(
                    color: isSelected ? item.swiftUIColor.opacity(0.9) : Color.clear,
                    radius: isSelected ? 14 : 0
                )

            // D. Icon and Label directly inside wedge with Bouncy Scale
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: isSelected ? 23 : 18, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(
                        isSelected
                            ? (isDark ? .white : item.swiftUIColor)
                            : (isDark ? item.swiftUIColor.opacity(0.95) : item.swiftUIColor)
                    )
                    .shadow(
                        color: isSelected ? item.swiftUIColor.opacity(0.9) : Color.clear,
                        radius: 8
                    )

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(
                        isSelected
                            ? (isDark ? .white : .black)
                            : (isDark ? .white.opacity(0.9) : Color.black.opacity(0.85))
                    )
                    .lineLimit(1)
            }
            .position(x: posX, y: posY)
            .scaleEffect(isSelected ? 1.24 : 1.0)
        }
        // Native drop shadow follows the actual wedge shape
        .shadow(
            color: Color.black.opacity(isSelected ? (isDark ? 0.45 : 0.25) : (isDark ? 0.22 : 0.1)),
            radius: isSelected ? 18 : 6,
            x: 0,
            y: isSelected ? 8 : 2
        )
        .scaleEffect(isSelected ? 1.06 : 1.0, anchor: .center)
        .zIndex(isSelected ? 20 : 1)
    }

    // MARK: - Center Glass Hub View
    private var centerHubView: some View {
        let innerR = CGFloat(appearance.innerRadius)
        let selectedItem = hoveredIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }

        return ZStack {
            // Frosted Center Orb with adaptive vibrancy
            VisualEffectBlur(
                material: isDark ? .underWindowBackground : .menu,
                blendingMode: .behindWindow,
                state: .active,
                appearance: NSAppearance(named: isDark ? .vibrantDark : .vibrantLight)
            )
            .clipShape(Circle())
            .frame(width: innerR * 2, height: innerR * 2)
            .opacity(isDark ? 0.75 : 0.85)

            Circle()
                .fill(isDark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                .frame(width: innerR * 2, height: innerR * 2)

            // Center Specular Bevel Border
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            selectedItem != nil ? selectedItem!.swiftUIColor : (isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.2)),
                            selectedItem != nil ? selectedItem!.swiftUIColor.opacity(0.4) : (isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: selectedItem != nil ? 2.4 : 1.2
                )
                .frame(width: innerR * 2, height: innerR * 2)
                .shadow(
                    color: selectedItem?.swiftUIColor.opacity(0.65) ?? Color.clear,
                    radius: 10
                )

            // Content inside Orb
            if let item = selectedItem {
                VStack(spacing: 2) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(item.swiftUIColor)
                        .shadow(color: item.swiftUIColor.opacity(0.8), radius: 6)

                    Text(item.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(isDark ? .white : .black)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(isDark ? .white.opacity(0.7) : Color.black.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 17, weight: .light))
                        .foregroundColor(isDark ? .white.opacity(0.5) : Color.black.opacity(0.4))

                    Text("Orbit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isDark ? .white.opacity(0.85) : Color.black.opacity(0.8))
                }
                .transition(.opacity)
            }
        }
        .contentShape(Circle())
        .scaleEffect(selectedItem != nil ? 1.05 : 1.0)
        .shadow(color: Color.black.opacity(isDark ? 0.35 : 0.15), radius: 10, x: 0, y: 4)
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
