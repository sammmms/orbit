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
            // MARK: - 1. Dynamic Glass Lens Disc (Expands seamlessly with hovered slice!)
            let isHovering = hoveredIndex != nil
            let discDiameter = CGFloat(appearance.radius * 2 + (isHovering ? 26 : 8))

            ZStack {
                // A. Real hardware GPU Gaussian blur behind window
                VisualEffectBlur(
                    material: isDark ? .underWindowBackground : .popover,
                    blendingMode: .behindWindow,
                    state: .active,
                    appearance: NSAppearance(named: isDark ? .vibrantDark : .vibrantLight)
                )
                .clipShape(Circle())
                .opacity(isDark ? 0.68 : 0.78)

                // B. Optical Glass Tint
                Circle()
                    .fill(isDark ? Color.black.opacity(0.18) : Color.white.opacity(0.35))

                // C. Surface Gloss Sheen (Angled studio reflection across the glass lens)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                isDark ? Color.white.opacity(0.24) : Color.white.opacity(0.45),
                                Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // D. Specular Glass Bevel Rim (Catches light at top-left, shadow at bottom-right)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDark ? 0.65 : 0.8),
                                Color.white.opacity(0.2),
                                Color.clear,
                                Color.white.opacity(isDark ? 0.25 : 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .frame(width: discDiameter, height: discDiameter)
            // Multi-tier optical glass drop shadows
            .shadow(color: Color.black.opacity(isDark ? 0.45 : 0.22), radius: 32, x: 0, y: 16)
            .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.1), radius: 10, x: 0, y: 4)
            .animation(.spring(response: 0.28, dampingFraction: 0.58), value: isHovering)

            // MARK: - 2. Triangular Pie Slices with Dynamic Glass Physics
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                sliceWedgeView(index: index, item: item)
            }

            // MARK: - 3. Center Crystal Glass Orb Hub
            centerHubView
        }
        .frame(width: size, height: size)
        .scaleEffect(isVisible ? 1.0 : 0.88)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isVisible)
        // High-energy bouncy spring physics for hovering
        .animation(.spring(response: 0.28, dampingFraction: 0.55, blendDuration: 0.05), value: hoveredIndex)
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

    // MARK: - Triangular / Annular Wedge Slice View with Radial Offset Pop
    @ViewBuilder
    private func sliceWedgeView(index: Int, item: RadialItem) -> some View {
        let isSelected = hoveredIndex == index
        let count = max(items.count, 1)
        let step = 360.0 / Double(count)
        let midAngleDeg = -90.0 + (Double(index) * step)

        // Strict angular borders with 2.5° gap (GUARANTEES ZERO OVERLAP WITH NEIGHBORS!)
        let gapDeg = 2.5
        let startAngleDeg = midAngleDeg - (step / 2.0) + (gapDeg / 2.0)
        let endAngleDeg = midAngleDeg + (step / 2.0) - (gapDeg / 2.0)

        let innerR = CGFloat(appearance.innerRadius)
        let outerR = CGFloat(appearance.radius)

        // Radial direction vector
        let rad = midAngleDeg * .pi / 180.0
        let dirX = CGFloat(cos(rad))
        let dirY = CGFloat(sin(rad))

        // Radial pop distance: slides cleanly outward along its spoke by 8pt
        // Moving outward widens the spacing, so collision with neighbors or hub is IMPOSSIBLE!
        let popDistance: CGFloat = isSelected ? 8.0 : 0.0
        let offsetX = dirX * popDistance
        let offsetY = dirY * popDistance

        // Centroid position for the icon and label
        // Positioned safely at 44% of distance between innerR and outerR (over 35pt margin from outer rim!)
        let midR = innerR + (outerR - innerR) * 0.44
        let posX = center.x + dirX * midR
        let posY = center.y + dirY * midR

        let sectorShape = AnnularSector(
            startAngle: Angle(degrees: startAngleDeg),
            endAngle: Angle(degrees: endAngleDeg),
            innerRadius: innerR,
            outerRadius: outerR
        )

        ZStack {
            // A. Individual Glass Wedge Sheen
            sectorShape
                .fill(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    item.swiftUIColor.opacity(isDark ? 0.52 : 0.42),
                                    item.swiftUIColor.opacity(isDark ? 0.24 : 0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.12))
                )

            // B. Specular Etched Glass Groove Outline
            sectorShape
                .stroke(
                    isSelected
                        ? item.swiftUIColor
                        : (isDark ? Color.white.opacity(0.24) : Color.black.opacity(0.16)),
                    lineWidth: isSelected ? 2.5 : 1.2
                )
                .shadow(
                    color: isSelected ? item.swiftUIColor.opacity(0.9) : Color.clear,
                    radius: isSelected ? 12 : 0
                )

            // C. Icon and Punchy Single-Word Label directly inside wedge (Safe from outer edge!)
            VStack(spacing: 2) {
                Image(systemName: item.icon)
                    .font(.system(size: isSelected ? 21 : 18, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(
                        isSelected
                            ? (isDark ? .white : item.swiftUIColor)
                            : (isDark ? item.swiftUIColor.opacity(0.95) : item.swiftUIColor)
                    )
                    .shadow(
                        color: isSelected ? item.swiftUIColor.opacity(0.85) : Color.clear,
                        radius: 6
                    )

                Text(item.shortTitle)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(
                        isSelected
                            ? (isDark ? .white : .black)
                            : (isDark ? .white.opacity(0.9) : Color.black.opacity(0.85))
                    )
                    .lineLimit(1)
            }
            .position(x: posX, y: posY)
            .scaleEffect(isSelected ? 1.14 : 1.0)
        }
        .offset(x: offsetX, y: offsetY)
        .shadow(
            color: Color.black.opacity(isSelected ? (isDark ? 0.35 : 0.2) : 0),
            radius: isSelected ? 10 : 0,
            x: 0,
            y: isSelected ? 4 : 0
        )
        .zIndex(isSelected ? 20 : 1)
    }

    // MARK: - Center Crystal Glass Hub View
    private var centerHubView: some View {
        let innerR = CGFloat(appearance.innerRadius)
        let selectedItem = hoveredIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }

        return ZStack {
            // Frosted Center Orb with adaptive vibrancy
            VisualEffectBlur(
                material: isDark ? .underWindowBackground : .popover,
                blendingMode: .behindWindow,
                state: .active,
                appearance: NSAppearance(named: isDark ? .vibrantDark : .vibrantLight)
            )
            .clipShape(Circle())
            .frame(width: innerR * 2, height: innerR * 2)
            .opacity(isDark ? 0.78 : 0.88)

            Circle()
                .fill(isDark ? Color.black.opacity(0.22) : Color.white.opacity(0.55))
                .frame(width: innerR * 2, height: innerR * 2)

            // Glossy Specular Bevel Border (Reflects light)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            selectedItem != nil ? selectedItem!.swiftUIColor : (isDark ? Color.white.opacity(0.65) : Color.white.opacity(0.9)),
                            selectedItem != nil ? selectedItem!.swiftUIColor.opacity(0.5) : (isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: selectedItem != nil ? 2.4 : 1.5
                )
                .frame(width: innerR * 2, height: innerR * 2)
                .shadow(
                    color: selectedItem?.swiftUIColor.opacity(0.7) ?? Color.clear,
                    radius: 10
                )

            // Content inside Orb (Strictly bounded so text CANNOT overflow the circle!)
            if let item = selectedItem {
                VStack(spacing: 2) {
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(item.swiftUIColor)
                        .shadow(color: item.swiftUIColor.opacity(0.8), radius: 5)

                    Text(item.title)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(isDark ? .white : .black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(isDark ? .white.opacity(0.7) : Color.black.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .frame(maxWidth: (innerR * 2) - 22)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(isDark ? .white.opacity(0.5) : Color.black.opacity(0.4))

                    Text("Orbit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isDark ? .white.opacity(0.85) : Color.black.opacity(0.8))
                }
                .frame(maxWidth: (innerR * 2) - 22)
                .transition(.opacity)
            }
        }
        .contentShape(Circle())
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
        if distance > CGFloat(appearance.radius + 35) {
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
