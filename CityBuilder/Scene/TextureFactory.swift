import CityCore
import SpriteKit
import UIKit

/// Procedurally generates and caches isometric `SKTexture` assets using `UIGraphicsImageRenderer`.
@MainActor
final class TextureFactory {
    private struct GroundKey: Hashable {
        let kind: TileKind
        let variant: UInt8
        let roadMask: UInt8
    }

    private struct StructureKey: Hashable {
        let kind: TileKind
        let level: UInt8
        let variant: UInt8
    }

    private var groundCache: [GroundKey: SKTexture] = [:]
    private var structureCache: [StructureKey: SKTexture] = [:]
    private var highlightCache: [Bool: SKTexture] = [:]
    private var unpoweredIconCache: SKTexture?

    private let tileW = SceneIsoMath.tileWidth
    private let tileH = SceneIsoMath.tileHeight
    private let halfW = SceneIsoMath.halfWidth
    private let halfH = SceneIsoMath.halfHeight

    // MARK: - Public API

    func groundTexture(for tile: Tile, roadMask: UInt8) -> SKTexture {
        let effectiveKind: TileKind
        let effectiveMask: UInt8
        let effectiveVariant: UInt8

        switch tile.kind {
        case .grass, .water, .forest:
            effectiveKind = tile.kind
            effectiveMask = 0
            effectiveVariant = tile.variant % 4
        case .road:
            effectiveKind = .road
            effectiveMask = roadMask & 0x0F
            effectiveVariant = 0
        case .residential, .commercial, .industrial:
            if tile.level == 0 {
                effectiveKind = tile.kind
                effectiveMask = 0
                effectiveVariant = 0
            } else {
                effectiveKind = .grass
                effectiveMask = 0
                effectiveVariant = tile.variant % 4
            }
        case .park, .powerPlant, .school, .hospital:
            effectiveKind = .grass
            effectiveMask = 0
            effectiveVariant = tile.variant % 4
        }

        let key = GroundKey(kind: effectiveKind, variant: effectiveVariant, roadMask: effectiveMask)
        if let cached = groundCache[key] {
            return cached
        }

        let texture = renderGroundTexture(kind: effectiveKind, variant: effectiveVariant, roadMask: effectiveMask)
        groundCache[key] = texture
        return texture
    }

    func structureTexture(for tile: Tile) -> SKTexture? {
        switch tile.kind {
        case .grass, .water, .road:
            return nil
        case .residential, .commercial, .industrial:
            guard tile.level > 0 else { return nil }
            let clampedLevel = min(tile.level, 3)
            let key = StructureKey(kind: tile.kind, level: clampedLevel, variant: tile.variant % 3)
            if let cached = structureCache[key] { return cached }
            let texture = renderStructureTexture(kind: tile.kind, level: clampedLevel, variant: tile.variant % 3)
            structureCache[key] = texture
            return texture
        case .forest, .park, .powerPlant, .school, .hospital:
            let v = tile.variant % 4
            let key = StructureKey(kind: tile.kind, level: 1, variant: v)
            if let cached = structureCache[key] { return cached }
            let texture = renderStructureTexture(kind: tile.kind, level: 1, variant: v)
            structureCache[key] = texture
            return texture
        }
    }

    func highlightTexture(valid: Bool) -> SKTexture {
        if let cached = highlightCache[valid] {
            return cached
        }
        let image = renderImage(size: CGSize(width: tileW, height: tileH)) { cg in
            let fill = valid
                ? rgba(255, 255, 255, 0.22)
                : rgba(239, 68, 68, 0.30)
            let stroke = valid
                ? rgba(255, 255, 255, 0.95)
                : rgba(239, 68, 68, 0.95)

            self.diamondPath(in: cg, cx: self.halfW, cy: self.halfH, hw: self.halfW - 1.5, hh: self.halfH - 0.75)
            cg.setFillColor(fill.cgColor)
            cg.fillPath()

            self.diamondPath(in: cg, cx: self.halfW, cy: self.halfH, hw: self.halfW - 1.5, hh: self.halfH - 0.75)
            cg.setStrokeColor(stroke.cgColor)
            cg.setLineWidth(2.0)
            cg.strokePath()
        }
        let texture = makeTexture(from: image)
        highlightCache[valid] = texture
        return texture
    }

    func unpoweredIconTexture() -> SKTexture {
        if let cached = unpoweredIconCache {
            return cached
        }
        let size = CGSize(width: 22, height: 22)
        let image = renderImage(size: size) { cg in
            cg.setFillColor(rgba(25, 28, 34, 0.85).cgColor)
            cg.fillEllipse(in: CGRect(x: 2, y: 2, width: 18, height: 18))
            cg.setStrokeColor(rgba(250, 204, 21, 0.95).cgColor)
            cg.setLineWidth(1.5)
            cg.strokeEllipse(in: CGRect(x: 2, y: 2, width: 18, height: 18))

            // Lightning bolt polygon in center
            let bolt: [CGPoint] = [
                CGPoint(x: 12.2, y: 4.5),
                CGPoint(x: 7.2, y: 11.5),
                CGPoint(x: 10.6, y: 11.5),
                CGPoint(x: 9.6, y: 17.5),
                CGPoint(x: 14.8, y: 10.3),
                CGPoint(x: 11.3, y: 10.3)
            ]
            self.fillPolygon(bolt, in: cg, color: rgba(250, 204, 21))
        }
        let texture = makeTexture(from: image)
        unpoweredIconCache = texture
        return texture
    }

    // MARK: - Ground Rendering (64x32)

    private func renderGroundTexture(kind: TileKind, variant: UInt8, roadMask: UInt8) -> SKTexture {
        let image = renderImage(size: CGSize(width: tileW, height: tileH)) { cg in
            let cx = self.halfW
            let cy = self.halfH

            switch kind {
            case .grass:
                self.drawGrassDiamond(in: cg, cx: cx, cy: cy, variant: variant, dark: false)
            case .forest:
                self.drawGrassDiamond(in: cg, cx: cx, cy: cy, variant: variant, dark: true)
            case .water:
                self.drawWaterDiamond(in: cg, cx: cx, cy: cy, variant: variant)
            case .road:
                self.drawGrassDiamond(in: cg, cx: cx, cy: cy, variant: 0, dark: false)
                self.drawRoad(in: cg, cx: cx, cy: cy, mask: roadMask)
            case .residential:
                self.drawZoneL0(in: cg, cx: cx, cy: cy, fill: rgba(145, 224, 145), border: rgba(46, 155, 68))
            case .commercial:
                self.drawZoneL0(in: cg, cx: cx, cy: cy, fill: rgba(140, 198, 245), border: rgba(37, 99, 235))
            case .industrial:
                self.drawZoneL0(in: cg, cx: cx, cy: cy, fill: rgba(246, 214, 128), border: rgba(202, 138, 4))
            default:
                self.drawGrassDiamond(in: cg, cx: cx, cy: cy, variant: variant, dark: false)
            }
        }
        return makeTexture(from: image)
    }

    private func drawGrassDiamond(in cg: CGContext, cx: CGFloat, cy: CGFloat, variant: UInt8, dark: Bool) {
        let baseColors: [UIColor] = dark
            ? [rgba(93, 174, 93), rgba(88, 168, 88), rgba(98, 178, 96), rgba(90, 170, 92)]
            : [rgba(123, 198, 123), rgba(119, 194, 119), rgba(128, 202, 126), rgba(121, 196, 124)]
        let fill = baseColors[Int(variant) % baseColors.count]

        diamondPath(in: cg, cx: cx, cy: cy, hw: halfW, hh: halfH)
        cg.setFillColor(fill.cgColor)
        cg.fillPath()

        // Subtle tile grid outline
        diamondPath(in: cg, cx: cx, cy: cy, hw: halfW - 0.3, hh: halfH - 0.15)
        cg.setStrokeColor(rgba(74, 140, 74, 0.25).cgColor)
        cg.setLineWidth(0.75)
        cg.strokePath()

        if !dark && variant > 0 {
            let offsetX = CGFloat(Int(variant) - 2) * 5.0
            let offsetY = CGFloat((Int(variant) % 2) == 0 ? -3 : 3)
            cg.setStrokeColor(rgba(95, 168, 95, 0.55).cgColor)
            cg.setLineWidth(1.0)
            cg.move(to: CGPoint(x: cx + offsetX, y: cy + offsetY))
            cg.addLine(to: CGPoint(x: cx + offsetX - 2, y: cy + offsetY - 3))
            cg.move(to: CGPoint(x: cx + offsetX, y: cy + offsetY))
            cg.addLine(to: CGPoint(x: cx + offsetX + 2, y: cy + offsetY - 2.5))
            cg.strokePath()
        }
    }

    private func drawWaterDiamond(in cg: CGContext, cx: CGFloat, cy: CGFloat, variant: UInt8) {
        let shades = [rgba(79, 163, 224), rgba(74, 156, 218), rgba(84, 168, 228), rgba(77, 160, 221)]
        let fill = shades[Int(variant) % shades.count]

        diamondPath(in: cg, cx: cx, cy: cy, hw: halfW, hh: halfH)
        cg.setFillColor(fill.cgColor)
        cg.fillPath()

        diamondPath(in: cg, cx: cx, cy: cy, hw: halfW - 0.3, hh: halfH - 0.15)
        cg.setStrokeColor(rgba(52, 124, 184, 0.38).cgColor)
        cg.setLineWidth(0.75)
        cg.strokePath()

        // Gentle ripple highlight
        let shift = CGFloat(Int(variant) % 3 - 1) * 5.0
        cg.setStrokeColor(rgba(186, 226, 252, 0.6).cgColor)
        cg.setLineWidth(1.2)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: cx - 7 + shift, y: cy - 1))
        cg.addLine(to: CGPoint(x: cx + 1 + shift, y: cy - 3))
        cg.move(to: CGPoint(x: cx - 2 - shift, y: cy + 4))
        cg.addLine(to: CGPoint(x: cx + 6 - shift, y: cy + 2))
        cg.strokePath()
    }

    private func drawZoneL0(in cg: CGContext, cx: CGFloat, cy: CGFloat, fill: UIColor, border: UIColor) {
        diamondPath(in: cg, cx: cx, cy: cy, hw: halfW, hh: halfH)
        cg.setFillColor(fill.cgColor)
        cg.fillPath()

        diamondPath(in: cg, cx: cx, cy: cy, hw: halfW - 2.0, hh: halfH - 1.0)
        cg.setStrokeColor(border.cgColor)
        cg.setLineWidth(1.6)
        cg.strokePath()
    }

    private func drawRoad(in cg: CGContext, cx: CGFloat, cy: CGFloat, mask: UInt8) {
        let asphalt = rgba(90, 90, 90)
        let stripe = rgba(224, 224, 224)

        let top = CGPoint(x: cx, y: cy - halfH)
        let right = CGPoint(x: cx + halfW, y: cy)
        let bottom = CGPoint(x: cx, y: cy + halfH)
        let left = CGPoint(x: cx - halfW, y: cy)
        let center = CGPoint(x: cx, y: cy)

        let roadScale: CGFloat = 0.56
        let halfRatio: CGFloat = roadScale * 0.5 // 0.28

        // Center road intersection diamond
        diamondPath(in: cg, cx: cx, cy: cy, hw: halfW * roadScale, hh: halfH * roadScale)
        cg.setFillColor(asphalt.cgColor)
        cg.fillPath()

        let edgeData: [(bit: UInt8, a: CGPoint, b: CGPoint, mid: CGPoint)] = [
            (1, top, right, CGPoint(x: cx + halfW * 0.5, y: cy - halfH * 0.5)),    // N: (x, y-1)
            (2, right, bottom, CGPoint(x: cx + halfW * 0.5, y: cy + halfH * 0.5)), // E: (x+1, y)
            (4, bottom, left, CGPoint(x: cx - halfW * 0.5, y: cy + halfH * 0.5)),  // S: (x, y+1)
            (8, left, top, CGPoint(x: cx - halfW * 0.5, y: cy - halfH * 0.5))      // W: (x-1, y)
        ]

        for edge in edgeData where (mask & edge.bit) != 0 {
            let edgeVec = CGPoint(x: edge.b.x - edge.a.x, y: edge.b.y - edge.a.y)
            let p1 = CGPoint(x: center.x - edgeVec.x * halfRatio, y: center.y - edgeVec.y * halfRatio)
            let p2 = CGPoint(x: center.x + edgeVec.x * halfRatio, y: center.y + edgeVec.y * halfRatio)
            let p3 = CGPoint(x: edge.mid.x + edgeVec.x * halfRatio, y: edge.mid.y + edgeVec.y * halfRatio)
            let p4 = CGPoint(x: edge.mid.x - edgeVec.x * halfRatio, y: edge.mid.y - edgeVec.y * halfRatio)
            fillPolygon([p1, p2, p3, p4], in: cg, color: asphalt)
        }

        // Road center line markings
        cg.setStrokeColor(stripe.cgColor)
        cg.setLineWidth(1.5)
        cg.setLineCap(.round)
        if mask == 0 {
            cg.fillEllipse(in: CGRect(x: cx - 2, y: cy - 1.5, width: 4, height: 3))
        } else {
            for edge in edgeData where (mask & edge.bit) != 0 {
                let start = CGPoint(
                    x: center.x + (edge.mid.x - center.x) * 0.22,
                    y: center.y + (edge.mid.y - center.y) * 0.22
                )
                let end = CGPoint(
                    x: center.x + (edge.mid.x - center.x) * 0.85,
                    y: center.y + (edge.mid.y - center.y) * 0.85
                )
                cg.move(to: start)
                cg.addLine(to: end)
            }
            cg.strokePath()
        }
    }

    // MARK: - Structure Rendering (64 x H, anchor = (0.5, 16 / H))

    private func renderStructureTexture(kind: TileKind, level: UInt8, variant: UInt8) -> SKTexture {
        switch kind {
        case .forest:
            return renderForestTrees(variant: variant)
        default:
            // Placeholder box for buildings before M3 enriches detailed textures.
            let height: CGFloat = 56
            let image = renderImage(size: CGSize(width: tileW, height: height)) { cg in
                let cy = height - self.halfH
                self.drawIsoBox(
                    in: cg,
                    cx: self.halfW,
                    cy: cy,
                    hw: 18,
                    hh: 9,
                    h: 22,
                    topColor: rgba(200, 205, 212),
                    leftColor: rgba(170, 176, 184),
                    rightColor: rgba(140, 146, 156)
                )
            }
            return makeTexture(from: image)
        }
    }

    private func renderForestTrees(variant: UInt8) -> SKTexture {
        let totalHeight: CGFloat = 54
        let cy = totalHeight - halfH
        let image = renderImage(size: CGSize(width: tileW, height: totalHeight)) { cg in
            let layouts: [[(CGFloat, CGFloat, CGFloat)]] = [
                [(-8, -3, 8.5), (9, -1, 7.5), (0, 5, 9.5)],
                [(6, -4, 8.0), (-9, 1, 9.0), (4, 6, 8.0)],
                [(-2, -5, 8.5), (-11, 3, 7.5), (8, 4, 9.0)],
                [(0, -4, 9.0), (-8, 4, 8.0), (9, 3, 8.5)]
            ]
            let trees = layouts[Int(variant) % layouts.count]

            for (dx, dy, r) in trees {
                let tx = self.halfW + dx
                let ty = cy + dy
                // Ground shadow
                cg.setFillColor(rgba(30, 82, 34, 0.30).cgColor)
                cg.fillEllipse(in: CGRect(x: tx - r * 0.9, y: ty - 2, width: r * 1.8, height: 6))
                // Trunk
                cg.setFillColor(rgba(104, 70, 44).cgColor)
                cg.fill(CGRect(x: tx - 2, y: ty - 9, width: 4, height: 10))
                // Canopy
                cg.setFillColor(rgba(46, 125, 50).cgColor)
                cg.fillEllipse(in: CGRect(x: tx - r, y: ty - 9 - r * 1.5, width: r * 2, height: r * 1.7))
                // Canopy highlight
                cg.setFillColor(rgba(74, 158, 76).cgColor)
                cg.fillEllipse(in: CGRect(x: tx - r * 0.65, y: ty - 9 - r * 1.4, width: r * 1.25, height: r * 1.1))
            }
        }
        return makeTexture(from: image)
    }

    // MARK: - Isometric Geometry Primitives

    func diamondPath(in cg: CGContext, cx: CGFloat, cy: CGFloat, hw: CGFloat, hh: CGFloat) {
        cg.beginPath()
        cg.move(to: CGPoint(x: cx, y: cy - hh))
        cg.addLine(to: CGPoint(x: cx + hw, y: cy))
        cg.addLine(to: CGPoint(x: cx, y: cy + hh))
        cg.addLine(to: CGPoint(x: cx - hw, y: cy))
        cg.closePath()
    }

    func fillPolygon(_ points: [CGPoint], in cg: CGContext, color: UIColor) {
        guard let first = points.first else { return }
        cg.beginPath()
        cg.move(to: first)
        for p in points.dropFirst() {
            cg.addLine(to: p)
        }
        cg.closePath()
        cg.setFillColor(color.cgColor)
        cg.fillPath()
    }

    func drawIsoBox(
        in cg: CGContext,
        cx: CGFloat,
        cy: CGFloat,
        hw: CGFloat,
        hh: CGFloat,
        h: CGFloat,
        topColor: UIColor,
        leftColor: UIColor,
        rightColor: UIColor
    ) {
        let top = CGPoint(x: cx, y: cy - hh)
        let right = CGPoint(x: cx + hw, y: cy)
        let bottom = CGPoint(x: cx, y: cy + hh)
        let left = CGPoint(x: cx - hw, y: cy)

        let topUp = CGPoint(x: top.x, y: top.y - h)
        let rightUp = CGPoint(x: right.x, y: right.y - h)
        let bottomUp = CGPoint(x: bottom.x, y: bottom.y - h)
        let leftUp = CGPoint(x: left.x, y: left.y - h)

        fillPolygon([left, bottom, bottomUp, leftUp], in: cg, color: leftColor)
        fillPolygon([bottom, right, rightUp, bottomUp], in: cg, color: rightColor)
        fillPolygon([topUp, rightUp, bottomUp, leftUp], in: cg, color: topColor)
    }

    func drawPyramidRoof(
        in cg: CGContext,
        cx: CGFloat,
        cy: CGFloat,
        hw: CGFloat,
        hh: CGFloat,
        peakHeight: CGFloat,
        leftColor: UIColor,
        rightColor: UIColor
    ) {
        let right = CGPoint(x: cx + hw, y: cy)
        let bottom = CGPoint(x: cx, y: cy + hh)
        let left = CGPoint(x: cx - hw, y: cy)
        let peak = CGPoint(x: cx, y: cy - peakHeight)

        fillPolygon([left, bottom, peak], in: cg, color: leftColor)
        fillPolygon([bottom, right, peak], in: cg, color: rightColor)
    }

    // MARK: - Image Utilities

    func renderImage(size: CGSize, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            draw(context.cgContext)
        }
    }

    func makeTexture(from image: UIImage) -> SKTexture {
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}

private func rgba(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1.0) -> UIColor {
    UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: a)
}
