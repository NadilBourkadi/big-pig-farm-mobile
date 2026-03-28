/// PigNode+Treats — Treat consumption visual effects.
import SpriteKit

extension PigNode {

    /// Play hearts particle at the pig's position.
    func playHeartParticle() {
        guard let parent else { return }
        parent.addChild(ParticleEffects.heartBurst(at: position))
    }
}
