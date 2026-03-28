/// PigNode+Treats — Treat consumption visual effects.
import SpriteKit

extension PigNode {

    /// Play hearts particle at the pig's position.
    func playHeartParticle() {
        guard let parent else { return }
        parent.addChild(ParticleEffects.heartBurst(at: position))
    }

    /// Start a repeating vertical bounce animation (playful pigs seeking treats).
    /// No-op if already bouncing.
    func startTreatBounce() {
        guard action(forKey: "treatBounce") == nil else { return }
        let amplitude = CGFloat(GameConfig.Behavior.playfulTreatBounceAmplitude)
        let halfPeriod = GameConfig.Behavior.playfulTreatBouncePeriod / 2
        let up = SKAction.moveBy(x: 0, y: amplitude, duration: halfPeriod)
        up.timingMode = .easeInEaseOut
        let down = SKAction.moveBy(x: 0, y: -amplitude, duration: halfPeriod)
        down.timingMode = .easeInEaseOut
        run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "treatBounce")
    }

    /// Stop the treat bounce animation.
    /// Position drift from mid-bounce is corrected by the next `syncPigs` tick
    /// which overwrites position via `update(from:in:)`.
    func stopTreatBounce() {
        removeAction(forKey: "treatBounce")
    }
}
