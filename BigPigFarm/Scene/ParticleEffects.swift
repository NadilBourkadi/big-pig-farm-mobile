/// ParticleEffects — Programmatic SpriteKit particle emitter factories.
import SpriteKit

@MainActor
enum ParticleEffects {

    // MARK: - Heart Burst

    /// Creates a burst of small heart particles floating upward. Used for treat consumption.
    /// Returns a static fade-only sprite when Reduce Motion is enabled.
    static func heartBurst(at position: CGPoint) -> SKNode {
        if MotionSettings.isReduced {
            return staticFade(
                texture: heartTexture,
                tint: .systemPink,
                position: position,
                scale: 0.3,
                alpha: 0.9
            )
        }
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 20
        emitter.particleTexture = heartTexture
        emitter.particleBirthRate = 10
        emitter.numParticlesToEmit = 5
        emitter.particleLifetime = 1.2
        emitter.particleLifetimeRange = 0.3
        emitter.emissionAngle = .pi / 2 // upward
        emitter.emissionAngleRange = .pi / 3
        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 10
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -0.7
        emitter.particleScale = 0.15
        emitter.particleScaleRange = 0.05
        emitter.particleColor = .systemPink
        emitter.particleColorBlendFactor = 1.0
        emitter.yAcceleration = 10 // gentle float up
        // Auto-remove after particles die
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.removeFromParent(),
        ]))
        return emitter
    }

    // MARK: - Sparkle Burst

    /// Creates a radial burst of sparkle particles. Used for reunion boost and treat placement.
    /// Returns a static fade-only sprite when Reduce Motion is enabled.
    static func sparkleBurst(at position: CGPoint) -> SKNode {
        if MotionSettings.isReduced {
            return staticFade(
                texture: sparkleTexture,
                tint: .yellow,
                position: position,
                scale: 0.5,
                alpha: 1.0
            )
        }
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 20
        emitter.particleTexture = sparkleTexture
        emitter.particleBirthRate = 15
        emitter.numParticlesToEmit = 8
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngleRange = .pi * 2 // radial
        emitter.particleSpeed = 40
        emitter.particleSpeedRange = 15
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.2
        emitter.particleScale = 0.1
        emitter.particleScaleRange = 0.04
        emitter.particleColor = .yellow
        emitter.particleColorBlendFactor = 1.0
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.removeFromParent(),
        ]))
        return emitter
    }

    // MARK: - Reduce Motion Fallback

    /// Builds a single static sprite that fades in, holds, fades out, and removes itself.
    /// Used as the Reduce Motion replacement for particle bursts — no spatial movement.
    private static func staticFade(
        texture: SKTexture,
        tint: UIColor,
        position: CGPoint,
        scale: CGFloat,
        alpha: CGFloat
    ) -> SKNode {
        let sprite = SKSpriteNode(texture: texture)
        sprite.position = position
        sprite.zPosition = 20
        sprite.setScale(scale)
        sprite.alpha = 0
        sprite.color = tint
        sprite.colorBlendFactor = 1.0
        sprite.run(SKAction.sequence([
            SKAction.fadeAlpha(to: alpha, duration: 0.1),
            SKAction.wait(forDuration: 0.4),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent(),
        ]))
        return sprite
    }

    // MARK: - Textures

    private static let heartTexture: SKTexture = makeHeartTexture()
    private static let sparkleTexture: SKTexture = makeSparkleTexture()

    private static func makeHeartTexture() -> SKTexture {
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            // Simple heart shape using two arcs
            path.move(to: CGPoint(x: center.x, y: rect.maxY - 2))
            path.addCurve(
                to: CGPoint(x: rect.minX + 1, y: center.y - 1),
                controlPoint1: CGPoint(x: center.x - 4, y: rect.maxY - 4),
                controlPoint2: CGPoint(x: rect.minX + 1, y: rect.maxY - 4)
            )
            path.addArc(
                withCenter: CGPoint(x: rect.minX + 4.5, y: center.y - 2),
                radius: 3.5, startAngle: .pi, endAngle: 0, clockwise: true
            )
            path.addArc(
                withCenter: CGPoint(x: rect.maxX - 4.5, y: center.y - 2),
                radius: 3.5, startAngle: .pi, endAngle: 0, clockwise: true
            )
            path.addCurve(
                to: CGPoint(x: center.x, y: rect.maxY - 2),
                controlPoint1: CGPoint(x: rect.maxX - 1, y: rect.maxY - 4),
                controlPoint2: CGPoint(x: center.x + 4, y: rect.maxY - 4)
            )
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
        return SKTexture(image: image)
    }

    private static func makeSparkleTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: rect).fill()
        }
        return SKTexture(image: image)
    }
}
