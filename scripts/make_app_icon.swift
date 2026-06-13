// Generates the Tertiary HRMS 1024×1024 App Store icon — "Premier Blue" design.
// App Store compliant: opaque, NO alpha channel (CGContext with .noneSkipLast).
// Design: a bold white people mark (SF Symbol "person.2.fill") with a check badge,
// on a deep-navy → premier-blue → azure diagonal gradient.
// Usage:  swift scripts/make_app_icon.swift [outputPath]
import AppKit
import UniformTypeIdentifiers

let px = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon-1024.png"
let S = CGFloat(px)

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let cg = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                         bytesPerRow: 0, space: cs,
                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("could not create CGContext")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
let ctx = cg
let full = NSRect(x: 0, y: 0, width: S, height: S)

// --- Background: Premier Blue diagonal gradient (navy → premier → azure) ---
let navy    = NSColor(srgbRed: 0.039, green: 0.122, blue: 0.267, alpha: 1)  // #0A1F44
let premier = NSColor(srgbRed: 0.114, green: 0.306, blue: 0.847, alpha: 1)  // #1D4ED8
let azure   = NSColor(srgbRed: 0.231, green: 0.510, blue: 0.965, alpha: 1)  // #3B82F6
NSGradient(colors: [navy, premier, azure], atLocations: [0.0, 0.62, 1.0],
           colorSpace: .sRGB)!.draw(in: full, angle: -55)
// Soft radial highlight (upper-left) for depth.
let hi = NSGradient(colors: [NSColor(white: 1, alpha: 0.18), NSColor(white: 1, alpha: 0)])!
hi.draw(in: full, relativeCenterPosition: NSPoint(x: -0.35, y: 0.45))

// --- Subtle concentric "reach" rings behind the mark (lower-right glow) ---
ctx.saveGState()
for (i, r) in [0.52, 0.40, 0.28].enumerated() {
    let rr = S * CGFloat(r)
    let ring = NSBezierPath(ovalIn: NSRect(x: S*0.5 - rr, y: S*0.46 - rr, width: rr*2, height: rr*2))
    ring.lineWidth = S * 0.006
    NSColor(white: 1, alpha: 0.06 + Double(i) * 0.02).setStroke()
    ring.stroke()
}
ctx.restoreGState()

// --- People mark (SF Symbol "person.2.fill"), tinted white, centered ---
func tintedSymbol(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return nil }
    let img = NSImage(size: base.size)
    img.lockFocus()
    base.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    color.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    img.unlockFocus()
    img.isTemplate = false
    return img
}

if let people = tintedSymbol("person.2.fill", pointSize: 560, color: .white) {
    let targetW = S * 0.62
    let scale = targetW / people.size.width
    let h = people.size.height * scale
    let rect = NSRect(x: S*0.5 - targetW/2, y: S*0.42 - h/2, width: targetW, height: h)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 34,
                  color: NSColor(white: 0, alpha: 0.28).cgColor)
    people.draw(in: rect)
    ctx.restoreGState()
}

// --- Check badge (bottom-right) signalling "managed / approved" ---
ctx.saveGState()
let bd = S * 0.20
let bx = S*0.70, by = S*0.16
let badgeRect = NSRect(x: bx, y: by, width: bd, height: bd)
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 24,
              color: NSColor(white: 0, alpha: 0.30).cgColor)
NSColor.white.setFill()
NSBezierPath(ovalIn: badgeRect).fill()
ctx.restoreGState()
if let check = tintedSymbol("checkmark", pointSize: 240, color: premier) {
    let cw = bd * 0.52
    let chScale = cw / check.size.width
    let ch = check.size.height * chScale
    check.draw(in: NSRect(x: bx + (bd - cw)/2, y: by + (bd - ch)/2, width: cw, height: ch))
}

NSGraphicsContext.restoreGraphicsState()

guard let image = cg.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not encode PNG")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out) (\(px)×\(px), no alpha)")
