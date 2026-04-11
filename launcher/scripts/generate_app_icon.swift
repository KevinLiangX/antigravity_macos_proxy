import Cocoa
import Foundation

let size: CGFloat = 1024
let canvasRect = NSRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: canvasRect.size)

image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("Failed to get CGContext")
    exit(1)
}

// Outer shadow
ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 30, color: NSColor.black.withAlphaComponent(0.4).cgColor)

// macOS squircle math
let padding: CGFloat = 104
let rect = NSRect(x: padding, y: padding, width: size - padding * 2, height: size - padding * 2)
let radius = rect.width * 0.225

let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
path.addClip()

// Clear shadow inside the clip
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Draw beautiful gradient
guard let gradient = NSGradient(
    starting: NSColor(red: 0.16, green: 0.08, blue: 0.40, alpha: 1.0),
    ending: NSColor(red: 0.65, green: 0.20, blue: 0.85, alpha: 1.0)
) else { exit(1) }

gradient.draw(in: rect, angle: 45)

// Draw inner highlight (glass effect)
let innerPath = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: radius, yRadius: radius)
innerPath.lineWidth = 4
NSColor(white: 1.0, alpha: 0.4).setStroke()
innerPath.stroke()

// Draw symbol
let symbolName = "bolt.shield.fill" // "sparkles" or "paperplane.fill"
let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .bold)
if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    ctx.setShadow(offset: CGSize(width: 0, height: -15), blur: 20, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    
    let template = symbol
    template.isTemplate = true
    NSColor.white.set()
    let symbolRect = NSRect(
        x: (size - template.size.width) / 2,
        y: (size - template.size.height) / 2,
        width: template.size.width,
        height: template.size.height
    )
    template.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

// Export
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to render PNG")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon_1024.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Icon generated at: \(outputPath)")
