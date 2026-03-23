/// PigNode+Treats — Personality-driven treat movement and reaction animations.
import SpriteKit

extension PigNode {

    /// Move toward a treat with personality-based animation modifiers.
    /// - greedy: 2x movement speed (sprint)
    /// - shy: 0.5–1.0s delay before starting
    /// - playful: popcorn bounce during movement
    /// Completion fires when the pig arrives at the treat position.
    func moveToTreat(
        at treatPosition: CGPoint,
        traits: [Personality],
        completion: @escaping () -> Void
    ) {
        let distance = hypot(position.x - treatPosition.x, position.y - treatPosition.y)
        let baseSpeed: CGFloat = 80.0 // pts/second
        var duration = TimeInterval(distance / baseSpeed)
        var actions: [SKAction] = []

        // Shy: delay before moving
        if traits.contains(.shy) {
            let delay = Double.random(in: 0.5...1.0)
            actions.append(SKAction.wait(forDuration: delay))
        }

        // Greedy: double speed
        if traits.contains(.greedy) {
            duration /= 2.0
        }

        // Minimum duration to prevent teleportation at short distances
        duration = max(0.15, duration)

        let moveAction = SKAction.move(to: treatPosition, duration: duration)

        // Playful: interleave bounces with movement
        if traits.contains(.playful) {
            let bounceCount = max(1, Int(duration / 0.3))
            let bounce = SKAction.sequence([
                SKAction.scaleY(to: 1.2, duration: 0.1),
                SKAction.scaleY(to: 1.0, duration: 0.1),
            ])
            let bounces = SKAction.repeat(bounce, count: bounceCount)
            actions.append(SKAction.group([moveAction, bounces]))
        } else {
            actions.append(moveAction)
        }

        run(SKAction.sequence(actions), withKey: "treatMovement") {
            completion()
        }
    }

    /// Play hearts particle at the pig's position.
    func playHeartParticle() {
        guard let parent else { return }
        parent.addChild(ParticleEffects.heartBurst(at: position))
    }
}
