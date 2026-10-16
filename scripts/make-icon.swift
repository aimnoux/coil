// Renders the Coil app icon (1024×1024 PNG).
// Usage: swift scripts/make-icon.swift Coil/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit
import CoreGraphics

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size = 1024
let s = CGFloat(size)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

enum Variant { case light, dark, tinted }

func render(_ variant: Variant) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Background.
    switch variant {
    case .light:
        let gradient = CGGradient(colorsSpace: space, colors: [color(0x6A5CFF), color(0xB04CE8)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    case .dark:
        let gradient = CGGradient(colorsSpace: space, colors: [color(0x16132E), color(0x231A3D)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    case .tinted:
        ctx.setFillColor(color(0x000000))
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    }

    // An Archimedean spiral growing outwards: each loop of a habit builds on the last.
    let center = CGPoint(x: s / 2, y: s / 2)
    let turns: CGFloat = 2.35
    let startRadius: CGFloat = 36
    let endRadius: CGFloat = 330
    let startAngle: CGFloat = .pi / 2
    let path = CGMutablePath()
    let steps = 600
    var last = CGPoint.zero
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let angle = startAngle - t * turns * 2 * .pi
        let radius = startRadius + (endRadius - startRadius) * t
        let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        last = point
    }

    let stroke: CGColor
    switch variant {
    case .light: stroke = color(0xFFFFFF)
    case .dark: stroke = color(0xB9A8FF)
    case .tinted: stroke = color(0xFFFFFF)
    }

    // Center the spiral's bounding box (including the line width) in the icon.
    let bounds = path.boundingBoxOfPath.insetBy(dx: -37, dy: -37)
    ctx.translateBy(x: s / 2 - bounds.midX, y: s / 2 - bounds.midY)
    ctx.addPath(path)
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(74)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // A dot at the outer end marks today's progress.
    let dotColor: CGColor
    switch variant {
    case .light: dotColor = color(0xFFD84D)
    case .dark: dotColor = color(0xFFD84D)
    case .tinted: dotColor = color(0xFFFFFF, 0.7)
    }
    ctx.setFillColor(dotColor)
    ctx.fillEllipse(in: CGRect(x: last.x - 30, y: last.y - 30, width: 60, height: 60))

    return ctx.makeImage()!
}

func write(_ image: CGImage, to name: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
    try! data.write(to: url)
    print("Wrote \(url.path)")
}

write(render(.light), to: "AppIcon.png")
write(render(.dark), to: "AppIcon-Dark.png")
write(render(.tinted), to: "AppIcon-Tinted.png")
