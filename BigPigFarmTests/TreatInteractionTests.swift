/// TreatInteractionTests — Tests for treat UI components and scene interaction.
import Testing
import SpriteKit
import SwiftUI
@testable import BigPigFarm

// MARK: - TreatNode Tests

@Suite("TreatNode")
struct TreatNodeTests {

    @Test("Initializes with correct treat type")
    @MainActor func initializesWithType() {
        let node = TreatNode(
            type: .freshVeggies,
            scenePosition: CGPoint(x: 100, y: 100),
            gridPosition: Position(x: 5, y: 5)
        )
        #expect(node.treatType == .freshVeggies)
        #expect(node.gridPosition == Position(x: 5, y: 5))
    }

    @Test("Has correct zPosition between facilities and pigs")
    @MainActor func correctZPosition() {
        let node = TreatNode(
            type: .herbBundle,
            scenePosition: .zero,
            gridPosition: Position()
        )
        #expect(node.zPosition == 7)
    }
}

// MARK: - ParticleEffects Tests

@Suite("ParticleEffects")
struct ParticleEffectsTests {

    @Test("Heart burst creates emitter with particles")
    @MainActor func heartBurstCreatesEmitter() {
        let emitter = ParticleEffects.heartBurst(at: CGPoint(x: 50, y: 50))
        #expect(emitter.numParticlesToEmit == 5)
        #expect(emitter.position == CGPoint(x: 50, y: 50))
        #expect(emitter.zPosition == 20)
    }

    @Test("Sparkle burst creates emitter with particles")
    @MainActor func sparkleBurstCreatesEmitter() {
        let emitter = ParticleEffects.sparkleBurst(at: CGPoint(x: 30, y: 30))
        #expect(emitter.numParticlesToEmit == 8)
        #expect(emitter.position == CGPoint(x: 30, y: 30))
    }
}

// MARK: - FarmScene Treat Mode Tests

@Suite("FarmScene Treat Mode")
struct FarmSceneTreatModeTests {

    @Test("Treat placement mode defaults to false")
    @MainActor func defaultsToFalse() {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        #expect(scene.isTreatPlacementMode == false)
    }

    @Test("Treat layer has correct zPosition")
    @MainActor func treatLayerZPosition() {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        #expect(scene.treatLayer.zPosition == 7)
    }
}

// MARK: - StreakIndicator Tests

@Suite("StreakIndicator")
struct StreakIndicatorTests {

    @Test("Displays with active streak")
    func displaysWithActiveStreak() {
        var streak = VisitStreak()
        streak.currentStreak = 3
        streak.lastVisitDate = Date()
        let indicator = StreakIndicator(streak: streak)
        #expect(indicator.streak.currentStreak == 3)
    }

    @Test("Hidden when streak is zero")
    func hiddenWhenZero() {
        let streak = VisitStreak()
        let indicator = StreakIndicator(streak: streak)
        #expect(indicator.streak.currentStreak == 0)
    }
}

// MARK: - ReunionBoostIndicator Tests

@Suite("ReunionBoostIndicator")
struct ReunionBoostIndicatorTests {

    @Test("Displays with active boost")
    @MainActor func displaysWithActiveBoost() {
        let boost = ReunionBoost.standard()
        let indicator = ReunionBoostIndicator(boost: boost)
        #expect(indicator.boost != nil)
        #expect(indicator.boost!.isActive())
    }

    @Test("Nil boost produces hidden indicator")
    func nilBoostHidden() {
        let indicator = ReunionBoostIndicator(boost: nil)
        #expect(indicator.boost == nil)
    }

    @Test("Expired boost produces hidden indicator")
    @MainActor func expiredBoostHidden() {
        let boost = ReunionBoost.standard(at: Date().addingTimeInterval(-2000))
        let indicator = ReunionBoostIndicator(boost: boost)
        #expect(!indicator.boost!.isActive())
    }
}
