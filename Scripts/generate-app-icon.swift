#!/usr/bin/env swift
//
// MacRAR app-icon generator.
//
// Draws a Tahoe-style rounded-square icon with an archive-box motif + "RAR"
// wordmark, then exports a master 1024×1024 PNG. The companion shell wrapper
// (`make-app-icon.sh`) downsizes to all required iconset sizes and packages
// into AppIcon.appiconset for Xcode.
//
import Cocoa

let out: String = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/tmp/macrar-icon-1024.png"

let size: CGFloat = 1024

// Tahoe Liquid Glass-ish gradient: warm coral → deep red
let topColor    = NSColor(red: 1.00, green: 0.51, blue: 0.30, alpha: 1.0)
let bottomColor = NSColor(red: 0.85, green: 0.16, blue: 0.10, alpha: 1.0)

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // 1. Rounded-square background with vertical gradient
    let cornerRadius = size * 0.225 // matches macOS 26 Tahoe app icon mask
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()
    let gradient = NSGradient(colors: [topColor, bottomColor])!
    gradient.draw(in: rect, angle: -90)

    // 2. Inner translucent panel (the "archive box face")
    let panelInset = size * 0.18
    let panelRect = NSRect(
        x: panelInset, y: panelInset,
        width: size - 2 * panelInset, height: size - 2 * panelInset
    )
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: size * 0.07, yRadius: size * 0.07)
    NSColor(white: 1.0, alpha: 0.94).setFill()
    panelPath.fill()

    // 3. Subtle inner shadow line at top of panel (depth)
    NSColor(white: 0.0, alpha: 0.08).setStroke()
    panelPath.lineWidth = 2
    panelPath.stroke()

    // 4. Center divider — evokes a zipper / tape
    let divider = NSRect(
        x: panelInset, y: size / 2 - size * 0.012,
        width: size - 2 * panelInset, height: size * 0.024
    )
    let dividerGrad = NSGradient(colors: [
        topColor.withAlphaComponent(0.0),
        bottomColor.withAlphaComponent(0.45),
        topColor.withAlphaComponent(0.0)
    ])!
    dividerGrad.draw(in: divider, angle: 0)

    // 5. "RAR" wordmark
    let text = "RAR" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.26, weight: .black),
        .foregroundColor: bottomColor,
        .kern: -size * 0.005
    ]
    let textSize = text.size(withAttributes: attrs)
    let textOrigin = NSPoint(
        x: (size - textSize.width) / 2,
        y: (size - textSize.height) / 2 - size * 0.01
    )
    text.draw(at: textOrigin, withAttributes: attrs)

    // 6. Top corner glint (Tahoe liquid-glass highlight)
    let glint = NSBezierPath()
    glint.move(to: NSPoint(x: rect.minX + cornerRadius * 0.6, y: rect.maxY))
    glint.curve(
        to: NSPoint(x: rect.maxX - cornerRadius * 0.4, y: rect.maxY - cornerRadius * 0.4),
        controlPoint1: NSPoint(x: rect.midX, y: rect.maxY),
        controlPoint2: NSPoint(x: rect.maxX, y: rect.maxY - cornerRadius * 0.1)
    )
    NSColor(white: 1.0, alpha: 0.18).setStroke()
    glint.lineWidth = size * 0.015
    glint.stroke()

    _ = ctx
    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("ERROR: failed to encode PNG\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: out))
print("✓ Wrote \(png.count) bytes → \(out)")
