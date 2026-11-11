import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: swift make-icon.swift <output.iconset>\n", stderr)
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func renderIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }

    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let margin = s * 0.08
    let cardRect = rect.insetBy(dx: margin, dy: margin)
    let corner = s * 0.21
    let squircle = CGPath(roundedRect: cardRect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Clip to macOS squircle
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Deep spatial obsidian gradient background
    let colors = [
        CGColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1.0),
        CGColor(red: 0.03, green: 0.035, blue: 0.06, alpha: 1.0)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    }

    // Subtle cyan + violet ambient glow
    let cyanGlow = [
        CGColor(red: 0.0, green: 0.92, blue: 1.0, alpha: 0.28),
        CGColor(red: 0.0, green: 0.92, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let g1 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cyanGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g1, startCenter: CGPoint(x: s * 0.35, y: s * 0.72), startRadius: 0, endCenter: CGPoint(x: s * 0.35, y: s * 0.72), endRadius: s * 0.55, options: [])
    }

    let magentaGlow = [
        CGColor(red: 0.65, green: 0.22, blue: 1.0, alpha: 0.22),
        CGColor(red: 0.65, green: 0.22, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let g2 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: magentaGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g2, startCenter: CGPoint(x: s * 0.72, y: s * 0.26), startRadius: 0, endCenter: CGPoint(x: s * 0.72, y: s * 0.26), endRadius: s * 0.5, options: [])
    }

    // Stylized minimalist 75% keycaps emblem
    let keyRows: [[(w: CGFloat, accent: Bool)]] = [
        [(1.0, true), (1.0, false), (1.0, false), (1.0, false), (0.85, true)],
        [(1.2, false), (1.0, false), (1.0, false), (1.65, true)],
        [(1.4, false), (2.4, true), (1.05, false)]
    ]
    let totalW = s * 0.62
    let startX = (s - totalW) / 2.0
    let gap = s * 0.022
    let rowH = s * 0.088
    var y = s * 0.57

    for row in keyRows {
        let units = row.reduce(0) { $0 + $1.w }
        let usableW = totalW - gap * CGFloat(row.count - 1)
        var x = startX
        for item in row {
            let w = usableW * (item.w / units)
            let kRect = CGRect(x: x, y: y, width: w, height: rowH)
            let kPath = CGPath(roundedRect: kRect, cornerWidth: s * 0.02, cornerHeight: s * 0.02, transform: nil)
            ctx.addPath(kPath)
            ctx.setFillColor(item.accent
                ? CGColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 0.22)
                : CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08))
            ctx.fillPath()
            ctx.addPath(kPath)
            ctx.setStrokeColor(item.accent
                ? CGColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.85)
                : CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.24))
            ctx.setLineWidth(max(1.0, s * 0.008))
            ctx.strokePath()
            x += w + gap
        }
        y -= (rowH + gap)
    }

    // Crisp "F75" wordmark at bottom
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: s * 0.13, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.85, green: 0.96, blue: 1.0, alpha: 0.95)
    ]
    let label = NSAttributedString(string: "F75", attributes: attrs)
    let textSize = label.size()
    label.draw(at: CGPoint(x: (s - textSize.width) / 2.0, y: s * 0.15))

    ctx.restoreGState()

    // Specular outer rim
    ctx.addPath(squircle)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.24))
    ctx.setLineWidth(max(1.2, s * 0.012))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let specs: [(String, Int)] = [
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

for (filename, px) in specs {
    if let data = renderIcon(size: px) {
        try data.write(to: iconsetURL.appendingPathComponent(filename))
    }
}
