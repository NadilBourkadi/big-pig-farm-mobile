/// DisplayFormattingTests — Tests for free formatting functions and color mappings.
/// SwiftUI view rendering is deferred to the polish phase per spec.
import Testing
import Foundation
import SwiftUI
@testable import BigPigFarm

// MARK: - formatBreedingStatus

struct FormatBreedingStatusTests {

    // ageDays=5 (adult), default happiness=75 >= 70 threshold, not locked → Ready
    @Test func adultHealthyPigIsReady() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 5.0
        #expect(formatBreedingStatus(pig) == "Ready")
    }

    @Test func lockedPigShowsLocked() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 5.0
        pig.breedingLocked = true
        #expect(formatBreedingStatus(pig) == "LOCKED")
    }

    @Test func babyPigShowsBaby() {
        let pig = GuineaPig.create(name: "Test", gender: .male) // ageDays=0 by default
        #expect(formatBreedingStatus(pig) == "Baby")
    }

    @Test func babyMarkedForSaleShowsSellAtAdult() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.markedForSale = true
        // isBaby=true (ageDays=0), markedForSale=true → special case
        #expect(formatBreedingStatus(pig) == "Sell@Adult")
    }

    @Test func seniorPigShowsSenior() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 35.0 // seniorAgeDays=30
        #expect(formatBreedingStatus(pig) == "Senior")
    }

    @Test func pregnantPigShowsPregnant() {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.ageDays = 5.0
        pig.isPregnant = true
        pig.pregnancyDays = 1.0
        #expect(formatBreedingStatus(pig) == "Pregnant")
    }

    @Test func verboseLockedShowsFullReason() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 5.0
        pig.breedingLocked = true
        #expect(formatBreedingStatus(pig, verbose: true) == "Breeding locked")
    }

    @Test func verboseBabyMarkedForSaleShowsFullMessage() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.markedForSale = true
        #expect(formatBreedingStatus(pig, verbose: true) == "Marked for auto-sell at adulthood")
    }

    @Test func unhappyPigShowsNotReady() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 5.0
        pig.needs.happiness = 50.0 // below 70 threshold
        #expect(formatBreedingStatus(pig) == "Not ready")
    }
}

// MARK: - formatFacilityBonuses

struct FormatFacilityBonusesTests {

    @Test func groomingStationShowsSaleBonus() {
        let bonuses = formatFacilityBonuses(.groomingStation)
        #expect(bonuses.contains("sale"))
        #expect(bonuses.contains("15"))
    }

    @Test func hideoutShowsHappinessBonus() {
        let bonuses = formatFacilityBonuses(.hideout)
        #expect(bonuses.contains("happiness"))
        #expect(bonuses.contains("10"))
    }

    @Test func foodBowlHasNoBonuses() {
        let bonuses = formatFacilityBonuses(.foodBowl)
        #expect(bonuses.isEmpty)
    }

    @Test func veggieGardenShowsFoodProduction() {
        let bonuses = formatFacilityBonuses(.veggieGarden)
        #expect(bonuses.contains("produces"))
        #expect(bonuses.contains("10"))
    }

    @Test func therapyGardenShowsMultipleBonuses() {
        let bonuses = formatFacilityBonuses(.therapyGarden)
        // therapyGarden: healthBonus=0.08, happinessBonus=0.20
        #expect(bonuses.contains("health"))
        #expect(bonuses.contains("happiness"))
        #expect(bonuses.contains(", "))
    }

    @Test func waterBottleHasNoBonuses() {
        let bonuses = formatFacilityBonuses(.waterBottle)
        #expect(bonuses.isEmpty)
    }
}

// MARK: - pigColorSwiftUI

struct PigColorSwiftUITests {

    @Test func blackMapsToNearBlack() {
        // .black (RGB 0,0,0) is invisible on dark material backgrounds.
        // Use Color(white:0.15) — dark enough to read as "black phenotype",
        // visible against SwiftUI .ultraThinMaterial / .regularMaterial.
        #expect(pigColorSwiftUI(.black) == Color(white: 0.15))
    }

    @Test func smokeMapsToGray() {
        #expect(pigColorSwiftUI(.smoke) == .gray)
    }

    @Test func goldenMapsToYellow() {
        #expect(pigColorSwiftUI(.golden) == .yellow)
    }

    @Test func chocolateMapsToBrown() {
        #expect(pigColorSwiftUI(.chocolate) == .brown)
    }

    @Test func saffronMapsToOrange() {
        #expect(pigColorSwiftUI(.saffron) == .orange)
    }

    @Test func allCasesReturnWithoutCrash() {
        // Exhaustiveness: every BaseColor must have a mapping
        for color in BaseColor.allCases {
            _ = pigColorSwiftUI(color)
        }
    }
}
