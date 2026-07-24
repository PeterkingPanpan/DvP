import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    // Background: white rounded rectangle with subtle border
    NSColor.white.setFill()
    let bgRect = rect.insetBy(dx: 64, dy: 64)
    let path = NSBezierPath(roundedRect: bgRect,
                            xRadius: 180, yRadius: 180)
    path.fill()
    
    // Subtle border
    let borderColor = NSColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 0.6)
    borderColor.setStroke()
    path.lineWidth = 12
    path.stroke()
    
    // Text: "DvP" in medium blue
    let textColor = NSColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 1.0)
    let fontSize: CGFloat = 540
    guard let font = NSFont.systemFont(ofSize: fontSize, weight: .bold) as NSFont? else { return false }
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .kern: -12.0,
    ]
    let text = "DvP" as NSString
    let textSize = text.size(withAttributes: attributes)
    let textRect = NSRect(
        x: (rect.width - textSize.width) / 2,
        y: (rect.height - textSize.height) / 2 - 20,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attributes)
    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR: failed to generate PNG")
    exit(1)
}

let outPath = "/tmp/DvP_1024.png"
try png.write(to: URL(fileURLWithPath: outPath))
print("Written: \(outPath)")
