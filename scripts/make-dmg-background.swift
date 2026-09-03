import AppKit

// Renders the KeyFlip DMG window background at a given scale factor.
// usage: swift genbg.swift <out.png> <scale>
let out = CommandLine.arguments[1]
let scale = CGFloat(Double(CommandLine.arguments[2]) ?? 1)
let W: CGFloat = 660, H: CGFloat = 400

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let nsctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsctx
let ctx = nsctx.cgContext
ctx.scaleBy(x: scale, y: scale)

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}

// Backdrop: navy -> violet diagonal, echoing the app icon.
let grad = NSGradient(colors: [rgb(16, 20, 62), rgb(38, 21, 82), rgb(62, 26, 104)],
                      atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
grad.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)

// Glow wells marking where the two icons sit.
func glow(cx: CGFloat, cy: CGFloat, r: CGFloat, alpha: CGFloat) {
    let box = NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: box).addClip()
    let g = NSGradient(colors: [rgb(255, 255, 255, alpha), rgb(255, 255, 255, 0)])!
    g.draw(in: box, relativeCenterPosition: .zero)
    NSGraphicsContext.restoreGraphicsState()
}
let iconY = H - 185          // Finder places icon centres 185pt below the window top
glow(cx: 170, cy: iconY, r: 96, alpha: 0.10)
glow(cx: 490, cy: iconY, r: 96, alpha: 0.07)

// Arrow from the app to the Applications folder.
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 279, y: iconY))
arrow.line(to: NSPoint(x: 368, y: iconY))
arrow.lineWidth = 3
arrow.lineCapStyle = .round
rgb(255, 255, 255, 0.55).setStroke()
arrow.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 366, y: iconY + 11))
head.line(to: NSPoint(x: 385, y: iconY))
head.line(to: NSPoint(x: 366, y: iconY - 11))
head.close()
rgb(255, 255, 255, 0.55).setFill()
head.fill()

// Captions.
func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, cx: CGFloat, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    str.draw(at: NSPoint(x: cx - sz.width / 2, y: y))
}
text("Drag KeyFlip into Applications", size: 17, weight: .semibold, color: rgb(255, 255, 255, 0.92), cx: W/2, y: 74)
text("Then launch it from Launchpad or Spotlight — it lives in the menu bar.",
     size: 12, weight: .regular, color: rgb(255, 255, 255, 0.5), cx: W/2, y: 50)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
