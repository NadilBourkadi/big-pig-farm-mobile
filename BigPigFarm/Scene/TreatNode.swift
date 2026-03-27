/// TreatNode — SpriteKit sprite for a treat placed on the farm.
import SpriteKit

class TreatNode: SKSpriteNode {
    let treatType: TreatType
    let gridPosition: Position
    private var consumedCount: Int = 0
    private let maxConsumers: Int = GameConfig.Prestige.treatsPerScatter

    init(type: TreatType, scenePosition: CGPoint, gridPosition: Position) {
        self.treatType = type
        self.gridPosition = gridPosition

        let texture = Self.textureForType(type)
        let nodeSize = CGSize(width: 12, height: 12)
        super.init(texture: texture, color: .clear, size: nodeSize)

        position = scenePosition
        zPosition = 7 // between facilities (5) and pigs (10)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Animations

    /// Pop-in spawn animation.
    func animateSpawn() {
        setScale(0)
        run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.1),
        ]))
        parent?.addChild(ParticleEffects.sparkleBurst(at: position))
    }

    /// Called when a pig arrives and consumes the treat.
    /// Returns true if this was the last consumer (treat should be removed).
    func animatePickup(completion: @escaping () -> Void) -> Bool {
        consumedCount += 1
        let isLast = consumedCount >= maxConsumers

        if isLast {
            run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 0, duration: 0.2),
                    SKAction.fadeOut(withDuration: 0.2),
                ]),
                SKAction.removeFromParent(),
            ])) {
                completion()
            }
        } else {
            // Pulse to show a pig ate
            run(SKAction.sequence([
                SKAction.scale(to: 0.8, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1),
            ])) {
                completion()
            }
        }
        return isLast
    }

    // MARK: - Textures

    private static func textureForType(_ type: TreatType) -> SKTexture {
        SpriteAssets.treatTexture(type: type)
    }
}
