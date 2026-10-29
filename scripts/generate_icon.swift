import AppKit
import CoreGraphics
import Foundation

// MARK: - Orbit Icon Generator
// Creates an ultra-premium macOS squircle app icon for Orbit.

func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
    return degrees * .pi / 180.0
}

func createOrbitIcon(size: CGFloat = 1024) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let scale = size / 1024.0

    // 1. Squircle bounds (macOS standard HIG: 824x824 on 1024x1024 canvas)
    let margin: CGFloat = 100 * scale
    let squircleSize: CGFloat = 824 * scale
    let cornerRadius: CGFloat = 185 * scale
    let squircleRect = CGRect(x: margin, y: margin, width: squircleSize, height: squircleSize)

    // 2. Shadows under the squircle
    ctx.saveGState()
    let shadowPath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Deep ambient shadow
    ctx.setShadow(offset: CGSize(width: 0, height: -28 * scale), blur: 44 * scale, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    ctx.addPath(shadowPath)
    ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Contact shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 16 * scale, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(shadowPath)
    ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // 3. Clip to Squircle for interior artwork
    ctx.saveGState()
    ctx.addPath(shadowPath)
    ctx.clip()

    // 4. Background Gradient (Deep cosmic slate-navy)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.13, green: 0.14, blue: 0.20, alpha: 1.0), // Top: #212433
        CGColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1.0), // Mid: #12121F
        CGColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1.0)  // Bottom: #0A0A12
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient,
                               start: CGPoint(x: 512 * scale, y: (1024 - 100) * scale),
                               end: CGPoint(x: 512 * scale, y: 100 * scale),
                               options: [])
    }

    // 5. Ambient Nebula Glow (Center radial lighting)
    let nebulaColors = [
        CGColor(red: 0.39, green: 0.25, blue: 0.95, alpha: 0.30), // Purple-violet #6340F2
        CGColor(red: 0.14, green: 0.55, blue: 0.95, alpha: 0.18), // Electric cyan #248CF2
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    let nebulaLocations: [CGFloat] = [0.0, 0.45, 1.0]
    if let nebulaGradient = CGGradient(colorsSpace: colorSpace, colors: nebulaColors, locations: nebulaLocations) {
        ctx.drawRadialGradient(nebulaGradient,
                               startCenter: CGPoint(x: 512 * scale, y: 530 * scale),
                               startRadius: 0,
                               endCenter: CGPoint(x: 512 * scale, y: 530 * scale),
                               endRadius: 420 * scale,
                               options: [])
    }

    let center = CGPoint(x: 512 * scale, y: 512 * scale)

    // 6. Outer Spoke Ticks & Radial Grid (representing 8 sectors)
    let outerTrackRadius: CGFloat = 265 * scale
    let tickInnerRadius: CGFloat = 245 * scale
    let tickOuterRadius: CGFloat = 285 * scale

    // Outer faint track circle
    ctx.setStrokeColor(CGColor(red: 0.5, green: 0.6, blue: 0.9, alpha: 0.15))
    ctx.setLineWidth(1.5 * scale)
    ctx.strokeEllipse(in: CGRect(x: center.x - outerTrackRadius, y: center.y - outerTrackRadius, width: outerTrackRadius * 2, height: outerTrackRadius * 2))

    // 8 Spoke Divider Rays
    for i in 0..<8 {
        let angle = degreesToRadians(CGFloat(i) * 45.0)
        let p1 = CGPoint(x: center.x + cos(angle) * tickInnerRadius, y: center.y + sin(angle) * tickInnerRadius)
        let p2 = CGPoint(x: center.x + cos(angle) * tickOuterRadius, y: center.y + sin(angle) * tickOuterRadius)
        
        ctx.setStrokeColor(CGColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 0.25))
        ctx.setLineWidth(1.5 * scale)
        ctx.strokeLineSegments(between: [p1, p2])
    }

    // 7. Middle Orbital Ring (Glowing Neon Track)
    let orbitRadius: CGFloat = 205 * scale
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 16 * scale, color: CGColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 0.55))
    ctx.setStrokeColor(CGColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 0.5))
    ctx.setLineWidth(2.5 * scale)
    ctx.strokeEllipse(in: CGRect(x: center.x - orbitRadius, y: center.y - orbitRadius, width: orbitRadius * 2, height: orbitRadius * 2))
    ctx.restoreGState()

    // 8. 8 Glowing Jewel Planetary Nodes on the Orbit Track
    // Mirroring the Orbit radial menu:
    // 0: Green (Terminal), 1: Violet (Clips), 2: Cyan (Web), 3: Orange (OCR)
    // 4: Rose (Media), 5: Purple (Color), 6: Gold (Paste), 7: Red (Lock)
    let nodeColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (0.13, 0.85, 0.45), // Green
        (0.68, 0.35, 0.98), // Violet
        (0.05, 0.75, 0.95), // Cyan
        (0.98, 0.50, 0.15), // Orange
        (0.96, 0.25, 0.45), // Rose
        (0.55, 0.35, 0.96), // Purple
        (0.95, 0.75, 0.10), // Gold
        (0.94, 0.30, 0.30)  // Coral Red
    ]

    for (i, col) in nodeColors.enumerated() {
        // Angles: start at top (90 deg in standard cartesian, step by -45 clockwise)
        let angleDeg: CGFloat = 90.0 - CGFloat(i) * 45.0
        let angle = degreesToRadians(angleDeg)
        let nx = center.x + cos(angle) * orbitRadius
        let ny = center.y + sin(angle) * orbitRadius
        let nodeCenter = CGPoint(x: nx, y: ny)

        // Outer soft halo
        ctx.saveGState()
        let haloRadius: CGFloat = 20 * scale
        ctx.setShadow(offset: .zero, blur: 18 * scale, color: CGColor(red: col.r, green: col.g, blue: col.b, alpha: 0.85))
        ctx.setFillColor(CGColor(red: col.r, green: col.g, blue: col.b, alpha: 0.4))
        ctx.fillEllipse(in: CGRect(x: nodeCenter.x - haloRadius, y: nodeCenter.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2))
        ctx.restoreGState()

        // Vibrant node bead
        let beadRadius: CGFloat = 11 * scale
        ctx.setFillColor(CGColor(red: col.r, green: col.g, blue: col.b, alpha: 0.95))
        ctx.fillEllipse(in: CGRect(x: nodeCenter.x - beadRadius, y: nodeCenter.y - beadRadius, width: beadRadius * 2, height: beadRadius * 2))

        // Center specular highlight point
        let coreRadius: CGFloat = 4 * scale
        ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
        ctx.fillEllipse(in: CGRect(x: nodeCenter.x - coreRadius, y: nodeCenter.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2))
    }

    // 9. Center Orb (Liquid Glass Core)
    let hubRadius: CGFloat = 115 * scale

    // Outer glow for hub
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 28 * scale, color: CGColor(red: 0.45, green: 0.30, blue: 0.95, alpha: 0.6))
    ctx.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 0.92))
    ctx.fillEllipse(in: CGRect(x: center.x - hubRadius, y: center.y - hubRadius, width: hubRadius * 2, height: hubRadius * 2))
    ctx.restoreGState()

    // Hub gradient fill (glass body)
    let hubColors = [
        CGColor(red: 0.22, green: 0.24, blue: 0.36, alpha: 0.95), // Top
        CGColor(red: 0.11, green: 0.12, blue: 0.18, alpha: 0.98), // Mid
        CGColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)   // Bottom
    ] as CFArray
    if let hubGradient = CGGradient(colorsSpace: colorSpace, colors: hubColors, locations: [0.0, 0.6, 1.0]) {
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: center.x - hubRadius, y: center.y - hubRadius, width: hubRadius * 2, height: hubRadius * 2))
        ctx.clip()
        ctx.drawLinearGradient(hubGradient,
                               start: CGPoint(x: center.x, y: center.y + hubRadius),
                               end: CGPoint(x: center.x, y: center.y - hubRadius),
                               options: [])
        ctx.restoreGState()
    }

    // Hub glass rim bevel stroke
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 0.45))
    ctx.setLineWidth(2.5 * scale)
    ctx.strokeEllipse(in: CGRect(x: center.x - hubRadius, y: center.y - hubRadius, width: hubRadius * 2, height: hubRadius * 2))
    ctx.restoreGState()

    // 10. Center Emblem: Futuristic Concentric Orbital Rings & Singularity Core
    // Inner vibrant ring
    let innerEmblemRadius: CGFloat = 52 * scale
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 14 * scale, color: CGColor(red: 0.30, green: 0.80, blue: 1.0, alpha: 0.8))
    ctx.setStrokeColor(CGColor(red: 0.40, green: 0.85, blue: 1.0, alpha: 0.95))
    ctx.setLineWidth(4.0 * scale)
    ctx.strokeEllipse(in: CGRect(x: center.x - innerEmblemRadius, y: center.y - innerEmblemRadius, width: innerEmblemRadius * 2, height: innerEmblemRadius * 2))
    ctx.restoreGState()

    // Tilted elliptical planetary orbit across the core
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: degreesToRadians(-25.0))
    ctx.scaleBy(x: 1.0, y: 0.42)
    ctx.setShadow(offset: .zero, blur: 10 * scale, color: CGColor(red: 0.95, green: 0.35, blue: 0.85, alpha: 0.8))
    ctx.setStrokeColor(CGColor(red: 0.96, green: 0.45, blue: 0.90, alpha: 0.90))
    ctx.setLineWidth(3.0 * scale)
    ctx.strokeEllipse(in: CGRect(x: -72 * scale, y: -72 * scale, width: 144 * scale, height: 144 * scale))
    ctx.restoreGState()

    // Glowing Star / Singularity Core
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 20 * scale, color: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    let coreDotRadius: CGFloat = 16 * scale
    ctx.fillEllipse(in: CGRect(x: center.x - coreDotRadius, y: center.y - coreDotRadius, width: coreDotRadius * 2, height: coreDotRadius * 2))
    ctx.restoreGState()

    // 11. Glass Surface Sheen (Upper Diagonal Specular Reflection)
    ctx.saveGState()
    let sheenPath = CGMutablePath()
    sheenPath.move(to: CGPoint(x: squircleRect.minX, y: squircleRect.maxY - 120 * scale))
    sheenPath.addCurve(to: CGPoint(x: squircleRect.maxX, y: center.y + 70 * scale),
                       control1: CGPoint(x: center.x - 80 * scale, y: squircleRect.maxY - 40 * scale),
                       control2: CGPoint(x: center.x + 120 * scale, y: center.y + 160 * scale))
    sheenPath.addLine(to: CGPoint(x: squircleRect.maxX, y: squircleRect.maxY))
    sheenPath.addLine(to: CGPoint(x: squircleRect.minX, y: squircleRect.maxY))
    sheenPath.closeSubpath()

    let sheenColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0]) {
        ctx.addPath(sheenPath)
        ctx.clip()
        ctx.drawLinearGradient(sheenGrad,
                               start: CGPoint(x: 512 * scale, y: squircleRect.maxY),
                               end: CGPoint(x: 512 * scale, y: center.y),
                               options: [])
    }
    ctx.restoreGState()

    // 12. Outer Squircle Inner Rim Highlight (Top specular rim)
    ctx.saveGState()
    let rimColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.02)
    ] as CFArray
    if let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.4, 1.0]) {
        ctx.addPath(shadowPath)
        ctx.setLineWidth(2.0 * scale)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(rimGrad,
                               start: CGPoint(x: 512 * scale, y: squircleRect.maxY),
                               end: CGPoint(x: 512 * scale, y: squircleRect.minY),
                               options: [])
    }
    ctx.restoreGState()

    // Close interior clip
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - Save PNG & Generate .iconset

func saveImageToPNG(image: NSImage, path: String, pixelSize: Int) -> Bool {
    guard image.tiffRepresentation != nil else { return false }
    
    // Scale representation to exact pixel dimensions
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: pixelSize,
                               pixelsHigh: pixelSize,
                               bitsPerSample: 8,
                               samplesPerPixel: 4,
                               hasAlpha: true,
                               isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0,
                               bitsPerPixel: 0)
    
    NSGraphicsContext.saveGraphicsState()
    if let rep = rep {
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        context?.cgContext.interpolationQuality = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
                   from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
                   operation: .copy,
                   fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? pngData.write(to: URL(fileURLWithPath: path))) != nil
    }
    NSGraphicsContext.restoreGraphicsState()
    return false
}

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let iconsetDir = "\(currentDir)/AppIcon.iconset"
let outputPath = "\(currentDir)/AppIcon.icns"

print("==> Generating 1024x1024 master icon image...")
let masterImage = createOrbitIcon(size: 1024)

// Clean and create iconset directory
try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// Required macOS icon sizes:
let iconSpecs: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

print("==> Rendering iconset mipmaps...")
for spec in iconSpecs {
    let targetFile = "\(iconsetDir)/\(spec.name)"
    let success = saveImageToPNG(image: masterImage, path: targetFile, pixelSize: spec.size)
    if !success {
        print("Failed to write \(spec.name)")
        exit(1)
    }
}

// Save master preview PNG as well
let previewPath = "\(currentDir)/AppIcon_1024.png"
_ = saveImageToPNG(image: masterImage, path: previewPath, pixelSize: 1024)
print("==> Saved master preview to: \(previewPath)")

print("==> Compiling to \(outputPath) with iconutil...")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", outputPath]
try? task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("==> Successfully generated \(outputPath)!")
    // Cleanup temporary iconset directory
    try? fileManager.removeItem(atPath: iconsetDir)
} else {
    print("iconutil failed with code \(task.terminationStatus)")
    exit(1)
}
