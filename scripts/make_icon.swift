import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: make_icon.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else {
    fputs("Failed to create CGContext\n", stderr)
    exit(1)
}

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(srgbRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

func fillPoly(_ points: [CGPoint], color: CGColor) {
    guard let first = points.first else { return }
    ctx.beginPath()
    ctx.move(to: first)
    for point in points.dropFirst() {
        ctx.addLine(to: point)
    }
    ctx.closePath()
    ctx.setFillColor(color)
    ctx.fillPath()
}

func drawIsoBox(
    cx: CGFloat,
    cy: CGFloat,
    hw: CGFloat,
    hh: CGFloat,
    h: CGFloat,
    topColor: CGColor,
    leftColor: CGColor,
    rightColor: CGColor
) {
    let top = CGPoint(x: cx, y: cy + hh)
    let right = CGPoint(x: cx + hw, y: cy)
    let bottom = CGPoint(x: cx, y: cy - hh)
    let left = CGPoint(x: cx - hw, y: cy)

    let topUp = CGPoint(x: top.x, y: top.y + h)
    let rightUp = CGPoint(x: right.x, y: right.y + h)
    let bottomUp = CGPoint(x: bottom.x, y: bottom.y + h)
    let leftUp = CGPoint(x: left.x, y: left.y + h)

    fillPoly([left, bottom, bottomUp, leftUp], color: leftColor)
    fillPoly([bottom, right, rightUp, bottomUp], color: rightColor)
    fillPoly([topUp, rightUp, bottomUp, leftUp], color: topColor)
}

func drawPyramidRoof(
    cx: CGFloat,
    cy: CGFloat,
    hw: CGFloat,
    hh: CGFloat,
    peakHeight: CGFloat,
    leftColor: CGColor,
    rightColor: CGColor
) {
    let right = CGPoint(x: cx + hw, y: cy)
    let bottom = CGPoint(x: cx, y: cy - hh)
    let left = CGPoint(x: cx - hw, y: cy)
    let peak = CGPoint(x: cx, y: cy + peakHeight)

    fillPoly([left, bottom, peak], color: leftColor)
    fillPoly([bottom, right, peak], color: rightColor)
}

// 1. Sky gradient (opaque)
let skyColors = [rgba(52, 130, 232), rgba(142, 202, 250), rgba(218, 240, 255)] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: skyColors, locations: [0.0, 0.55, 1.0]) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: 1024),
        end: CGPoint(x: 512, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

// 2. Soft sun disc
ctx.setFillColor(rgba(255, 238, 175, 0.9))
ctx.fillEllipse(in: CGRect(x: 735, y: 745, width: 150, height: 150))

// 3. Isometric grass island base
drawIsoBox(
    cx: 512,
    cy: 255,
    hw: 420,
    hh: 210,
    h: 56,
    topColor: rgba(123, 198, 123),
    leftColor: rgba(118, 92, 66),
    rightColor: rgba(90, 68, 48)
)

// Subtle road cross paths on top of the grass base (center y = 311)
fillPoly([
    CGPoint(x: 512, y: 311 + 195),
    CGPoint(x: 552, y: 311 + 175),
    CGPoint(x: 512, y: 311 - 195),
    CGPoint(x: 472, y: 311 - 175)
], color: rgba(90, 90, 90))
fillPoly([
    CGPoint(x: 512 - 390, y: 311 + 15),
    CGPoint(x: 512 + 390, y: 311 - 15),
    CGPoint(x: 512 + 350, y: 311 - 35),
    CGPoint(x: 512 - 350, y: 311 + 35)
], color: rgba(90, 90, 90))

// 4. Back commercial glass tower
drawIsoBox(
    cx: 390,
    cy: 400,
    hw: 108,
    hh: 54,
    h: 295,
    topColor: rgba(140, 205, 250),
    leftColor: rgba(65, 140, 215),
    rightColor: rgba(45, 108, 175)
)
// Floor stripes on glass tower
for step in stride(from: CGFloat(45), to: 270, by: 48) {
    let baseY = 400 + step
    fillPoly([
        CGPoint(x: 390 - 94, y: baseY),
        CGPoint(x: 390 - 10, y: baseY - 42),
        CGPoint(x: 390 - 10, y: baseY - 26),
        CGPoint(x: 390 - 94, y: baseY + 16)
    ], color: rgba(195, 232, 255, 0.7))
    fillPoly([
        CGPoint(x: 390 + 10, y: baseY - 42),
        CGPoint(x: 390 + 94, y: baseY),
        CGPoint(x: 390 + 94, y: baseY + 16),
        CGPoint(x: 390 + 10, y: baseY - 26)
    ], color: rgba(160, 212, 245, 0.55))
}

// 5. Back-right amber residential/civic tower
drawIsoBox(
    cx: 635,
    cy: 395,
    hw: 100,
    hh: 50,
    h: 215,
    topColor: rgba(246, 206, 120),
    leftColor: rgba(224, 174, 82),
    rightColor: rgba(186, 138, 56)
)

// 6. Front-left red-roofed house
drawIsoBox(
    cx: 410,
    cy: 265,
    hw: 94,
    hh: 47,
    h: 120,
    topColor: rgba(250, 242, 224),
    leftColor: rgba(235, 222, 198),
    rightColor: rgba(205, 190, 165)
)
drawPyramidRoof(
    cx: 410,
    cy: 265 + 120,
    hw: 102,
    hh: 51,
    peakHeight: 74,
    leftColor: rgba(220, 86, 68),
    rightColor: rgba(178, 60, 46)
)

// 7. Front-right park trees
let treeCenters: [(CGFloat, CGFloat, CGFloat)] = [
    (615, 295, 44),
    (680, 260, 38),
    (565, 245, 34)
]
for (tx, ty, radius) in treeCenters {
    ctx.setFillColor(rgba(110, 74, 46))
    ctx.fill(CGRect(x: tx - 8, y: ty, width: 16, height: 34))
    ctx.setFillColor(rgba(46, 125, 50))
    ctx.fillEllipse(in: CGRect(x: tx - radius, y: ty + 20, width: radius * 2, height: radius * 1.9))
    ctx.setFillColor(rgba(76, 160, 78))
    ctx.fillEllipse(in: CGRect(x: tx - radius * 0.72, y: ty + 32, width: radius * 1.4, height: radius * 1.3))
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
          outputURL as CFURL,
          UTType.png.identifier as CFString,
          1,
          nil
      ) else {
    fputs("Failed to create PNG destination\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    fputs("Failed to write PNG\n", stderr)
    exit(1)
}
