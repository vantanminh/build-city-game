import CityCore
import SpriteKit
import UIKit

/// Isometric SpriteKit scene rendering the city map and handling touch navigation/building gestures.
@MainActor
final class CityScene: SKScene, UIGestureRecognizerDelegate, CityRenderer {
    weak var controller: GameController?

    private let mapNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let textureFactory = TextureFactory()
    private var tileNodes: [TileNode] = []
    private var mapWidth: Int = 0
    private var mapHeight: Int = 0

    private lazy var highlightNode: SKSpriteNode = {
        let node = SKSpriteNode(texture: textureFactory.highlightTexture(valid: true))
        node.size = CGSize(width: SceneIsoMath.tileWidth, height: SceneIsoMath.tileHeight)
        node.zPosition = 10_000
        node.isHidden = true
        return node
    }()

    private weak var configuredView: SKView?
    private var lastUpdateTime: TimeInterval?
    private var lastPaintedPoint: GridPoint?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = UIColor(red: 0.14, green: 0.19, blue: 0.24, alpha: 1.0)
        scaleMode = .resizeFill

        if mapNode.parent == nil {
            addChild(mapNode)
        }
        if cameraNode.parent == nil {
            addChild(cameraNode)
            camera = cameraNode
        }
        if highlightNode.parent == nil {
            mapNode.addChild(highlightNode)
        }

        if configuredView !== view {
            attachGestures(to: view)
            configuredView = view
        }

        if tileNodes.isEmpty {
            reloadAll()
            centerCamera()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval
        if let prev = lastUpdateTime {
            dt = max(0, min(0.25, currentTime - prev))
        } else {
            dt = 0
        }
        lastUpdateTime = currentTime
        controller?.advance(dt: dt)
    }

    // MARK: - CityRenderer

    func reloadAll() {
        guard let city = controller?.city else { return }

        mapNode.removeAllChildren()
        mapNode.addChild(highlightNode)
        highlightNode.isHidden = true

        mapWidth = city.map.width
        mapHeight = city.map.height
        tileNodes = []
        tileNodes.reserveCapacity(mapWidth * mapHeight)

        for y in 0..<mapHeight {
            for x in 0..<mapWidth {
                let point = GridPoint(x: x, y: y)
                let tile = city.map[point]
                let mask = city.map.roadMask(at: point)
                let groundTex = textureFactory.groundTexture(for: tile, roadMask: mask)
                let node = TileNode(point: point, groundTexture: groundTex)
                mapNode.addChild(node.groundSprite)
                node.update(tile: tile, roadMask: mask, textures: textureFactory, in: mapNode)
                tileNodes.append(node)
            }
        }
    }

    func refresh(_ points: [GridPoint]) {
        guard let city = controller?.city else { return }
        for point in points where city.map.contains(point) {
            let idx = point.y * mapWidth + point.x
            guard idx >= 0 && idx < tileNodes.count else { continue }
            let tile = city.map[point]
            let mask = city.map.roadMask(at: point)
            tileNodes[idx].update(tile: tile, roadMask: mask, textures: textureFactory, in: mapNode)
        }
    }

    func animatePlacement(at point: GridPoint) {
        guard point.x >= 0 && point.x < mapWidth && point.y >= 0 && point.y < mapHeight else { return }
        let idx = point.y * mapWidth + point.x
        guard idx >= 0 && idx < tileNodes.count else { return }
        tileNodes[idx].playPlacementPop()
    }

    func centerCamera() {
        guard let city = controller?.city else { return }
        let center = GridPoint(x: city.map.width / 2, y: city.map.height / 2)
        cameraNode.position = SceneIsoMath.gridToScene(center)
        cameraNode.setScale(1.0)
        clampCameraPosition()
    }

    // MARK: - Gestures

    private func attachGestures(to view: SKView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        let singlePan = UIPanGestureRecognizer(target: self, action: #selector(handleSinglePan(_:)))
        singlePan.minimumNumberOfTouches = 1
        singlePan.maximumNumberOfTouches = 1
        singlePan.cancelsTouchesInView = false
        singlePan.delegate = self
        view.addGestureRecognizer(singlePan)

        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.delegate = self
        view.addGestureRecognizer(twoFingerPan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        view.addGestureRecognizer(pinch)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1, let touch = touches.first, let view = self.view else { return }
        let viewLoc = touch.location(in: view)
        let point = gridPoint(fromViewPoint: viewLoc)
        updateHighlight(at: point)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let view = self.view else { return }
        let point = gridPoint(fromViewPoint: recognizer.location(in: view))
        updateHighlight(at: point)
        controller?.tap(at: point)
    }

    @objc private func handleSinglePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = self.view, let controller = controller else { return }

        if controller.selectedTool == .inspect {
            if recognizer.state == .changed {
                let translation = recognizer.translation(in: view)
                panCamera(by: translation)
                recognizer.setTranslation(.zero, in: view)
            }
            return
        }

        let point = gridPoint(fromViewPoint: recognizer.location(in: view))
        switch recognizer.state {
        case .began:
            lastPaintedPoint = point
            updateHighlight(at: point)
            controller.paint(from: nil, to: point)
        case .changed:
            updateHighlight(at: point)
            if point != lastPaintedPoint {
                controller.paint(from: lastPaintedPoint, to: point)
                lastPaintedPoint = point
            }
        case .ended, .cancelled, .failed:
            lastPaintedPoint = nil
        default:
            break
        }
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = self.view, recognizer.state == .changed else { return }
        let translation = recognizer.translation(in: view)
        panCamera(by: translation)
        recognizer.setTranslation(.zero, in: view)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .changed, recognizer.scale > 0 else { return }
        let currentScale = cameraNode.xScale
        let nextScale = max(0.4, min(2.5, currentScale / recognizer.scale))
        cameraNode.setScale(nextScale)
        recognizer.scale = 1.0
        clampCameraPosition()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let isPinchOrTwoPan: (UIGestureRecognizer) -> Bool = { rec in
            if rec is UIPinchGestureRecognizer { return true }
            if let pan = rec as? UIPanGestureRecognizer, pan.minimumNumberOfTouches == 2 { return true }
            return false
        }
        return isPinchOrTwoPan(gestureRecognizer) && isPinchOrTwoPan(otherGestureRecognizer)
    }

    // MARK: - Helpers

    private func gridPoint(fromViewPoint viewPoint: CGPoint) -> GridPoint {
        let scenePoint = convertPoint(fromView: viewPoint)
        let mapPoint = mapNode.convert(scenePoint, from: self)
        return SceneIsoMath.sceneToGrid(mapPoint)
    }

    private func updateHighlight(at point: GridPoint) {
        guard let city = controller?.city, city.map.contains(point) else {
            highlightNode.isHidden = true
            return
        }
        let valid = controller?.canPlaceHighlight(at: point) ?? (city.map[point].kind != .water)
        highlightNode.texture = textureFactory.highlightTexture(valid: valid)
        highlightNode.position = SceneIsoMath.gridToScene(point)
        highlightNode.isHidden = false
    }

    private func panCamera(by viewDelta: CGPoint) {
        cameraNode.position.x -= viewDelta.x * cameraNode.xScale
        cameraNode.position.y += viewDelta.y * cameraNode.yScale
        clampCameraPosition()
    }

    private func clampCameraPosition() {
        let w = CGFloat(max(1, mapWidth))
        let h = CGFloat(max(1, mapHeight))
        let minX = -h * SceneIsoMath.halfWidth
        let maxX = w * SceneIsoMath.halfWidth
        let minY = -(w + h) * SceneIsoMath.halfHeight - 40
        let maxY: CGFloat = 80

        cameraNode.position.x = max(minX, min(maxX, cameraNode.position.x))
        cameraNode.position.y = max(minY, min(maxY, cameraNode.position.y))
    }
}
