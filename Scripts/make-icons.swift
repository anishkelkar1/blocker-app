import AppKit

// Renders the FocusLock app icon and launch logo as PNGs into an asset catalog.
// A white shield with an indigo lock layered on top, so the lock reads clearly.
// Usage: swift makeicons.swift <path-to-Assets.xcassets>

let assets = CommandLine.arguments[1]
let indigo = NSColor(srgbRed: 0.263, green: 0.220, blue: 0.792, alpha: 1) // matches LaunchBackground

func render(px: Int, _ draw: (CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func symbol(_ name: String, _ color: NSColor, points: CGFloat) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: points, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg)
}

// Draw `image` centered, scaled so its larger side spans `frac` of `side`,
// nudged vertically by `dy` (positive = up, non-flipped coordinates).
func place(_ image: NSImage, in side: CGFloat, frac: CGFloat, dy: CGFloat = 0) {
    let s = image.size
    let scale = min(side * frac / s.width, side * frac / s.height)
    let w = s.width * scale, h = s.height * scale
    image.draw(in: NSRect(x: (side - w) / 2, y: (side - h) / 2 + dy, width: w, height: h))
}

func shieldWithLock(_ side: CGFloat, lockColor: NSColor, drawBackground: Bool) {
    if drawBackground {
        let g = NSGradient(
            starting: NSColor(srgbRed: 0.42, green: 0.36, blue: 0.95, alpha: 1),
            ending: NSColor(srgbRed: 0.15, green: 0.39, blue: 0.92, alpha: 1))!
        g.draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)), angle: -90)
    }
    if let shield = symbol("shield.fill", .white, points: side * 0.62) {
        place(shield, in: side, frac: 0.64)
    }
    if let lock = symbol("lock.fill", lockColor, points: side * 0.26) {
        place(lock, in: side, frac: 0.24, dy: side * 0.03)
    }
}

func write(_ data: Data, _ path: String) {
    try! data.write(to: URL(fileURLWithPath: path))
}

// App icon: gradient background, white shield, indigo lock.
write(render(px: 1024) { shieldWithLock($0, lockColor: indigo, drawBackground: true) },
      "\(assets)/AppIcon.appiconset/icon_1024.png")

// Launch logo: transparent background, white shield, indigo lock (the lock
// blends into the indigo launch background for a cut-out look).
for (px, name) in [(200, "logo.png"), (400, "logo@2x.png"), (600, "logo@3x.png")] {
    write(render(px: px) { shieldWithLock($0, lockColor: indigo, drawBackground: false) },
          "\(assets)/LaunchLogo.imageset/\(name)")
}
print("icons written")
