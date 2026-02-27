/// EnumTests — Exhaustive tests for all 21 ported Python enums.
import Testing
@testable import BigPigFarm

// MARK: - Genetics Enums

@Test func alleleHas12Cases() {
    #expect(Allele.allCases.count == 12)
}

@Test func alleleRawValues() {
    #expect(Allele.dominantE.rawValue == "E")
    #expect(Allele.recessiveE.rawValue == "e")
    #expect(Allele.dominantB.rawValue == "B")
    #expect(Allele.recessiveB.rawValue == "b")
    #expect(Allele.dominantS.rawValue == "S")
    #expect(Allele.recessiveS.rawValue == "s")
    #expect(Allele.dominantC.rawValue == "C")
    #expect(Allele.chinchilla.rawValue == "ch")
    #expect(Allele.dominantR.rawValue == "R")
    #expect(Allele.recessiveR.rawValue == "r")
    #expect(Allele.dominantD.rawValue == "D")
    #expect(Allele.recessiveD.rawValue == "d")
}

@Test func alleleDecodesFromJSON() throws {
    let json = "\"ch\""
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(Allele.self, from: data)
    #expect(decoded == .chinchilla)
}

@Test func baseColorHas8Cases() {
    #expect(BaseColor.allCases.count == 8)
}

@Test func baseColorCasesMatchPython() {
    let expected: [BaseColor] = [
        .black, .chocolate, .golden, .cream,
        .blue, .lilac, .saffron, .smoke,
    ]
    #expect(BaseColor.allCases == expected)
}

@Test func baseColorRawValues() {
    #expect(BaseColor.black.rawValue == "black")
    #expect(BaseColor.smoke.rawValue == "smoke")
    #expect(BaseColor.saffron.rawValue == "saffron")
}

@Test func patternHas3Cases() {
    #expect(Pattern.allCases.count == 3)
}

@Test func patternCasesMatchPython() {
    let expected: [Pattern] = [.solid, .dutch, .dalmatian]
    #expect(Pattern.allCases == expected)
}

@Test func colorIntensityHas3Cases() {
    #expect(ColorIntensity.allCases.count == 3)
}

@Test func colorIntensityCasesMatchPython() {
    let expected: [ColorIntensity] = [.full, .chinchilla, .himalayan]
    #expect(ColorIntensity.allCases == expected)
}

@Test func roanTypeHas2Cases() {
    #expect(RoanType.allCases.count == 2)
}

@Test func roanTypeCasesMatchPython() {
    #expect(RoanType.none.rawValue == "none")
    #expect(RoanType.roan.rawValue == "roan")
}

@Test func rarityHas5Cases() {
    #expect(Rarity.allCases.count == 5)
}

@Test func rarityVeryRareRawValue() {
    // Python uses "very_rare" as the string value
    #expect(Rarity.veryRare.rawValue == "very_rare")
}

@Test func rarityCasesAreOrdered() {
    let expected: [Rarity] = [.common, .uncommon, .rare, .veryRare, .legendary]
    #expect(Rarity.allCases == expected)
}

@Test func rarityDecodesSnakeCaseFromJSON() throws {
    let json = "\"very_rare\""
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(Rarity.self, from: data)
    #expect(decoded == .veryRare)
}

// MARK: - Guinea Pig Enums

@Test func genderHas2Cases() {
    #expect(Gender.allCases.count == 2)
}

@Test func genderCases() {
    #expect(Gender.male.rawValue == "male")
    #expect(Gender.female.rawValue == "female")
}

@Test func ageGroupHas3Cases() {
    // Python source has 3 stages: baby, adult, senior (no juvenile)
    #expect(AgeGroup.allCases.count == 3)
}

@Test func ageGroupCasesMatchPython() {
    let expected: [AgeGroup] = [.baby, .adult, .senior]
    #expect(AgeGroup.allCases == expected)
}

@Test func behaviorStateHas8Cases() {
    #expect(BehaviorState.allCases.count == 8)
}

@Test func behaviorStateCasesMatchPython() {
    let expected: [BehaviorState] = [
        .idle, .wandering, .eating, .drinking,
        .playing, .sleeping, .socializing, .courting,
    ]
    #expect(BehaviorState.allCases == expected)
}

@Test func personalityHas7Cases() {
    #expect(Personality.allCases.count == 7)
}

@Test func personalityCasesMatchPython() {
    let expected: [Personality] = [
        .greedy, .lazy, .playful, .shy,
        .social, .brave, .picky,
    ]
    #expect(Personality.allCases == expected)
}

// MARK: - Facility Enum

@Test func facilityTypeHas17Cases() {
    #expect(FacilityType.allCases.count == 17)
}

@Test func facilityTypeSnakeCaseRawValues() {
    #expect(FacilityType.foodBowl.rawValue == "food_bowl")
    #expect(FacilityType.waterBottle.rawValue == "water_bottle")
    #expect(FacilityType.hayRack.rawValue == "hay_rack")
    #expect(FacilityType.exerciseWheel.rawValue == "exercise_wheel")
    #expect(FacilityType.playArea.rawValue == "play_area")
    #expect(FacilityType.breedingDen.rawValue == "breeding_den")
    #expect(FacilityType.veggieGarden.rawValue == "veggie_garden")
    #expect(FacilityType.groomingStation.rawValue == "grooming_station")
    #expect(FacilityType.geneticsLab.rawValue == "genetics_lab")
    #expect(FacilityType.feastTable.rawValue == "feast_table")
    #expect(FacilityType.therapyGarden.rawValue == "therapy_garden")
    #expect(FacilityType.hotSpring.rawValue == "hot_spring")
}

@Test func facilityTypeSingleWordRawValues() {
    // Single-word cases have implicit raw values
    #expect(FacilityType.hideout.rawValue == "hideout")
    #expect(FacilityType.tunnel.rawValue == "tunnel")
    #expect(FacilityType.nursery.rawValue == "nursery")
    #expect(FacilityType.campfire.rawValue == "campfire")
    #expect(FacilityType.stage.rawValue == "stage")
}

@Test func facilityTypeDisplayName() {
    #expect(FacilityType.foodBowl.displayName == "Food Bowl")
    #expect(FacilityType.hotSpring.displayName == "Hot Spring")
    #expect(FacilityType.stage.displayName == "Stage")
}

@Test func facilityTypeDecodesFromJSON() throws {
    let json = "\"genetics_lab\""
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(FacilityType.self, from: data)
    #expect(decoded == .geneticsLab)
}

// MARK: - BiomeType Enum

@Test func biomeTypeHas8Cases() {
    #expect(BiomeType.allCases.count == 8)
}

@Test func biomeTypeCasesMatchPython() {
    let expected: [BiomeType] = [
        .meadow, .burrow, .garden, .tropical,
        .alpine, .crystal, .wildflower, .sanctuary,
    ]
    #expect(BiomeType.allCases == expected)
}

// MARK: - BloodlineType Enum

@Test func bloodlineTypeHas7Cases() {
    #expect(BloodlineType.allCases.count == 7)
}

@Test func bloodlineTypeCasesMatchPython() {
    let expected: [BloodlineType] = [
        .spotted, .chocolate, .golden, .silver,
        .roan, .exoticSpotSilver, .exoticRoanSilver,
    ]
    #expect(BloodlineType.allCases == expected)
}

@Test func bloodlineTypeSnakeCaseRawValues() {
    #expect(BloodlineType.exoticSpotSilver.rawValue == "exotic_spot_silver")
    #expect(BloodlineType.exoticRoanSilver.rawValue == "exotic_roan_silver")
}

// MARK: - CellType Enum

@Test func cellTypeHas4Cases() {
    #expect(CellType.allCases.count == 4)
}

@Test func cellTypeCasesMatchPython() {
    let expected: [CellType] = [.floor, .bedding, .grass, .wall]
    #expect(CellType.allCases == expected)
}

// MARK: - GameSpeed Enum

@Test func gameSpeedHas7Cases() {
    #expect(GameSpeed.allCases.count == 7)
}

@Test func gameSpeedRawValues() {
    #expect(GameSpeed.paused.rawValue == 0)
    #expect(GameSpeed.normal.rawValue == 3)
    #expect(GameSpeed.fast.rawValue == 6)
    #expect(GameSpeed.faster.rawValue == 15)
    #expect(GameSpeed.fastest.rawValue == 60)
    #expect(GameSpeed.debug.rawValue == 300)
    #expect(GameSpeed.debugFast.rawValue == 900)
}

@Test func gameSpeedDisplayLabels() {
    #expect(GameSpeed.paused.displayLabel == "0x")
    #expect(GameSpeed.normal.displayLabel == "1x")
    #expect(GameSpeed.fast.displayLabel == "2x")
    #expect(GameSpeed.faster.displayLabel == "5x")
    #expect(GameSpeed.fastest.displayLabel == "20x")
    #expect(GameSpeed.debug.displayLabel == "100x")
    #expect(GameSpeed.debugFast.displayLabel == "300x")
}

// MARK: - ContractDifficulty Enum

@Test func contractDifficultyHas5Cases() {
    #expect(ContractDifficulty.allCases.count == 5)
}

@Test func contractDifficultyCasesMatchPython() {
    let expected: [ContractDifficulty] = [
        .easy, .medium, .hard, .expert, .legendary,
    ]
    #expect(ContractDifficulty.allCases == expected)
}

// MARK: - ShopCategory Enum

@Test func shopCategoryHas5Cases() {
    #expect(ShopCategory.allCases.count == 5)
}

@Test func shopCategoryCasesMatchPython() {
    let expected: [ShopCategory] = [
        .facilities, .perks, .upgrades, .decorations, .adoption,
    ]
    #expect(ShopCategory.allCases == expected)
}

// MARK: - BreedingStrategy Enum

@Test func breedingStrategyHas3Cases() {
    #expect(BreedingStrategy.allCases.count == 3)
}

@Test func breedingStrategyCasesMatchPython() {
    let expected: [BreedingStrategy] = [.target, .diversity, .money]
    #expect(BreedingStrategy.allCases == expected)
}

// MARK: - Sprite Type Enums

@Test func directionHas2Cases() {
    #expect(Direction.allCases.count == 2)
}

@Test func directionCasesMatchPython() {
    #expect(Direction.left.rawValue == "left")
    #expect(Direction.right.rawValue == "right")
}

@Test func zoomLevelHas3Cases() {
    #expect(ZoomLevel.allCases.count == 3)
}

@Test func zoomLevelCasesMatchPython() {
    let expected: [ZoomLevel] = [.far, .normal, .close]
    #expect(ZoomLevel.allCases == expected)
}

@Test func indicatorTypeHas6Cases() {
    #expect(IndicatorType.allCases.count == 6)
}

@Test func indicatorTypeCasesMatchPython() {
    let expected: [IndicatorType] = [
        .health, .hunger, .thirst, .energy, .courting, .pregnant,
    ]
    #expect(IndicatorType.allCases == expected)
}

// MARK: - Cross-Enum JSON Round-Trip

@Test func allStringEnumsRoundTripThroughJSON() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // Test a representative sample of enums with custom raw values
    let facilityData = try encoder.encode(FacilityType.geneticsLab)
    let facilityDecoded = try decoder.decode(FacilityType.self, from: facilityData)
    #expect(facilityDecoded == .geneticsLab)

    let bloodlineData = try encoder.encode(BloodlineType.exoticRoanSilver)
    let bloodlineDecoded = try decoder.decode(BloodlineType.self, from: bloodlineData)
    #expect(bloodlineDecoded == .exoticRoanSilver)

    let rarityData = try encoder.encode(Rarity.veryRare)
    let rarityDecoded = try decoder.decode(Rarity.self, from: rarityData)
    #expect(rarityDecoded == .veryRare)
}

@Test func gameSpeedRoundTripsThroughJSON() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let data = try encoder.encode(GameSpeed.debugFast)
    let decoded = try decoder.decode(GameSpeed.self, from: data)
    #expect(decoded == .debugFast)
    #expect(decoded.rawValue == 900)
}

// MARK: - Sendable Conformance

@Test func allEnumsAreSendable() {
    // These assignments verify Sendable conformance at compile time.
    // If any enum is not Sendable, this test will fail to compile.
    let _: any Sendable = Allele.dominantE
    let _: any Sendable = BaseColor.black
    let _: any Sendable = Pattern.solid
    let _: any Sendable = ColorIntensity.full
    let _: any Sendable = RoanType.none
    let _: any Sendable = Rarity.common
    let _: any Sendable = Gender.male
    let _: any Sendable = AgeGroup.baby
    let _: any Sendable = BehaviorState.idle
    let _: any Sendable = Personality.greedy
    let _: any Sendable = FacilityType.foodBowl
    let _: any Sendable = BiomeType.meadow
    let _: any Sendable = BloodlineType.spotted
    let _: any Sendable = CellType.floor
    let _: any Sendable = GameSpeed.normal
    let _: any Sendable = ContractDifficulty.easy
    let _: any Sendable = ShopCategory.facilities
    let _: any Sendable = BreedingStrategy.target
    let _: any Sendable = Direction.left
    let _: any Sendable = ZoomLevel.normal
    let _: any Sendable = IndicatorType.health
}
