import CityCore
import SpriteKit

/// Manages the SpriteKit nodes representing a single map tile.
@MainActor
final class TileNode {
    let point: GridPoint
    let groundSprite: SKSpriteNode
    private(set) var structureSprite: SKSpriteNode?
    private(set) var unpoweredSprite: SKSpriteNode?
    private(set) var smokeEmitter: SKEmitterNode?

    init(point: GridPoint, groundTexture: SKTexture) {
        self.point = point
        let scenePos = SceneIsoMath.gridToScene(point)
        let ground = SKSpriteNode(texture: groundTexture)
        ground.position = scenePos
        ground.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        ground.zPosition = SceneIsoMath.zPosition(for: point)
        self.groundSprite = ground
    }

    func update(
        tile: Tile,
        roadMask: UInt8,
        textures: TextureFactory,
        in mapNode: SKNode
    ) {
        groundSprite.texture = textures.groundTexture(for: tile, roadMask: roadMask)
        groundSprite.size = groundSprite.texture?.size() ?? CGSize(width: SceneIsoMath.tileWidth, height: SceneIsoMath.tileHeight)

        if let structTex = textures.structureTexture(for: tile) {
            let sprite = ensureStructureSprite(in: mapNode)
            let texSize = structTex.size()
            sprite.texture = structTex
            sprite.size = texSize
            let anchorY = texSize.height > 0 ? (SceneIsoMath.halfHeight / texSize.height) : 0.5
            sprite.anchorPoint = CGPoint(x: 0.5, y: anchorY)
            sprite.isHidden = false
        } else {
            structureSprite?.isHidden = true
        }

        let needsPowerWarning = tile.kind.consumesPower && !tile.powered
        if needsPowerWarning {
            let icon = ensureUnpoweredSprite(textures: textures, in: mapNode)
            icon.isHidden = false
            let heightOffset: CGFloat
            if let sprite = structureSprite, !sprite.isHidden {
                heightOffset = max(20, sprite.size.height - SceneIsoMath.halfHeight)
            } else {
                heightOffset = 14
            }
            let base = SceneIsoMath.gridToScene(point)
            icon.position = CGPoint(x: base.x, y: base.y + heightOffset)
        } else {
            unpoweredSprite?.isHidden = true
        }

        if tile.kind == .powerPlant {
            let emitter = ensureSmokeEmitter(textures: textures, in: mapNode)
            emitter.isHidden = false
            emitter.particleBirthRate = 2.5
        } else if let emitter = smokeEmitter {
            emitter.particleBirthRate = 0
            emitter.isHidden = true
        }
    }

    func playPlacementPop() {
        let target: SKNode
        if let sprite = structureSprite, !sprite.isHidden {
            target = sprite
        } else {
            target = groundSprite
        }
        target.removeAction(forKey: "placementPop")
        target.setScale(0.8)
        let action = SKAction.scale(to: 1.0, duration: 0.15)
        action.timingMode = .easeOut
        target.run(action, withKey: "placementPop")
    }

    private func ensureStructureSprite(in mapNode: SKNode) -> SKSpriteNode {
        if let existing = structureSprite {
            return existing
        }
        let sprite = SKSpriteNode()
        sprite.position = SceneIsoMath.gridToScene(point)
        sprite.zPosition = SceneIsoMath.zPosition(for: point, extra: 0.5)
        mapNode.addChild(sprite)
        structureSprite = sprite
        return sprite
    }

    private func ensureUnpoweredSprite(textures: TextureFactory, in mapNode: SKNode) -> SKSpriteNode {
        if let existing = unpoweredSprite {
            return existing
        }
        let icon = SKSpriteNode(texture: textures.unpoweredIconTexture())
        icon.size = CGSize(width: 18, height: 18)
        icon.zPosition = SceneIsoMath.zPosition(for: point, extra: 0.85)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.45),
            SKAction.fadeAlpha(to: 1.0, duration: 0.45)
        ])
        icon.run(SKAction.repeatForever(pulse), withKey: "blink")
        mapNode.addChild(icon)
        unpoweredSprite = icon
        return icon
    }

    private func ensureSmokeEmitter(textures: TextureFactory, in mapNode: SKNode) -> SKEmitterNode {
        if let existing = smokeEmitter {
            return existing
        }
        let emitter = SKEmitterNode()
        emitter.particleTexture = textures.smokePuffTexture()
        emitter.particleBirthRate = 2.5
        emitter.particleLifetime = 2.2
        emitter.particleLifetimeRange = 0.6
        emitter.particleSpeed = 11
        emitter.particleSpeedRange = 4
        emitter.emissionAngle = .pi * 0.48
        emitter.emissionAngleRange = 0.25
        emitter.particleScale = 0.45
        emitter.particleScaleSpeed = 0.35
        emitter.particleAlpha = 0.55
        emitter.particleAlphaSpeed = -0.25
        let base = SceneIsoMath.gridToScene(point)
        emitter.position = CGPoint(x: base.x - 4, y: base.y + 46)
        emitter.zPosition = SceneIsoMath.zPosition(for: point, extra: 0.75)
        mapNode.addChild(emitter)
        smokeEmitter = emitter
        return emitter
    }
}
