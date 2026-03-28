/// AccessibilityTests — VoiceOver accessibility label, value, and frame tests.
import Testing
import SpriteKit
@testable import BigPigFarm

// MARK: - Pig Accessibility Labels

@Suite("Pig Accessibility Labels")
@MainActor
struct PigAccessibilityLabelTests {

    private func makeScene() -> FarmScene {
        FarmScene(gameState: GameState())
    }

    private func makePig(
        name: String = "Butterscotch",
        gender: Gender = .female,
        behavior: BehaviorState = .idle,
        health: Double = 100,
        hunger: Double = 100,
        thirst: Double = 100,
        pregnant: Bool = false,
        ageDays: Double = 25
    ) -> GuineaPig {
        var pig = GuineaPig.create(name: name, gender: gender)
        pig.behaviorState = behavior
        pig.needs.health = health
        pig.needs.hunger = hunger
        pig.needs.thirst = thirst
        pig.ageDays = ageDays
        pig.isPregnant = pregnant
        return pig
    }

    @Test("Label includes name, color, gender, and behavior")
    func labelIncludesBasicInfo() {
        let scene = makeScene()
        let pig = makePig(name: "Daisy", gender: .female, behavior: .eating)
        let label = scene.pigAccessibilityLabel(for: pig)
        #expect(label.contains("Daisy"))
        #expect(label.contains("female"))
        #expect(label.contains("eating"))
    }

    @Test("Label format is comma-separated")
    func labelIsCommaSeparated() {
        let scene = makeScene()
        let pig = makePig()
        let label = scene.pigAccessibilityLabel(for: pig)
        let parts = label.components(separatedBy: ", ")
        #expect(parts.count >= 3)
    }

    @Test("Label includes critical need warnings")
    func labelIncludesCriticalNeeds() {
        let scene = makeScene()
        let low = Double(GameConfig.Needs.lowThreshold) - 1
        let pig = makePig(health: low, hunger: low, thirst: low)
        let label = scene.pigAccessibilityLabel(for: pig)
        #expect(label.contains("health low"))
        #expect(label.contains("hungry"))
        #expect(label.contains("thirsty"))
    }

    @Test("Label omits need warnings when needs are healthy")
    func labelOmitsWarningsWhenHealthy() {
        let scene = makeScene()
        let pig = makePig()
        let label = scene.pigAccessibilityLabel(for: pig)
        #expect(!label.contains("health low"))
        #expect(!label.contains("hungry"))
        #expect(!label.contains("thirsty"))
    }

    @Test("Label includes pregnant status")
    func labelIncludesPregnant() {
        let scene = makeScene()
        let pig = makePig(pregnant: true)
        let label = scene.pigAccessibilityLabel(for: pig)
        #expect(label.contains("pregnant"))
    }

    @Test("Label includes baby for young pigs")
    func labelIncludesBabyForYoungPigs() {
        let scene = makeScene()
        let pig = makePig(ageDays: 0)
        let label = scene.pigAccessibilityLabel(for: pig)
        #expect(label.contains("baby"))
    }

    @Test("Label includes senior for old pigs")
    func labelIncludesSeniorForOldPigs() {
        let scene = makeScene()
        let pig = makePig(ageDays: Double(GameConfig.Simulation.seniorAgeDays))
        let label = scene.pigAccessibilityLabel(for: pig)
        #expect(label.contains("senior"))
    }

    @Test("Label omits age group for adults")
    func labelOmitsAgeForAdults() {
        let scene = makeScene()
        let pig = makePig(ageDays: 25)
        let label = scene.pigAccessibilityLabel(for: pig)
        #expect(!label.contains("baby"))
        #expect(!label.contains("senior"))
    }

    @Test("All behavior states produce non-empty labels")
    func allBehaviorStatesProduceLabels() {
        let scene = makeScene()
        for state in BehaviorState.allCases {
            let pig = makePig(behavior: state)
            let label = scene.pigAccessibilityLabel(for: pig)
            #expect(!label.isEmpty, "Label should be non-empty for \(state)")
        }
    }
}

// MARK: - Pig Accessibility Values

@Suite("Pig Accessibility Values")
@MainActor
struct PigAccessibilityValueTests {

    private func makeScene() -> FarmScene {
        FarmScene(gameState: GameState())
    }

    @Test("Value reports happiness, health, hunger, and thirst percentages")
    func valueReportsPercentages() {
        let scene = makeScene()
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.needs.happiness = 75
        pig.needs.health = 100
        pig.needs.hunger = 80
        pig.needs.thirst = 90
        let value = scene.pigAccessibilityValue(for: pig)
        #expect(value.contains("Happiness 75%"))
        #expect(value.contains("Health 100%"))
        #expect(value.contains("Hunger 80%"))
        #expect(value.contains("Thirst 90%"))
    }
}

// MARK: - Facility Accessibility Labels

@Suite("Facility Accessibility Labels")
@MainActor
struct FacilityAccessibilityLabelTests {

    private func makeScene() -> FarmScene {
        FarmScene(gameState: GameState())
    }

    @Test("Label includes facility display name")
    func labelIncludesDisplayName() {
        let scene = makeScene()
        let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
        let label = scene.facilityAccessibilityLabel(for: facility)
        #expect(label.contains("Food Bowl"))
    }

    @Test("Label includes level when above 1")
    func labelIncludesLevelAbove1() {
        let scene = makeScene()
        var facility = Facility.create(type: .foodBowl, x: 5, y: 5)
        _ = facility.upgrade()
        let label = scene.facilityAccessibilityLabel(for: facility)
        #expect(label.contains("level 2"))
    }

    @Test("Label omits level when at level 1")
    func labelOmitsLevel1() {
        let scene = makeScene()
        let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
        let label = scene.facilityAccessibilityLabel(for: facility)
        #expect(!label.contains("level"))
    }
}

// MARK: - Facility Accessibility Values

@Suite("Facility Accessibility Values")
@MainActor
struct FacilityAccessibilityValueTests {

    private func makeScene() -> FarmScene {
        FarmScene(gameState: GameState())
    }

    @Test("Value shows percentage for consumable facilities")
    func valueShowsPercentageForConsumable() {
        let scene = makeScene()
        var facility = Facility.create(type: .foodBowl, x: 5, y: 5)
        facility.currentAmount = facility.maxAmount / 2
        let value = scene.facilityAccessibilityValue(for: facility)
        #expect(value == "50% full")
    }

    @Test("Value shows Empty for depleted consumable")
    func valueShowsEmptyForDepleted() {
        let scene = makeScene()
        var facility = Facility.create(type: .foodBowl, x: 5, y: 5)
        facility.currentAmount = 0
        let value = scene.facilityAccessibilityValue(for: facility)
        #expect(value == "Empty")
    }

    @Test("Value is nil for non-consumable facilities")
    func valueIsNilForNonConsumable() {
        let scene = makeScene()
        let facility = Facility.create(type: .breedingDen, x: 5, y: 5)
        let value = scene.facilityAccessibilityValue(for: facility)
        #expect(value == nil)
    }

    @Test("Value is nil for occupancy-based facilities without refill cost")
    func valueIsNilForOccupancyFacilities() {
        let scene = makeScene()
        let facility = Facility.create(type: .hideout, x: 5, y: 5)
        let value = scene.facilityAccessibilityValue(for: facility)
        #expect(value == nil)
    }
}

// MARK: - Accessibility Frame Tests

@Suite("Accessibility Frame Conversion")
@MainActor
struct AccessibilityFrameTests {

    @Test("Frame returns .zero when scene has no view")
    func frameReturnsZeroWithoutView() {
        let scene = FarmScene(gameState: GameState())
        let frame = scene.accessibilityFrame(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 32, height: 32)
        )
        #expect(frame == .zero)
    }

    @Test("Frame returns .zero when scene size is zero")
    func frameReturnsZeroWithZeroSceneSize() {
        let scene = FarmScene(gameState: GameState())
        scene.size = .zero
        let frame = scene.accessibilityFrame(
            position: .zero,
            size: CGSize(width: 32, height: 32)
        )
        #expect(frame == .zero)
    }
}

// MARK: - Sync Gating Tests

@Suite("Accessibility Sync Gating")
@MainActor
struct AccessibilitySyncGatingTests {

    @Test("Sync does not crash when scene has no view")
    func syncNoCrashWithoutView() {
        let scene = FarmScene(gameState: GameState())
        scene.syncAccessibilityElements()
    }

    @Test("Throttle interval is 5 ticks (0.5s at 10 TPS)")
    func throttleIntervalIs5Ticks() {
        #expect(FarmScene.accessibilitySyncInterval == 5)
    }
}
