#!/usr/bin/env swift
// Vẽ icon MacKey68 bằng AppKit (không cần Xcode, không cần file ảnh nguồn).
// Chạy: swift scripts/make-icon.swift
import AppKit

let pixel = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixel, pixelsHigh: pixel,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("không tạo được bitmap\n".utf8))
    exit(1)
}
rep.size = NSSize(width: pixel, height: pixel)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
ctx.setShouldAntialias(true)
ctx.setAllowsAntialiasing(true)

let side = CGFloat(pixel)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill()

// Nền trong suốt, chỉ vẽ viên thuốc bo góc như icon macOS.
let margin: CGFloat = 86
let body = NSRect(x: margin, y: margin, width: side - margin * 2, height: side - margin * 2)
let radius = body.width * 0.225
let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor.black.setFill()
shape.fill()
NSShadow().set()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Indigo → teal, giống tông của app.
let bg = NSGradient(colorsAndLocations:
    (NSColor(srgbRed: 0.29, green: 0.32, blue: 0.56, alpha: 1), 0.00),
    (NSColor(srgbRed: 0.15, green: 0.18, blue: 0.38, alpha: 1), 0.52),
    (NSColor(srgbRed: 0.05, green: 0.27, blue: 0.29, alpha: 1), 1.00)
)!
bg.draw(in: shape, angle: -62)

// Viền sáng mảnh trên đỉnh để icon có độ nổi.
NSGraphicsContext.saveGraphicsState()
shape.addClip()
let gloss = NSGradient(colorsAndLocations:
    (NSColor.white.withAlphaComponent(0.16), 0.00),
    (NSColor.white.withAlphaComponent(0.0), 0.55)
)!
gloss.draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

NSColor.white.withAlphaComponent(0.18).setStroke()
shape.lineWidth = 2
shape.stroke()

// Bàn phím 4 hàng, phím bo góc, hàng dưới có spacebar.
let kbWidth: CGFloat = 620
let kbX = (side - kbWidth) / 2
let keyHeight: CGFloat = 46
let gap: CGFloat = 11
let rowsBottomUp: [[CGFloat]] = [
    [1.5, 1.5, 1.5, 5.0, 1.5, 1.5],             // hàng dưới
    [1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25], // home row (caps ở đầu)
    [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.5],   // hàng trên
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],       // hàng số
]

func keyPath(_ rect: NSRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
}

let keyboardHeight = CGFloat(rowsBottomUp.count) * keyHeight + CGFloat(rowsBottomUp.count - 1) * gap
var rowY = (side - keyboardHeight) / 2 - 6

for (rowIndex, units) in rowsBottomUp.enumerated() {
    let totalUnits = units.reduce(0, +)
    let unit = (kbWidth - gap * CGFloat(units.count - 1)) / totalUnits
    var x = kbX
    for (keyIndex, width) in units.enumerated() {
        let w = unit * width
        let rect = NSRect(x: x, y: rowY, width: w, height: keyHeight)
        let path = keyPath(rect)

        let isBacktick = rowIndex == 1 && keyIndex == 0
        if isBacktick {
            let amber = NSGradient(colorsAndLocations:
                (NSColor(srgbRed: 1.00, green: 0.82, blue: 0.42, alpha: 1), 0.0),
                (NSColor(srgbRed: 0.96, green: 0.58, blue: 0.13, alpha: 1), 1.0)
            )!
            amber.draw(in: path, angle: -90)
            NSColor.white.withAlphaComponent(0.65).setStroke()
            path.lineWidth = 2
            path.stroke()

            // Dấu ` vẽ tay cho rõ ở kích thước nhỏ.
            let mark = NSBezierPath()
            mark.move(to: NSPoint(x: rect.midX - 7, y: rect.midY + 10))
            mark.line(to: NSPoint(x: rect.midX + 6, y: rect.midY - 7))
            mark.lineWidth = 7
            mark.lineCapStyle = .round
            NSColor(srgbRed: 0.22, green: 0.13, blue: 0.02, alpha: 1).setStroke()
            mark.stroke()
        } else {
            NSColor.white.withAlphaComponent(0.10).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.62).setStroke()
            path.lineWidth = 2.4
            path.stroke()
        }
        x += w + gap
    }
    rowY += keyHeight + gap
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("không xuất được PNG\n".utf8))
    exit(1)
}
let out = URL(fileURLWithPath: "Assets/AppIcon-1024.png")
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try png.write(to: out)
print("→ \(out.path)")
