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
            // MARK: - 1. High-Transparency Smoked Glass Backing
            let discDiameter = CGFloat(appearance.radius * 2 + 10)

            ZStack {
                // Real macOS blur with Vibrant Dark appearance (prevents milky white in Light Mode!)
                // Opacity at 0.65 allows background text & windows to clearly show through
                VisualEffectBlur(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    state: .active,
                    appearance: NSAppearance(named: .vibrantDark)
                )
                .clipShape(Circle())
                .opacity(0.65)

                // Very light smoked glass tint for contrast
                Circle()
                    .fill(Color.black.opacity(0.18))

                // Outer Glass Specular Bevel Border
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .frame(width: discDiameter, height: discDiameter)
            // Soft native macOS drop shadow
            .shadow(color: Color.black.opacity(0.38), radius: 28, x: 0, y: 14)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)

            // MARK: - 2. Triangular Pie Slices with Defined Outlines
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                sliceWedgeView(index: index, item: item)
            }

            // MARK: - 3. Center Glass Hub (Orb)
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

    // MARK: - Triangular / Annular Wedge Slice View
    @ViewBuilder
    private func sliceWedgeView(index: Int, item: RadialItem) -> some View {
        let isSelected = hoveredIndex == index
        let count = max(items.count, 1)
        let step = 360.0 / Double(count)
        let midAngleDeg = -90.0 + (Double(index) * step)
        let gapDeg = 2.0
        let startAngleDeg = midAngleDeg - (step / 2.0) + (gapDeg / 2.0)
        let endAngleDeg = midAngleDeg + (step / 2.0) - (gapDeg / 2.0)

        let innerR = CGFloat(appearance.innerRadius)
        let outerR = isSelected ? CGFloat(appearance.radius + 5) : CGFloat(appearance.radius)

        // Centroid position for the icon and label
        let rad = midAngleDeg * .pi / 180.0
        let midR = (innerR + CGFloat(appearance.radius)) / 2.0 + (isSelected ? 3 : 0)
        let posX = center.x + CGFloat(cos(rad)) * midR
        let posY = center.y + CGFloat(sin(rad)) * midR

        ZStack {
            // Triangular / Annular Sector Shape
            AnnularSector(
                startAngle: Angle(degrees: startAngleDeg),
                endAngle: Angle(degrees: endAngleDeg),
                innerRadius: innerR + 1,
                outerRadius: outerR
            )
            .fill(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                item.swiftUIColor.opacity(0.42),
                                item.swiftUIColor.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(Color.white.opacity(0.04))
            )
            // Triangular Outline on EACH sector (clearly visible!)
            .overlay(
                AnnularSector(
                    startAngle: Angle(degrees: startAngleDeg),
                    endAngle: Angle(degrees: endAngleDeg),
                    innerRadius: innerR + 1,
                    outerRadius: outerR
                )
                .stroke(
                    isSelected
                        ? item.swiftUIColor
                        : Color.white.opacity(0.24),
                    lineWidth: isSelected ? 2.5 : 1.2
                )
                .shadow(
                    color: isSelected ? item.swiftUIColor.opacity(0.85) : Color.clear,
                    radius: isSelected ? 10 : 0
                )
            )

            // Icon and Label directly inside wedge (NO rounded rectangles / squares!)
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: isSelected ? 22 : 18, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? .white : item.swiftUIColor.opacity(0.95))
                    .shadow(color: isSelected ? item.swiftUIColor.opacity(0.9) : Color.clear, radius: 8)

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                    .lineLimit(1)
            }
            .position(x: posX, y: posY)
            .scaleEffect(isSelected ? 1.14 : 1.0)
        }
    }

    // MARK: - Center Glass Hub View
    private var centerHubView: some View {
        let innerR = CGFloat(appearance.innerRadius)
        let selectedItem = hoveredIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }

        return ZStack {
            // Frosted Center Orb with matching vibrant dark glass
            VisualEffectBlur(
                material: .underWindowBackground,
                blendingMode: .behindWindow,
                state: .active,
                appearance: NSAppearance(named: .vibrantDark)
            )
            .clipShape(Circle())
            .frame(width: innerR * 2, height: innerR * 2)
            .opacity(0.7)

            Circle()
                .fill(Color.black.opacity(0.2))
                .frame(width: innerR * 2, height: innerR * 2)

            // Center Specular Bevel Border
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            selectedItem != nil ? selectedItem!.swiftUIColor : Color.white.opacity(0.45),
                            selectedItem != nil ? selectedItem!.swiftUIColor.opacity(0.4) : Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: selectedItem != nil ? 2.2 : 1.2
                )
                .frame(width: innerR * 2, height: innerR * 2)
                .shadow(
                    color: selectedItem?.swiftUIColor.opacity(0.6) ?? Color.clear,
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
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 17, weight: .light))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Orbit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
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
