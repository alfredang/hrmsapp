// Frames a raw device screenshot on the Premier Blue gradient with a caption,
// output sized for App Store iPhone 6.9" (1320×2868). No alpha.
// Usage: swift scripts/frame_screenshot.swift <input.png> <output.png> "Caption text"
import AppKit
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 4 else { fatalError("usage: in out caption") }
let inPath = args[1], outPath = args[2], caption = args[3]

let W = 1320, H = 2868
let S = CGFloat(W), HH = CGFloat(H)

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let cg = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                   space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

// Premier Blue background gradient (navy → premier → azure).
let navy    = NSColor(srgbRed: 0.039, green: 0.122, blue: 0.267, alpha: 1)
let premier = NSColor(srgbRed: 0.114, green: 0.306, blue: 0.847, alpha: 1)
let azure   = NSColor(srgbRed: 0.231, green: 0.510, blue: 0.965, alpha: 1)
NSGradient(colors: [navy, premier, azure], atLocations: [0.0, 0.65, 1.0], colorSpace: .sRGB)!
    .draw(in: NSRect(x: 0, y: 0, width: S, height: HH), angle: -90)

// Caption near the top.
let para = NSMutableParagraphStyle(); para.alignment = .center
let capAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 92, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para
]
let capRect = NSRect(x: 80, y: HH - 380, width: S - 160, height: 280)
(caption as NSString).draw(in: capRect, withAttributes: capAttrs)

// Device screenshot: scale to width, place below the caption with rounded corners + shadow.
guard let shot = NSImage(contentsOfFile: inPath) else { fatalError("cannot read \(inPath)") }
let targetW = S * 0.80
let scale = targetW / shot.size.width
let targetH = shot.size.height * scale
let x = (S - targetW) / 2
let y = HH - 460 - targetH   // below caption
let frame = NSRect(x: x, y: y, width: targetW, height: targetH)

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -24), blur: 60,
             color: NSColor(white: 0, alpha: 0.45).cgColor)
let clip = NSBezierPath(roundedRect: frame, xRadius: 56, yRadius: 56)
clip.addClip()
shot.draw(in: frame)
cg.restoreGState()

NSGraphicsContext.restoreGraphicsState()
let img = cg.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                           UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("framed \(outPath)")
